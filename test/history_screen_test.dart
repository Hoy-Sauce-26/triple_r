import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/history_screen.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/state/timer_providers.dart';
import 'package:triple_r/theme.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeClock clock;

  setUp(() {
    db = AppDatabase.memory();
    clock = FakeClock(DateTime(2026, 3, 10, 9));
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: lightTheme, home: const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Dispose before the final pump — disposing the container cancels drift's
  /// query streams, which schedules a zero-duration timer that must be
  /// flushed or the test fails on `!timersPending`.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(Duration.zero);
  }

  Future<void> addSession({
    required String id,
    required DateTime at,
    String status = 'completed',
    int sets = 3,
  }) async {
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: id,
            startedAt: at,
            endedAt: Value(at.add(const Duration(minutes: 45))),
            status: status,
            rotationIndex: 0,
            pairRestSeconds: 90,
            tripletRestSeconds: 60,
          ),
        );
    for (var i = 1; i <= sets; i++) {
      await db.into(db.setRecords).insert(
            SetRecordsCompanion.insert(
              id: '$id-set-$i',
              sessionId: id,
              pathId: 'pushup',
              exerciseId: 'full_pushups',
              setIndex: i,
              repsCompleted: Value(5 + i),
              recordedAt: at.add(Duration(minutes: i)),
            ),
          );
    }
  }

  testWidgets('shows an empty state before anything is logged', (tester) async {
    await pump(tester);

    expect(find.textContaining('No workouts yet'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('lists finished sessions, newest first', (tester) async {
    await addSession(id: 's1', at: DateTime(2026, 3, 1, 9));
    await addSession(id: 's2', at: DateTime(2026, 3, 8, 9));
    await pump(tester);

    expect(find.text('8/3/2026'), findsOneWidget);
    expect(find.text('1/3/2026'), findsOneWidget);

    final first = tester.getTopLeft(find.text('8/3/2026')).dy;
    final second = tester.getTopLeft(find.text('1/3/2026')).dy;
    expect(first, lessThan(second), reason: 'newest at the top');

    await disposeApp(tester);
  });

  testWidgets('marks an abandoned session rather than hiding it',
      (tester) async {
    // The sets in it are real work; hiding them would make the history look
    // like the day was skipped.
    await addSession(
      id: 's1',
      at: DateTime(2026, 3, 1, 9),
      status: 'abandoned',
      sets: 2,
    );
    await pump(tester);

    expect(find.text('Ended early'), findsOneWidget);
    expect(find.textContaining('2 sets'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('an in-progress session stays out of history', (tester) async {
    // That one belongs to the dashboard's resume banner.
    await addSession(id: 'live', at: DateTime(2026, 3, 9, 9), status: 'in_progress');
    await pump(tester);

    expect(find.textContaining('No workouts yet'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('opens a session detail on tap', (tester) async {
    await addSession(id: 's1', at: DateTime(2026, 3, 1, 9));
    await pump(tester);

    await tester.tap(find.text('1/3/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('Full Push-ups'), findsOneWidget);
    // Three chips, one per set.
    expect(find.text('6'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    await disposeApp(tester);
  });

  group('progress tab', () {
    testWidgets('prompts for data before anything is logged', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Log a workout'), findsOneWidget);
      expect(find.textContaining('Nothing logged yet'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('charts body weight once there are two entries',
        (tester) async {
      await db.addBodyWeight(
        id: 'bw-1',
        weightKg: 82,
        recordedAt: DateTime(2026, 3, 1),
      );
      await pump(tester);
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a trend needs two'), findsOneWidget);

      await db.addBodyWeight(
        id: 'bw-2',
        weightKg: 81.4,
        recordedAt: DateTime(2026, 3, 8),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('a trend needs two'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('lists advancements instead of drawing them', (tester) async {
      await addSession(id: 's1', at: DateTime(2026, 3, 1, 9), sets: 1);
      await db.into(db.setRecords).insert(
            SetRecordsCompanion.insert(
              id: 'advanced',
              sessionId: 's1',
              pathId: 'pushup',
              exerciseId: 'diamond_pushups',
              setIndex: 2,
              repsCompleted: const Value(5),
              recordedAt: DateTime(2026, 3, 1, 9, 30),
            ),
          );
      await pump(tester);
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      // The card sits below two charts, and a ListView never builds what is
      // off screen — so this has to scroll rather than just look.
      await tester.scrollUntilVisible(
        find.text('Progressions'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Progressions'), findsOneWidget);
      expect(
        find.textContaining('Diamond Push-ups — from Full Push-ups'),
        findsOneWidget,
      );

      await disposeApp(tester);
    });
  });
}
