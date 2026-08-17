import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/warmup_screen.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/notifications.dart';
import 'package:triple_r/services/screen_wake.dart';
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

  Future<void> pumpWarmup(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          tickerProvider.overrideWithValue(ticker),
          alertsProvider.overrideWithValue(alerts),
          screenWakeProvider.overrideWithValue(FakeScreenWake()),
          restNotificationsProvider.overrideWithValue(FakeRestNotifications()),
        ],
        child: MaterialApp(theme: lightTheme, home: const WarmupScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// See README — Riverpod disposing drift's query stream schedules a timer
  /// that outlives the fake clock unless the tree is torn down in-test.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows only the unlocked warmup items', (tester) async {
    await pumpWarmup(tester);

    expect(find.text('Shoulder Dislocates'), findsOneWidget);
    expect(find.text('Deadbugs'), findsOneWidget);
    // Gated behind Pull-up Eccentrics, which a fresh install has not reached.
    expect(find.text('Arch Hangs'), findsNothing);
    expect(find.text('0/4'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('reveals a gated item once its trigger is reached', (tester) async {
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'pullup_eccentrics',
    );
    await pumpWarmup(tester);

    expect(find.text('Arch Hangs'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('ticking items updates the counter', (tester) async {
    await pumpWarmup(tester);

    await tester.tap(find.text('Wrist Prep'));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);

    await tester.tap(find.text('Wrist Prep'));
    await tester.pumpAndSettle();
    expect(find.text('0/4'), findsOneWidget, reason: 'tapping again unticks it');

    await disposeApp(tester);
  });

  testWidgets('a timed hold counts down, chimes, and ticks itself off',
      (tester) async {
    await pumpWarmup(tester);

    // Deadbugs is the only timed item a beginner sees.
    await tester.tap(find.byTooltip('Start 30s hold'));
    await tester.pumpAndSettle();
    expect(find.text('0:30'), findsOneWidget);

    clock.advance(const Duration(seconds: 10));
    ticker.tick();
    await tester.pumpAndSettle();
    expect(find.text('0:20'), findsOneWidget);

    clock.advance(const Duration(seconds: 20));
    ticker.tick();
    await tester.pumpAndSettle();

    expect(alerts.holdCompletions, hasLength(1));
    expect(alerts.restCompletions, isEmpty, reason: 'a hold is the softer cue');
    expect(find.text('1/4'), findsOneWidget, reason: 'completing ticks it off');

    await disposeApp(tester);
  });

  testWidgets('stopping a hold early stays silent and leaves it unticked',
      (tester) async {
    await pumpWarmup(tester);

    await tester.tap(find.byTooltip('Start 30s hold'));
    await tester.pumpAndSettle();

    clock.advance(const Duration(seconds: 5));
    ticker.tick();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    expect(alerts.total, 0);
    expect(find.text('0/4'), findsOneWidget);
    expect(find.byTooltip('Start 30s hold'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('the finish button waits for the whole list', (tester) async {
    await pumpWarmup(tester);

    final button = find.widgetWithText(FloatingActionButton, 'Finish the list');
    expect(button, findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(button).onPressed,
      isNull,
      reason: 'disabled until every item is done',
    );

    for (final name in ['Shoulder Dislocates', 'Squat Sky Reaches', 'Wrist Prep']) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Start 30s hold'));
    await tester.pumpAndSettle();
    clock.advance(const Duration(seconds: 30));
    ticker.tick();
    await tester.pumpAndSettle();

    expect(find.text('4/4'), findsOneWidget);
    final done = find.widgetWithText(FloatingActionButton, 'Warmup done');
    expect(tester.widget<FloatingActionButton>(done).onPressed, isNotNull);

    await disposeApp(tester);
  });
}
