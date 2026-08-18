import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/main.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/timer_providers.dart';

/// The dashboard's Begin-workout wiring: the session clock and the wakelock.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeTicker ticker;
  late FakeScreenWake wake;

  setUp(() {
    db = AppDatabase.memory();
    clock = FakeClock();
    ticker = FakeTicker();
    wake = FakeScreenWake();
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          tickerProvider.overrideWithValue(ticker),
          alertsProvider.overrideWithValue(RecordingAlerts()),
          screenWakeProvider.overrideWithValue(wake),
        ],
        child: const TripleRApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('the dashboard shows the planned session', (tester) async {
    await pumpApp(tester);

    expect(find.text('Workout 1 of 3'), findsOneWidget);
    // Pair 1 on rotation 0, rendered as the exercises a beginner starts at.
    expect(find.textContaining('Scapular Pulls'), findsOneWidget);
    expect(find.textContaining('Assisted Squats'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('beginning a workout holds the screen awake and opens the warmup',
      (tester) async {
    await pumpApp(tester);
    expect(wake.isEnabled, isFalse);

    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();

    expect(find.text('Warmup'), findsOneWidget);
    expect(wake.isEnabled, isTrue, reason: 'the screen must stay on mid-set');

    await disposeApp(tester);
  });

  testWidgets('the session clock runs while the warmup is open', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();

    expect(find.text('0:00'), findsOneWidget);

    clock.advance(const Duration(minutes: 3, seconds: 20));
    ticker.tick();
    await tester.pumpAndSettle();

    expect(find.text('3:20'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('backing out of the warmup releases the wakelock but keeps the '
      'session resumable', (tester) async {
    // The session row survives so nothing logged is lost, but the screen must
    // not stay pinned on after the user walks away.
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();
    expect(wake.isEnabled, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(wake.isEnabled, isFalse);
    expect(find.text('Workout in progress'), findsOneWidget);
    expect(await db.inProgressSession, isNotNull);

    await disposeApp(tester);
  });

  testWidgets('the session clock and wakelock survive the warmup handoff',
      (tester) async {
    // The regression this file exists for. The warmup used to
    // `pushReplacement` itself with the workout screen, which completes the
    // *replaced* route's popped future — so the dashboard's teardown ran the
    // moment the user tapped through, freezing the clock at 0:00 and letting
    // the screen sleep for the rest of the workout.
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();

    clock.advance(const Duration(minutes: 2));
    ticker.tick();
    await tester.pumpAndSettle();
    expect(find.text('2:00'), findsOneWidget);

    await tester.tap(find.text('Skip to workout'));
    await tester.pumpAndSettle();

    clock.advance(const Duration(minutes: 1));
    ticker.tick();
    await tester.pumpAndSettle();

    expect(find.text('3:00'), findsOneWidget,
        reason: 'the clock keeps running across the handoff');
    expect(wake.isEnabled, isTrue,
        reason: 'the screen must stay awake for the whole workout');

    await disposeApp(tester);
  });

  testWidgets('leaving the workout stops the clock and the wakelock',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip to workout'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(wake.isEnabled, isFalse);
    expect(find.text('Workout in progress'), findsOneWidget,
        reason: 'the session is still resumable');

    await disposeApp(tester);
  });

  testWidgets('the warmup checklist resets when the session is resumed',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wrist Prep'));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Resuming goes straight to the workout, so the stale tick is gone with
    // the checklist rather than lingering into the next visit.
    expect(find.text('1/4'), findsNothing);

    await disposeApp(tester);
  });
}
