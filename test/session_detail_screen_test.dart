import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/session_detail_screen.dart';
import 'package:triple_r/state/timer_providers.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/theme.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 3, 10, 9))),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: lightTheme,
          home: const SessionDetailScreen(sessionId: 's1'),
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

  Future<void> addSet({
    required String id,
    required String pathId,
    required String exerciseId,
    required int reps,
    double? weightKg,
  }) =>
      db.into(db.setRecords).insert(
            SetRecordsCompanion.insert(
              id: id,
              sessionId: 's1',
              pathId: pathId,
              exerciseId: exerciseId,
              setIndex: 1,
              repsCompleted: Value(reps),
              weightKg: Value(weightKg),
              recordedAt: DateTime(2026, 3, 10, 9, 5),
            ),
          );

  setUp(() async {
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: 's1',
            startedAt: DateTime(2026, 3, 10, 9),
            endedAt: Value(DateTime(2026, 3, 10, 9, 45)),
            status: 'completed',
            rotationIndex: 0,
            pairRestSeconds: 90,
            tripletRestSeconds: 60,
          ),
        );
  });

  testWidgets('shows the load on an exercise that takes one', (tester) async {
    await addSet(
      id: 'a',
      pathId: 'dip',
      exerciseId: 'weighted_dips',
      reps: 8,
      weightKg: 20,
    );
    await pump(tester);

    expect(find.textContaining('@'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('never shows a load on an exercise that cannot take one',
      (tester) async {
    // A bodyweight row can still be carrying a number — a zero written before
    // weights were nullable, or a branch that changed under the path — and
    // "9 @ 0 lb" on a push-up is nonsense the user cannot correct here,
    // because the edit dialog gates its weight field on the same flag.
    await addSet(
      id: 'a',
      pathId: 'pushup',
      exerciseId: 'full_pushups',
      reps: 9,
      weightKg: 0,
    );
    await pump(tester);

    expect(find.text('9'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('shows a deliberate zero where zero is a real answer',
      (tester) async {
    // Zero on a loadable exercise is a choice, not an empty field: it is how
    // someone records dropping back to bare bodyweight on an exercise they
    // normally load.
    await addSet(
      id: 'a',
      pathId: 'dip',
      exerciseId: 'weighted_dips',
      reps: 8,
      weightKg: 0,
    );
    await pump(tester);

    expect(find.textContaining('@'), findsOneWidget);
    await disposeApp(tester);
  });
}
