import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/main.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/notifications.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/timer_providers.dart';

/// The dashboard's Begin-workout wiring: the session clock, the wakelock, and
/// the notification permission prompt.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late FakeTicker ticker;
  late FakeScreenWake wake;
  late FakeRestNotifications notifications;

  setUp(() {
    db = AppDatabase.memory();
    clock = FakeClock();
    ticker = FakeTicker();
    wake = FakeScreenWake();
    notifications = FakeRestNotifications();
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
          restNotificationsProvider.overrideWithValue(notifications),
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
    expect(notifications.initialised || notifications.permissionGranted, isTrue);

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

  testWidgets('leaving the warmup releases the wakelock', (tester) async {
    // Otherwise a user who backs out mid-warmup leaves the screen pinned on
    // until the battery dies.
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();
    expect(wake.isEnabled, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(wake.isEnabled, isFalse);
    expect(find.text('Begin workout'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the warmup checklist resets between workouts', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wrist Prep'));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin workout'));
    await tester.pumpAndSettle();

    expect(find.text('0/4'), findsOneWidget);

    await disposeApp(tester);
  });
}
