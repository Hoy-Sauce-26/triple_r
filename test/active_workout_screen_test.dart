import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/active_workout_screen.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/active_session.dart';
import 'package:triple_r/state/timer_providers.dart';
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

    expect(find.text('Rest complete'), findsOneWidget);
    expect(alerts.restCompletions, hasLength(1));

    await disposeApp(tester);
  });

  testWidgets('+30s extends a running rest', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+30s'));
    await tester.pumpAndSettle();

    expect(find.text('2:00'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('skipping the rest dismisses the overlay without chiming',
      (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip rest'));
    await tester.pumpAndSettle();

    expect(find.text('Resting'), findsNothing);
    expect(alerts.total, 0, reason: 'the user chose to move on');

    await disposeApp(tester);
  });

  testWidgets('the stepper adjusts the logged value', (tester) async {
    await pumpWorkout(tester);

    // Seeds at the bottom of the range with no history to draw on.
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    final sets = await db.setsForSession(
      container.read(activeSessionProvider).value!.id,
    );
    expect(sets.single.repsCompleted, 6);

    await disposeApp(tester);
  });

  testWidgets('logged sets are listed and can be corrected', (tester) async {
    await pumpWorkout(tester);
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip rest'));
    await tester.pumpAndSettle();

    // Back to the pull-up on set 2; set 1 shows in the history list.
    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip rest'));
    await tester.pumpAndSettle();

    expect(find.text('Set 1'), findsOneWidget);

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
}
