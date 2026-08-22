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
import 'package:triple_r/services/workout_notification.dart';
import 'package:triple_r/state/active_session.dart';
import 'package:triple_r/state/timer_providers.dart';

/// A whole workout, driven against an in-memory database.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeTicker ticker;
  late ProviderContainer container;
  late FakeWorkoutNotification notifications;

  /// A container over the same fakes — used to simulate the app being killed
  /// and reopened onto an in-progress session.
  ProviderContainer freshContainer() => ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          tickerProvider.overrideWithValue(ticker),
          alertsProvider.overrideWithValue(RecordingAlerts()),
          screenWakeProvider.overrideWithValue(FakeScreenWake()),
          workoutNotificationProvider.overrideWithValue(notifications),
        ],
      );

  setUp(() {
    db = AppDatabase.memory();
    clock = FakeClock();
    ticker = FakeTicker();
    notifications = FakeWorkoutNotification();
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
  Future<void> logCurrent(int reps, {double? weightKg}) async {
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
      weightKg: weightKg,
    );
  }

  /// Works the whole session at [reps].
  ///
  /// [weightOn] names a path whose sets carry [weightKg] — the case where the
  /// user types a load into the logger rather than accepting a prompt.
  Future<void> completeWorkout(
    int reps, {
    String? weightOn,
    double? weightKg,
  }) async {
    while (session().currentStep != null) {
      final onPath = session().currentStep!.pathId == weightOn;
      await logCurrent(reps, weightKg: onPath ? weightKg : null);
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

    test('the weight the user typed is what the prompt adds to', () async {
      // The reported bug: the working load only ever moved when a prompt was
      // accepted, so someone who simply typed 10 lb into the logger still had
      // zero recorded against the exercise — and the prompt then offered the
      // bare increment as a *total*, wiping the ten they had been lifting.
      await db.saveProgressionConfig(
        pathId: 'antirotation',
        branchId: 'pallof',
        exerciseId: 'pallof_press',
      );
      await settle();
      await controller().start();
      await completeWorkout(
        12,
        weightOn: 'antirotation',
        weightKg: poundsToKg(10),
      );

      final outcomes = await controller().evaluateSession();
      final core = outcomes.firstWhere((o) => o.pathId == 'antirotation');
      final add = core.outcome as AddLoadOutcome;
      expect(
        kgToPounds(add.currentLoadKg),
        closeTo(10, 1e-6),
        reason: 'the log is the truth about what was lifted',
      );
      expect(kgToPounds(add.resultingLoadKg), closeTo(12.5, 1e-6));

      await controller().applyOutcome(core);
      final state = await db.exerciseState('pallof_press');
      expect(kgToPounds(state!.workingLoadKg), closeTo(12.5, 1e-6));
    });

    test('a typed load is remembered even without a prompt', () async {
      await db.saveProgressionConfig(
        pathId: 'antirotation',
        branchId: 'pallof',
        exerciseId: 'pallof_press',
      );
      await settle();
      await controller().start();
      // Mid-range: no prompt at all, and the load must still stick.
      await completeWorkout(
        10,
        weightOn: 'antirotation',
        weightKg: poundsToKg(10),
      );
      await controller().evaluateSession();

      final state = await db.exerciseState('pallof_press');
      expect(kgToPounds(state!.workingLoadKg), closeTo(10, 1e-6));
    });

    test('the increment from settings is what a fresh exercise moves by',
        () async {
      await db.updateProfile(
        UserProfilesCompanion(loadIncrementKg: Value(poundsToKg(10))),
      );
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
      expect(
        kgToPounds((hinge.outcome as AddLoadOutcome).suggestedIncrementKg),
        closeTo(10, 1e-6),
      );
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
          sessionOrdinal: i,
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

  group('the ongoing notification', () {
    test('names the current exercise while working', () async {
      await controller().start();

      expect(notifications.isShowing, isTrue);
      expect(notifications.current, startsWith('Scapular Pulls'));
      expect(
        notifications.current,
        contains('Pair 1 · set 1 of 3'),
      );
    });

    test('becomes the rest countdown, naming what is coming next', () async {
      await controller().start();
      await controller().logSet(reps: 5, holdSeconds: null);

      // Logging starts the 90s pair rest and moves to the paired exercise.
      expect(notifications.current, startsWith('Resting'));
      expect(
        notifications.current,
        contains('Next up: Assisted Squats'),
        reason: 'the exercise named is the one about to be worked',
      );
      expect(
        notifications.current,
        endsWith('0/90'),
        reason: 'the bar tracks the rest while the rest is what is running',
      );
      // The seconds are not in the text — text only changes while the app is
      // scheduled, and the shade used to freeze at whatever second Flutter
      // was last awake for. The deadline goes to the platform instead, which
      // counts it down whether or not any Dart is running.
      expect(
        notifications.countdowns.last,
        clock.now().add(const Duration(seconds: 90)),
      );

      clock.advance(const Duration(seconds: 30));
      ticker.tick();
      expect(notifications.current, endsWith('30/90'));
      expect(
        notifications.countdowns.last,
        clock.now().add(const Duration(seconds: 60)),
        reason: 'the deadline is fixed, so it does not drift as time passes',
      );
    });

    test('five ticks a second do not become five notifications', () async {
      await controller().start();
      await controller().logSet(reps: 5, holdSeconds: null);
      final before = notifications.shown.length;

      // A whole second of ticks at the 200ms interval.
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(milliseconds: 200));
        ticker.tick();
      }

      expect(
        notifications.shown.length - before,
        1,
        reason: 'only the whole second changed, so only one post',
      );
    });

    test('goes back to the exercise once the rest is skipped', () async {
      await controller().start();
      await controller().logSet(reps: 5, holdSeconds: null);
      container.read(restTimerProvider.notifier).skip();

      expect(notifications.current, startsWith('Assisted Squats'));
      expect(notifications.current, endsWith('1/27'));
    });

    test('is taken down when the workout ends', () async {
      await controller().start();
      await controller().finish(completed: true);

      expect(notifications.isShowing, isFalse);
      expect(notifications.clears, greaterThan(0));
    });
  });

  test('completing a workout consumes the hand-picked rotation', () async {
    // The override is a correction to which session the user is on, and it is
    // spent once a session records that. Keeping it would override every
    // workout from then on rather than the one it was meant for.
    await db.setPlannedRotation(2);
    await controller().start();
    expect((await db.profile).plannedRotationIndex, 2);

    await controller().finish(completed: true);
    expect((await db.profile).plannedRotationIndex, isNull);
  });

  test('abandoning a workout keeps the hand-picked rotation', () async {
    // Nothing recorded the session, so the correction is still outstanding.
    await db.setPlannedRotation(2);
    await controller().start();
    await controller().finish(completed: false);

    expect((await db.profile).plannedRotationIndex, 2);
  });
}
