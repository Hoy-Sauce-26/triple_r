import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/active_workout_screen.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/haptics.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/active_session.dart';
import 'package:triple_r/state/timer_providers.dart';
import 'package:triple_r/theme.dart';

/// Haptics are feedback the user feels rather than sees, which makes them
/// exactly the kind of thing that rots unnoticed. These pin the two moments
/// that carry meaning.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late RecordingHaptics haptics;

  setUp(() {
    db = AppDatabase.memory();
    haptics = RecordingHaptics();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hapticsProvider.overrideWithValue(haptics),
        alertsProvider.overrideWithValue(RecordingAlerts()),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 3, 1, 9))),
        tickerProvider.overrideWithValue(FakeTicker()),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await container.read(activeSessionProvider.notifier).start();
    await container.read(activeSessionProvider.notifier).completeWarmup();
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

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(Duration.zero);
  }

  testWidgets('logging a set confirms by touch', (tester) async {
    await pump(tester);
    expect(haptics.total, 0);

    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    expect(haptics.confirmCount, 1);
    expect(haptics.warnCount, 0, reason: 'logging a set is not a warning');
    await disposeApp(tester);
  });

  testWidgets('ending early warns before the dialog appears', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End workout early'));
    await tester.pumpAndSettle();

    expect(haptics.warnCount, 1);
    expect(find.text('End workout early?'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('a failing haptic never interrupts the action', (tester) async {
    // A device with no vibrator, a user who disabled system haptics, or a
    // channel that simply never answers. The call site uses `ignore()` rather
    // than `await` precisely so none of those can sit between the tap and the
    // set being written.
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hapticsProvider.overrideWithValue(_ThrowingHaptics()),
        alertsProvider.overrideWithValue(RecordingAlerts()),
        screenWakeProvider.overrideWithValue(FakeScreenWake()),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 3, 1, 9))),
        tickerProvider.overrideWithValue(FakeTicker()),
      ],
    );
    await pump(tester);

    await tester.tap(find.text('Log set'));
    await tester.pumpAndSettle();

    // The set still reached the database, which is the part that matters.
    expect(await db.select(db.setRecords).get(), hasLength(1));
    await disposeApp(tester);
  });
}

/// Stands in for a platform channel that rejects the call.
class _ThrowingHaptics implements Haptics {
  @override
  Future<void> confirm() async => throw StateError('no vibrator');

  @override
  Future<void> warn() async => throw StateError('no vibrator');

  @override
  Future<void> transition() async => throw StateError('no vibrator');
}
