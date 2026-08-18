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
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Waits for the async providers a plan depends on to settle.
  Future<void> settle() async {
    await container.read(profileProvider.future);
    await container.read(completedSessionCountProvider.future);
    await container.read(pathPositionsProvider.future);
  }

  /// Lets a drift query stream deliver after a write.
  ///
  /// Re-reading `provider.future` would not do it: that future completed on
  /// the stream's first value and hands back the stale one immediately.
  Future<void> settleAfterWrite() => pumpEventQueue();

  Future<void> completeSessions(int count) async {
    for (var i = 0; i < count; i++) {
      await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              id: 'session-$i',
              startedAt: DateTime(2026, 3, i + 1),
              status: 'completed',
              rotationIndex: i % 3,
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
    container.invalidate(completedSessionCountProvider);
    await container.read(completedSessionCountProvider.future);

    final plan = container.read(nextSessionPlanProvider)!;
    expect(plan.rotationIndex, 1);
    expect(plan.pairs.first.pathIds, ['dip', 'hinge']);
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
    container.invalidate(completedSessionCountProvider);
    await container.read(completedSessionCountProvider.future);

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
}
