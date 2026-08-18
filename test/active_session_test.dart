import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/domain/progression.dart';
import 'package:triple_r/domain/units.dart';
import 'package:triple_r/domain/workout_steps.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/active_session.dart';
import 'package:triple_r/state/timer_providers.dart';

/// A whole workout, driven against an in-memory database.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeTicker ticker;
  late ProviderContainer container;

  /// A container over the same fakes — used to simulate the app being killed
  /// and reopened onto an in-progress session.
  ProviderContainer freshContainer() => ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          tickerProvider.overrideWithValue(ticker),
          alertsProvider.overrideWithValue(RecordingAlerts()),
          screenWakeProvider.overrideWithValue(FakeScreenWake()),
        ],
      );

  setUp(() {
    db = AppDatabase.memory();
    clock = FakeClock();
    ticker = FakeTicker();
    container = freshContainer();
    // Riverpod 3 auto-disposes unlistened providers; without a subscription
    // the notifier is torn down between awaits.
    container.listen(activeSessionProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  ActiveSessionController controller() =>
      container.read(activeSessionProvider.notifier);

  ActiveSession session() => container.read(activeSessionProvider).value!;

  Future<void> settle() => container.read(activeSessionProvider.future);

  /// Logs [reps] for whatever step is current.
  Future<void> logCurrent(int reps) async {
    final step = session().currentStep!;
    final exercise = session().exerciseFor(step);
    // Timed exercises must go in the hold column or the CHECK constraint
    // rejects the row.
    final timed = ['planks', 'parallel_bar_support_hold', 'tuck_front_levers']
        .contains(exercise);
    clock.advance(const Duration(seconds: 40));
    await controller().logSet(
      reps: timed ? null : reps,
      holdSeconds: timed ? reps : null,
    );
  }

  /// Works the whole session at [reps].
  Future<void> completeWorkout(int reps) async {
    while (session().currentStep != null) {
      await logCurrent(reps);
    }
  }

  group('starting', () {
    test('writes an in-progress row before anything is logged', () async {
      await settle();
      await controller().start();

      final row = await db.inProgressSession;
      expect(row, isNotNull);
      expect(row!.status, 'in_progress');
      expect(row.endedAt, isNull);
      expect(row.cursorJson, isNotNull);
    });

    test('captures the rest defaults from the profile', () async {
      await db.updateProfile(const UserProfilesCompanion(
        defaultPairRestSeconds: Value(120),
        defaultTripletRestSeconds: Value(45),
      ));
      await settle();
      await controller().start();

      expect(session().pairRestSeconds, 120);
      expect(session().tripletRestSeconds, 45);
    });

    test('freezes the exercise for each path at start', () async {
      await settle();
      await controller().start();
      expect(session().exerciseByPath['pushup'], 'wall_pushups');
      expect(session().exerciseByPath, hasLength(9));
    });
  });

  group('logging', () {
    test('records a set and advances to the paired exercise', () async {
      await settle();
      await controller().start();
      expect(session().currentStep!.pathId, 'pullup');

      await logCurrent(6);

      expect(session().currentStep!.pathId, 'squat');
      final sets = await db.setsForSession(session().id);
      expect(sets, hasLength(1));
      expect(sets.single.repsCompleted, 6);
      expect(sets.single.setIndex, 1);
    });

    test('starts the rest timer between sets', () async {
      await settle();
      await controller().start();
      await logCurrent(6);

      expect(container.read(restTimerProvider).isRunning, isTrue);
      expect(
        container.read(restTimerProvider.notifier).remaining,
        const Duration(seconds: 90),
      );
    });

    test('uses the triplet rest inside the triplet', () async {
      await settle();
      await controller().start();
      // Walk to the first triplet step.
      while (!session().currentStep!.isTriplet) {
        await logCurrent(6);
      }
      await logCurrent(10);

      expect(
        container.read(restTimerProvider.notifier).remaining,
        const Duration(seconds: 60),
      );
    });

    test('does not rest after the final set', () async {
      await settle();
      await controller().start();
      await completeWorkout(6);

      expect(session().currentStep, isNull);
      expect(container.read(restTimerProvider).isRunning, isFalse);
    });

    test('persists the cursor after every set', () async {
      await settle();
      await controller().start();
      await logCurrent(6);
      await logCurrent(6);

      final row = await db.inProgressSession;
      expect(row!.cursorJson, contains('"stepIndex":2'));
    });

    test('re-logging the same set overwrites rather than duplicating', () async {
      await settle();
      await controller().start();
      await logCurrent(6);

      await controller().editSet(
        pathId: 'pullup',
        setIndex: 1,
        reps: 8,
        holdSeconds: null,
      );

      final sets = await db.setsForSession(session().id);
      expect(sets, hasLength(1));
      expect(sets.single.repsCompleted, 8);
    });

    test('a timed exercise logs into the hold column', () async {
      await db.saveProgressionConfig(
        pathId: 'antiextension',
        branchId: 'rings',
        exerciseId: 'planks',
      );
      await settle();
      await controller().start();
      while (session().currentStep!.pathId != 'antiextension') {
        await logCurrent(6);
      }
      await logCurrent(45);

      final sets = await db.setsForSession(session().id);
      final plank = sets.firstWhere((s) => s.exerciseId == 'planks');
      expect(plank.holdSeconds, 45);
      expect(plank.repsCompleted, isNull);
    });
  });

  group('skipping', () {
    test('drops every remaining set of that exercise', () async {
      await settle();
      await controller().start();
      final before = session().stepsRemaining;

      await controller().skipCurrentExercise();

      expect(session().currentStep!.pathId, 'squat');
      expect(session().stepsRemaining, before - 3);
    });

    test('a skipped exercise logs nothing and is excluded from progression',
        () async {
      await settle();
      await controller().start();
      await controller().skipCurrentExercise();
      await completeWorkout(8);

      final sets = await db.setsForSession(session().id);
      expect(sets.where((s) => s.pathId == 'pullup'), isEmpty);

      final outcomes = await controller().evaluateSession();
      expect(
        outcomes.where((o) => o.pathId == 'pullup'),
        isEmpty,
        reason: 'a day without a bar must not advance or regress anything',
      );
    });

    test('cancels any running rest', () async {
      await settle();
      await controller().start();
      await logCurrent(6);
      expect(container.read(restTimerProvider).isRunning, isTrue);

      await controller().skipCurrentExercise();
      expect(container.read(restTimerProvider).isRunning, isFalse);
    });
  });

  group('resume', () {
    test('rebuilds an interrupted session at the same step', () async {
      await settle();
      await controller().start();
      await logCurrent(6);
      await logCurrent(6);
      final id = session().id;

      // A fresh container is what the app does after being killed.
      final revived = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        tickerProvider.overrideWithValue(ticker),
        alertsProvider.overrideWithValue(RecordingAlerts()),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
      ]);
      revived.listen(activeSessionProvider, (_, _) {});
      final resumed = await revived.read(activeSessionProvider.future);

      expect(resumed!.id, id);
      expect(resumed.cursor.stepIndex, 2);
      expect(resumed.currentStep!.pathId, 'pullup');
      expect(resumed.currentStep!.setIndex, 2);
      revived.dispose();
    });

    test('keeps the original start time so elapsed stays true', () async {
      await settle();
      await controller().start();
      final startedAt = session().startedAt;

      clock.advance(const Duration(minutes: 12));
      final revived = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        tickerProvider.overrideWithValue(ticker),
        alertsProvider.overrideWithValue(RecordingAlerts()),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
      ]);
      revived.listen(activeSessionProvider, (_, _) {});
      final resumed = await revived.read(activeSessionProvider.future);

      expect(resumed!.startedAt, startedAt);
      revived.dispose();
    });

    test('preserves skipped exercises across a restart', () async {
      await settle();
      await controller().start();
      await controller().skipCurrentExercise();

      final revived = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        tickerProvider.overrideWithValue(ticker),
        alertsProvider.overrideWithValue(RecordingAlerts()),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
      ]);
      revived.listen(activeSessionProvider, (_, _) {});
      final resumed = await revived.read(activeSessionProvider.future);

      expect(resumed!.cursor.skippedPathIds, contains('pullup'));
      expect(resumed.currentStep!.pathId, 'squat');
      revived.dispose();
    });

    test('does not reshuffle the pair order mid-workout', () async {
      // Rotation is derived from the completed count, which could change
      // between a crash and a resume; the session's own index must win.
      await settle();
      await controller().start();
      final order = session().plan.pairs.map((p) => p.aPathId).toList();

      await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              id: 'unrelated-completed',
              startedAt: DateTime(2026, 1, 1),
              status: 'completed',
              rotationIndex: 2,
              pairRestSeconds: 90,
              tripletRestSeconds: 60,
            ),
          );

      final revived = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        tickerProvider.overrideWithValue(ticker),
        alertsProvider.overrideWithValue(RecordingAlerts()),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
      ]);
      revived.listen(activeSessionProvider, (_, _) {});
      final resumed = await revived.read(activeSessionProvider.future);

      expect(resumed!.plan.pairs.map((p) => p.aPathId).toList(), order);
      revived.dispose();
    });
  });

  group('finishing', () {
    test('completing counts toward the rotation', () async {
      await settle();
      await controller().start();
      await completeWorkout(6);
      await controller().finish(completed: true);

      expect(await db.completedSessionCount(), 1);
      expect(await db.inProgressSession, isNull);
    });

    test('abandoning keeps the sets but does not count', () async {
      await settle();
      await controller().start();
      await logCurrent(6);
      await controller().finish(completed: false);

      expect(await db.completedSessionCount(), 0);
      expect(await db.inProgressSession, isNull);

      final all = await db.select(db.setRecords).get();
      expect(all, hasLength(1), reason: 'the set really was performed');
    });

    test('clears the cursor so nothing offers to resume a finished workout',
        () async {
      await settle();
      await controller().start();
      final id = session().id;
      await controller().finish(completed: true);

      final row = await (db.select(db.workoutSessions)
            ..where((s) => s.id.equals(id)))
          .getSingle();
      expect(row.cursorJson, isNull);
      expect(row.endedAt, isNotNull);
    });
  });

  group('end-of-session evaluation', () {
    test('three sets at the ceiling offer to advance', () async {
      await settle();
      await controller().start();
      await completeWorkout(8);

      final outcomes = await controller().evaluateSession();
      final pushup = outcomes.firstWhere((o) => o.pathId == 'pushup');
      expect(pushup.outcome, isA<AdvanceOutcome>());
      expect(
        (pushup.outcome as AdvanceOutcome).nextExerciseId,
        'incline_pushups',
      );
    });

    test('accepting an advance moves the stored progression', () async {
      await settle();
      await controller().start();
      await completeWorkout(8);

      final outcomes = await controller().evaluateSession();
      await controller()
          .applyOutcome(outcomes.firstWhere((o) => o.pathId == 'pushup'));

      final configs = await db.progressionConfigsAll;
      final pushup = configs.firstWhere((c) => c.pathId == 'pushup');
      expect(pushup.selectedExerciseId, 'incline_pushups');
    });

    test('a mid-range session produces no prompts', () async {
      await settle();
      await controller().start();
      await completeWorkout(6);

      final outcomes = await controller().evaluateSession();
      expect(
        outcomes.where((o) => !o.pathId.startsWith('anti')),
        isEmpty,
        reason: '6 reps sits inside the 5-8 pair range',
      );
    });

    test('a first failing session is silent but still counted', () async {
      // The counter must persist even with no prompt, or the second failing
      // session can never see the first.
      await settle();
      await controller().start();
      await completeWorkout(2);
      final outcomes = await controller().evaluateSession();

      expect(outcomes.where((o) => o.pathId == 'pushup'), isEmpty);
      final state = await db.exerciseState('wall_pushups');
      expect(state!.consecutiveFailures, 1);
    });

    test('a second failing session offers to regress', () async {
      await settle();
      await controller().start();
      await db.saveProgressionConfig(
        pathId: 'pushup',
        branchId: 'pseudoplanche',
        exerciseId: 'incline_pushups',
      );
      await db.saveExerciseState('incline_pushups', consecutiveFailures: 1);

      // Restart so the session picks up the configured exercise.
      await controller().finish(completed: false);
      await controller().start();
      await completeWorkout(2);

      final outcomes = await controller().evaluateSession();
      final pushup = outcomes.firstWhere((o) => o.pathId == 'pushup');
      expect(pushup.outcome, isA<RegressOutcome>());
    });

    test('load-mode exercises offer weight and remember the increment',
        () async {
      await db.saveProgressionConfig(
        pathId: 'hinge',
        branchId: 'barbell',
        exerciseId: null,
      );
      await db.saveExerciseState('barbell_romanian_deadlift', workingLoadKg: 60);
      await settle();
      await controller().start();
      await completeWorkout(8);

      final outcomes = await controller().evaluateSession();
      final hinge = outcomes.firstWhere((o) => o.pathId == 'hinge');
      expect(hinge.outcome, isA<AddLoadOutcome>());
      expect(hinge.exerciseId, 'barbell_romanian_deadlift');

      await controller().applyOutcome(hinge);
      final state = await db.exerciseState('barbell_romanian_deadlift');
      expect(
        kgToPounds(state!.workingLoadKg),
        closeTo(kgToPounds(60) + 2.5, 1e-6),
        reason: 'seeded at 2.5 lb and added in display units',
      );
      expect(state.lastIncrementKg, isNotNull);
    });

    test('a topped-out branch congratulates once and records it', () async {
      await db.saveProgressionConfig(
        pathId: 'squat',
        branchId: 'pistol',
        exerciseId: 'pistol_squats',
      );
      await settle();
      await controller().start();
      await completeWorkout(8);

      final outcomes = await controller().evaluateSession();
      expect(
        outcomes.firstWhere((o) => o.pathId == 'squat').outcome,
        isA<MasteredOutcome>(),
      );
      expect((await db.exerciseState('pistol_squats'))!.masteredAt, isNotNull);
    });
  });

  group('resuming keeps the session it started as', () {
    test('the alternating hinge lift survives a resume', () async {
      // The stored rotation index is 0-2; it was being passed where a session
      // number belongs, so a resumed workout could compute the hinge lift
      // from 1 when the session had started life as number 4 — and the
      // barbell rotation would swap under a user mid-workout.
      await db.saveProgressionConfig(
        pathId: 'hinge',
        branchId: 'barbell',
        exerciseId: null,
      );
      for (var i = 0; i < 4; i++) {
        await db.startSession(
          id: 'done-$i',
          startedAt: clock.now(),
          rotationIndex: i % 3,
          pairRestSeconds: 90,
          tripletRestSeconds: 60,
          cursorJson: const SessionCursor().encode(),
        );
        await db.closeSession('done-$i',
            status: 'completed', endedAt: clock.now());
      }

      await container.read(activeSessionProvider.notifier).start();
      final atStart =
          container.read(activeSessionProvider).value!.exerciseByPath['hinge'];

      // A fresh controller, as after the app is killed and reopened.
      final resumed = freshContainer();
      addTearDown(resumed.dispose);
      final session = await resumed.read(activeSessionProvider.future);

      expect(session!.exerciseByPath['hinge'], atStart);
    });
  });
}
