import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/domain/units.dart';
import 'package:triple_r/providers.dart';

/// The seam between the pure domain logic and the database — the part neither
/// the domain tests nor the widget tests cover.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    // Riverpod 3 auto-disposes providers with no listeners, so a bare
    // `read(provider.future)` tears the element down before the underlying
    // stream emits and the future never completes. Widgets keep these alive
    // by watching them; the test has to do it explicitly.
    container.listen(profileProvider, (_, _) {});
    container.listen(pathPositionsProvider, (_, _) {});
    container.listen(completedSessionCountProvider, (_, _) {});
    container.listen(sessionHistoryProvider, (_, _) {});
    container.listen(nextSessionOrdinalProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Waits for the async providers a plan depends on to settle.
  Future<void> settle() async {
    await container.read(profileProvider.future);
    await container.read(completedSessionCountProvider.future);
    await container.read(sessionHistoryProvider.future);
    await container.read(nextSessionOrdinalProvider.future);
    await container.read(pathPositionsProvider.future);
  }

  /// Lets a drift query stream deliver after a write.
  ///
  /// Re-reading `provider.future` would not do it: that future completed on
  /// the stream's first value and hands back the stale one immediately.
  Future<void> settleAfterWrite() => pumpEventQueue();

  /// Re-reads what a plan derives from after sessions are written directly.
  ///
  /// The session number now carries forward from the last completed row
  /// rather than being counted, so both it and the raw count have to be
  /// refreshed before the plan is read back.
  Future<void> settleAfterSession() async {
    await pumpEventQueue();
    container.invalidate(completedSessionCountProvider);
    container.invalidate(nextSessionOrdinalProvider);
    await container.read(completedSessionCountProvider.future);
    await container.read(nextSessionOrdinalProvider.future);
  }

  Future<void> completeSessions(int count) async {
    for (var i = 0; i < count; i++) {
      await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              id: 'session-$i',
              startedAt: DateTime(2026, 3, i + 1),
              status: 'completed',
              rotationIndex: i % 3,
              sessionOrdinal: Value(i),
              pairRestSeconds: 90,
              tripletRestSeconds: 60,
            ),
          );
    }
  }

  test('unit system follows the profile', () async {
    await settle();
    expect(container.read(unitSystemProvider), UnitSystem.imperial);

    await db.updateProfile(const UserProfilesCompanion(unitSystem: Value('metric')));
    await settleAfterWrite();
    expect(container.read(unitSystemProvider), UnitSystem.metric);
  });

  test('the plan is null until its inputs load', () {
    // Planning against a not-yet-loaded session count would silently pick
    // rotation 0 and show the wrong pair order for a moment.
    expect(container.read(nextSessionPlanProvider), isNull);
  });

  test('rotation advances with completed sessions', () async {
    await settle();
    expect(container.read(nextSessionPlanProvider)!.rotationIndex, 0);

    await completeSessions(1);
    await settleAfterSession();

    final plan = container.read(nextSessionPlanProvider)!;
    expect(plan.rotationIndex, 1);
    expect(plan.pairs.first.pathIds, ['dip', 'hinge']);
  });

  test('a workout started out of order still advances the sequence', () async {
    // The rotation used to be counted from the rows, so finishing the workout
    // you were actually due handed you the same one again: one row completed
    // means "session 1", which is the workout just done.
    await settle();
    expect(container.read(nextSessionPlanProvider)!.rotationIndex, 0);

    // Trained yesterday without logging it, so start workout 2 instead.
    await db.setPlannedRotation(1);
    await settle();
    expect(container.read(nextSessionPlanProvider)!.rotationIndex, 1);
    expect(container.read(plannedSessionOrdinalProvider), 1);

    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: 'out-of-order',
            startedAt: DateTime(2026, 3, 2),
            status: 'completed',
            rotationIndex: 1,
            sessionOrdinal: const Value(1),
            pairRestSeconds: 90,
            tripletRestSeconds: 60,
          ),
        );
    await db.setPlannedRotation(null);
    await settleAfterSession();

    expect(
      container.read(nextSessionPlanProvider)!.rotationIndex,
      2,
      reason: 'the next workout carries on from the one actually done',
    );
  });

  test('turning rotation off pins the book order', () async {
    await completeSessions(2);
    await db.updateProfile(
      const UserProfilesCompanion(rotatePairOrder: Value(false)),
    );
    await settle();

    final plan = container.read(nextSessionPlanProvider)!;
    expect(plan.rotationIndex, 0);
    expect(plan.pairs.first.pathIds, ['pullup', 'squat']);
  });

  test('a fresh install plans every path at its first exercise', () async {
    await settle();
    final exercises = container.read(nextSessionExercisesProvider);

    expect(exercises, hasLength(9));
    expect(exercises['pushup'], 'wall_pushups');
    expect(exercises['squat'], 'assisted_squats');
    // The two core paths with no trunk default to Option A of the source
    // routine rather than to whichever branch happened to be listed first.
    expect(exercises['antirotation'], 'pallof_press');
    expect(exercises['extension'], 'reverse_hyperextensions');
  });

  test('the alternating hinge branch picks its lift from the session count',
      () async {
    await db.saveProgressionConfig(
      pathId: 'hinge',
      branchId: 'barbell',
      exerciseId: null,
    );
    await settle();
    expect(
      container.read(nextSessionExercisesProvider)['hinge'],
      'barbell_romanian_deadlift',
    );

    await completeSessions(1);
    await settleAfterSession();

    expect(
      container.read(nextSessionExercisesProvider)['hinge'],
      'barbell_deadlift',
    );
  });

  test('abandoned sessions do not move the rotation', () async {
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: 'bailed',
            startedAt: DateTime(2026, 3, 1),
            status: 'abandoned',
            rotationIndex: 0,
            pairRestSeconds: 90,
            tripletRestSeconds: 60,
          ),
        );
    await settle();

    expect(container.read(nextSessionPlanProvider)!.rotationIndex, 0);
  });

  test('warmup gating reflects stored progression', () async {
    await settle();
    expect(container.read(nextSessionPlanProvider)!.warmup, hasLength(4));

    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'pullup_eccentrics',
    );
    await settleAfterWrite();

    final warmup = container.read(nextSessionPlanProvider)!.warmup;
    expect(warmup, hasLength(5));
    expect(warmup.map((w) => w.name), contains('Arch Hangs'));
  });

  test('a hand-picked workout survives a restart', () async {
    // It is a correction to which session the user is on, not a preference
    // about the one screen they are looking at. Losing it on restart put them
    // back on a workout they had already said they were past — silently.
    await settle();
    await db.setPlannedRotation(2);
    await settle();
    expect(container.read(nextSessionPlanProvider)!.rotationIndex, 2);

    // A fresh container over the same database, as after a relaunch.
    final restarted = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(restarted.dispose);
    restarted.listen(nextSessionPlanProvider, (_, _) {});
    await restarted.read(profileProvider.future);
    await restarted.read(nextSessionOrdinalProvider.future);

    expect(
      restarted.read(nextSessionPlanProvider)!.rotationIndex,
      2,
      reason: 'still on the workout the user said they were on',
    );
  });
}
