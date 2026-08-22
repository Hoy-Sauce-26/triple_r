import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/domain/units.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/active_workout_screen.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/active_session.dart';
import 'package:triple_r/state/timer_providers.dart';
import 'package:triple_r/widgets/edit_set_dialog.dart';
import 'package:triple_r/theme.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeTicker ticker;
  late RecordingAlerts alerts;

  setUp(() {
    db = AppDatabase.memory();
    clock = FakeClock();
    ticker = FakeTicker();
    alerts = RecordingAlerts();
  });

  tearDown(() => db.close());

  late ProviderContainer container;

  Future<void> pumpWorkout(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        tickerProvider.overrideWithValue(ticker),
        alertsProvider.overrideWithValue(alerts),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
      ],
    );
    container.listen(activeSessionProvider, (_, _) {});
    await container.read(activeSessionProvider.future);
    await container.read(activeSessionProvider.notifier).start();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: lightTheme,
          home: const ActiveWorkoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The nth TextField inside the edit dialog. Scoped because the screen
  /// behind the dialog has fields of its own.
  Finder dialogField(int index) => find
      .descendant(
        of: find.byType(EditSetDialog),
        matching: find.byType(TextField),
      )
      .at(index);

  /// Skips the six pair exercises so the triplet is next, without tapping
  /// through eighteen sets.
  Future<void> skipToTriplet(WidgetTester tester) async {
    final notifier = container.read(activeSessionProvider.notifier);
    while (container.read(activeSessionProvider).value?.currentStep?.isTriplet ==
        false) {
      await notifier.skipCurrentExercise();
    }
    await tester.pumpAndSettle();
  }

  /// Order matters. With `UncontrolledProviderScope` the test owns the
  /// container, so unmounting the tree does not dispose it — but disposing it
  /// cancels drift's query streams, and `StreamQueryStore.markAsClosed`
  /// schedules a zero-duration timer. Disposing after the last pump leaves
  /// that timer pending and every test fails on `!timersPending`. Dispose
  /// first, then pump to flush it.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(Duration.zero);
  }

  testWidgets('opens on the first exercise of the rotation', (tester) async {
    await pumpWorkout(tester);

    expect(find.text('Scapular Pulls'), findsOneWidget);
    expect(find.text('Pair 1 · set 1 of 3'), findsOneWidget);
    expect(find.textContaining('Target 3 x 5-8'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('logging a set advances to the paired exercise and rests',
      (tester) async {
    await pumpWorkout(tester);

    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    expect(find.text('Assisted Squats'), findsOneWidget);
    expect(find.text('Resting'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the rest overlay counts down and chimes at zero',
      (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    clock.advance(const Duration(seconds: 60));
    ticker.tick();
    await tester.pumpAndSettle();
    expect(find.text('0:30'), findsOneWidget);
    expect(alerts.total, 0);

    clock.advance(const Duration(seconds: 30));
    ticker.tick();
    await tester.pumpAndSettle();

    expect(find.text('Rest done'), findsOneWidget);
    expect(alerts.restCompletions, hasLength(1));

    await disposeApp(tester);
  });

  testWidgets('+15s extends a running rest', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+15s'));
    await tester.pumpAndSettle();

    expect(find.text('1:45'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('skipping the rest dismisses the overlay without chiming',
      (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Resting'), findsNothing);
    expect(alerts.total, 0, reason: 'the user chose to move on');

    await disposeApp(tester);
  });

  testWidgets('the entry field takes a typed value', (tester) async {
    await pumpWorkout(tester);

    // Seeds at the bottom of the range with no history to draw on.
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    expect(sets.single.repsCompleted, 12);

    await disposeApp(tester);
  });

  testWidgets('a set carries the previous set of the same session forward',
      (tester) async {
    // Someone who moved from 5 reps to 8 this week is going for 8 again on
    // set 2 — not back to the 5 they managed last week.
    await pumpWorkout(tester);

    await tester.enterText(find.byType(TextField).first, '8');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // The pair alternates, so the partner exercise comes between set 1 and
    // set 2 of this one.
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, '8'),
      findsOneWidget,
      reason: 'set 2 starts where set 1 finished, not where last week did',
    );

    await disposeApp(tester);
  });

  testWidgets('a weighted exercise remembers the weight across sets',
      (tester) async {
    // The plates do not change between sets. Re-typing them each time invites
    // a typo, and forgetting entirely used to log a silent zero — which then
    // fed the load-progression evaluation at the end of the session.
    // Scapular Pulls, where the rotation starts, carries no load. Put the
    // pull-up path on its weighted branch so the weight field is present.
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'weighted_pullups',
    );
    await pumpWorkout(tester);
    expect(find.text('Weighted Pull-ups'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '8');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Past the partner exercise and back to set 2 of this one.
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, '10'),
      findsOneWidget,
      reason: 'the weight carries forward with the reps',
    );

    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    final logged = sets.where((s) => s.exerciseId == 'weighted_pullups');
    expect(
      logged.map((s) => s.weightKg),
      everyElement(closeTo(poundsToKg(10), 1e-9)),
      reason: 'both sets are logged at the weight, not just the typed one',
    );

    await disposeApp(tester);
  });

  testWidgets('a weight of zero is recorded as zero, not as nothing',
      (tester) async {
    // Zero and empty look identical in the box but are not the same claim:
    // empty means "no weight recorded", zero means "I did this unloaded".
    // Both used to land in the database as 0, so a set deliberately logged
    // bodyweight had its field re-seeded from the working load on the very
    // next set.
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'weighted_pullups',
    );
    await db.saveExerciseState('weighted_pullups', workingLoadKg: poundsToKg(25));
    await pumpWorkout(tester);

    await tester.enterText(find.byType(TextField).first, '8');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    expect(
      sets.firstWhere((s) => s.pathId == 'pullup').weightKg,
      0,
      reason: 'a typed zero is a value, and it is stored as one',
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, '0'),
      findsOneWidget,
      reason: 'set 2 keeps the zero rather than reverting to the working load',
    );

    await disposeApp(tester);
  });

  testWidgets('an untouched weight field records nothing at all',
      (tester) async {
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'weighted_pullups',
    );
    await pumpWorkout(tester);

    await tester.enterText(find.byType(TextField).first, '8');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    expect(
      sets.firstWhere((s) => s.pathId == 'pullup').weightKg,
      isNull,
      reason: 'nothing entered is not the same claim as zero',
    );

    await disposeApp(tester);
  });

  testWidgets('the set rows carry what the same set came to last time',
      (tester) async {
    // So the user can see last week without the entry box being locked down
    // to it — the seed is one number they immediately overtype and lose.
    //
    // Pair rotation off, so completing the session below does not hand the
    // new workout a different pair order and open on a different exercise.
    await db.updateProfile(const UserProfilesCompanion(rotatePairOrder: Value(false)));
    final previous = 'session-previous';
    await db.startSession(
      id: previous,
      startedAt: DateTime(2026, 3, 1, 9),
      rotationIndex: 0,
      sessionOrdinal: 0,
      pairRestSeconds: 90,
      tripletRestSeconds: 60,
      cursorJson: '{}',
    );
    for (final (index, reps) in [7, 6, 5].indexed) {
      await db.logSet(
        SetRecordsCompanion.insert(
          id: '$previous-pullup-${index + 1}',
          sessionId: previous,
          pathId: 'pullup',
          exerciseId: 'scapular_pulls',
          setIndex: index + 1,
          repsCompleted: Value(reps),
          recordedAt: DateTime(2026, 3, 1, 9, 10 + index),
        ),
      );
    }
    await db.closeSession(
      previous,
      status: 'completed',
      endedAt: DateTime(2026, 3, 1, 10),
    );

    await pumpWorkout(tester);

    expect(find.text('Last time'), findsOneWidget);
    for (final reps in ['7', '6', '5']) {
      expect(
        find.text(reps),
        findsWidgets,
        reason: 'each of last session\'s three sets is shown against its own',
      );
    }

    await disposeApp(tester);
  });

  testWidgets('an unparseable entry cannot be logged', (tester) async {
    await pumpWorkout(tester);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log set'),
    );
    expect(button.onPressed, isNull);

    await disposeApp(tester);
  });

  testWidgets('logged sets are listed and can be corrected', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Back to the pull-up on set 2; set 1 shows in the history list.
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Set 1 now carries its value; the sets still to come hold their place
    // with a placeholder rather than being absent.
    //
    // Anchored to the Set 1 row rather than to any ListTile: the "Just
    // logged" card is a ListTile too, and it is legitimately showing the same
    // number for the paired exercise.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Set 1'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    expect(find.text('—'), findsNWidgets(2));

    await disposeApp(tester);
  });

  testWidgets('every set of the exercise is listed before anything is logged',
      (tester) async {
    // The list used to appear only once a set existed, so it grew a row at
    // the moment of logging and the screen changed exercise immediately
    // after — the two together read as a flicker.
    await pumpWorkout(tester);

    for (final label in ['Set 1', 'Set 2', 'Set 3']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('—'), findsNWidgets(3));

    await disposeApp(tester);
  });

  testWidgets('skipping an exercise jumps past all of its sets',
      (tester) async {
    await pumpWorkout(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Assisted Squats'), findsOneWidget);
    expect(find.text('Scapular Pulls'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('ending early asks first and says what it costs', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End workout early'));
    await tester.pumpAndSettle();

    expect(find.textContaining('will not count toward your rotation'),
        findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();

    expect(await db.inProgressSession, isNotNull);

    await disposeApp(tester);
  });

  testWidgets('tapping the entry field selects the whole number',
      (tester) async {
    // The seed is a guess to be overtyped, not text to edit. Leaving the
    // caret where the user tapped costs a select-all before every correction.
    await pumpWorkout(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.selection.baseOffset, 0);
    expect(
      field.controller!.selection.extentOffset,
      field.controller!.text.length,
    );

    await disposeApp(tester);
  });

  testWidgets('the set just logged stays reachable during the rest',
      (tester) async {
    // Logging advances the cursor at once, so the rest is spent looking at
    // the *next* exercise. The set just finished used to be unreachable until
    // its exercise came round again two steps later.
    await pumpWorkout(tester);
    await tester.enterText(find.byType(TextField).first, '7');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Just logged'), findsOneWidget);
    expect(find.textContaining('Scapular Pulls set 1'), findsOneWidget);

    await tester.tap(find.textContaining('Just logged'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField(0), '9');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    expect(
      sets.firstWhere((s) => s.pathId == 'pullup').repsCompleted,
      9,
      reason: 'corrected without waiting for the exercise to come round',
    );

    await disposeApp(tester);
  });

  testWidgets('a logged set can have its weight corrected', (tester) async {
    // Weight is per set in the schema, but there was no way to change it once
    // logged — so a set recorded at the wrong load stayed wrong and fed the
    // load-progression evaluation that way.
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'weighted_pullups',
    );
    await pumpWorkout(tester);

    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Just logged'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField(1), '25');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    expect(
      sets.firstWhere((s) => s.pathId == 'pullup').weightKg,
      closeTo(poundsToKg(25), 1e-9),
    );

    await disposeApp(tester);
  });

  testWidgets('a timed exercise offers a stopwatch that fills the field',
      (tester) async {
    // A plank is held until failure — the number is not known in advance, and
    // watching a clock while shaking is not a plan.
    await db.saveProgressionConfig(
      pathId: 'antiextension',
      branchId: 'rings',
      exerciseId: 'planks',
    );
    await pumpWorkout(tester);
    await skipToTriplet(tester);

    expect(find.text('Start hold'), findsOneWidget);
    await tester.tap(find.text('Start hold'));
    await tester.pumpAndSettle();

    clock.advance(const Duration(seconds: 42));
    ticker.tick();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '42');

    await disposeApp(tester);
  });
}
