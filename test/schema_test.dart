import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';

/// Round-trips and constraint checks for the Phase 1 tables.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<String> insertSession({String status = 'completed'}) async {
    final id = 'session-$status-${DateTime.now().microsecondsSinceEpoch}';
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: id,
            startedAt: DateTime(2026, 3, 1, 9),
            status: status,
            rotationIndex: 0,
            pairRestSeconds: 90,
            tripletRestSeconds: 60,
          ),
        );
    return id;
  }

  Future<void> insertSet(
    String sessionId, {
    int? reps = 8,
    int? hold,
    double weight = 0,
    String exerciseId = 'full_pushups',
    int index = 1,
  }) {
    return db.into(db.setRecords).insert(
          SetRecordsCompanion.insert(
            id: 'set-$sessionId-$index-$exerciseId',
            sessionId: sessionId,
            pathId: 'pushup',
            exerciseId: exerciseId,
            setIndex: index,
            repsCompleted: Value(reps),
            holdSeconds: Value(hold),
            weightKg: Value(weight),
            recordedAt: DateTime(2026, 3, 1, 9, 10),
          ),
        );
  }

  group('progression configs', () {
    test('round-trip, including a null exercise for alternating branches', () async {
      await db.saveProgressionConfig(
        pathId: 'hinge',
        branchId: 'barbell',
        exerciseId: null,
        now: DateTime(2026, 3, 1),
      );

      final rows = await db.progressionConfigsAll;
      expect(rows, hasLength(1));
      expect(rows.single.selectedBranchId, 'barbell');
      expect(rows.single.selectedExerciseId, isNull);
    });

    test('saving the same path twice updates rather than duplicating', () async {
      await db.saveProgressionConfig(
        pathId: 'squat',
        branchId: 'bodyweight',
        exerciseId: 'split_squats',
      );
      await db.saveProgressionConfig(
        pathId: 'squat',
        branchId: 'pistol',
        exerciseId: 'pistol_squats',
      );

      final rows = await db.progressionConfigsAll;
      expect(rows, hasLength(1));
      expect(rows.single.selectedBranchId, 'pistol');
    });
  });

  group('exercise state', () {
    test('is absent until written, then round-trips', () async {
      expect(await db.exerciseState('barbell_deadlift'), isNull);

      await db.saveExerciseState(
        'barbell_deadlift',
        workingLoadKg: 84.5,
        lastIncrementKg: 4.53592,
        now: DateTime(2026, 3, 1),
      );

      final state = await db.exerciseState('barbell_deadlift');
      expect(state!.workingLoadKg, closeTo(84.5, 1e-9));
      expect(state.lastIncrementKg, closeTo(4.53592, 1e-9));
      expect(state.consecutiveFailures, 0);
    });

    test('the two alternating hinge exercises keep independent state', () async {
      // The concrete reason this table is keyed by exercise and not by path.
      await db.saveExerciseState('barbell_romanian_deadlift', workingLoadKg: 60);
      await db.saveExerciseState('barbell_deadlift', workingLoadKg: 100);

      expect((await db.exerciseState('barbell_romanian_deadlift'))!.workingLoadKg, 60);
      expect((await db.exerciseState('barbell_deadlift'))!.workingLoadKg, 100);
    });

    test('partial updates leave other columns alone', () async {
      await db.saveExerciseState('weighted_dips', workingLoadKg: 20, lastIncrementKg: 1.1);
      await db.saveExerciseState('weighted_dips', consecutiveFailures: 2);

      final state = await db.exerciseState('weighted_dips');
      expect(state!.consecutiveFailures, 2);
      expect(state.workingLoadKg, 20, reason: 'load should survive the update');
      expect(state.lastIncrementKg, closeTo(1.1, 1e-9));
    });
  });

  group('sessions', () {
    test('only completed sessions count toward the rotation', () async {
      await insertSession(status: 'completed');
      await insertSession(status: 'completed');
      await insertSession(status: 'abandoned');
      await insertSession(status: 'in_progress');

      expect(await db.completedSessionCount(), 2);
    });

    test('finds an in-progress session for resume', () async {
      await insertSession(status: 'completed');
      expect(await db.inProgressSession, isNull);

      final id = await insertSession(status: 'in_progress');
      expect((await db.inProgressSession)!.id, id);
    });

    test('endedAt stays null while in progress', () async {
      final id = await insertSession(status: 'in_progress');
      final session = await (db.select(db.workoutSessions)
            ..where((s) => s.id.equals(id)))
          .getSingle();
      expect(session.endedAt, isNull);
      expect(session.cursorJson, isNull);
    });
  });

  group('set records', () {
    test('reps and holds are mutually exclusive', () async {
      final id = await insertSession();

      // Both set → rejected.
      await expectLater(
        insertSet(id, reps: 8, hold: 30, index: 1),
        throwsA(_checkViolation),
      );
      // Neither set → also rejected.
      await expectLater(
        insertSet(id, reps: null, hold: null, index: 2),
        throwsA(_checkViolation),
      );
    });

    test('accepts a rep set and a timed set independently', () async {
      final id = await insertSession();
      await insertSet(id, reps: 8, index: 1);
      await insertSet(id, reps: null, hold: 45, exerciseId: 'planks', index: 2);

      final rows = await db.select(db.setRecords).get();
      expect(rows, hasLength(2));
      expect(rows.firstWhere((r) => r.exerciseId == 'planks').holdSeconds, 45);
    });

    test('values above the target range are stored as performed', () async {
      // Targets are targets, not caps — see docs/PLAN.md §2.1.
      final id = await insertSession();
      await insertSet(id, reps: 14, index: 1);
      await insertSet(id, reps: null, hold: 95, exerciseId: 'planks', index: 2);

      final rows = await db.select(db.setRecords).get();
      expect(rows.firstWhere((r) => r.exerciseId == 'full_pushups').repsCompleted, 14);
      expect(rows.firstWhere((r) => r.exerciseId == 'planks').holdSeconds, 95);
    });

    test('deleting a session cascades to its sets', () async {
      final id = await insertSession();
      await insertSet(id, index: 1);
      await insertSet(id, index: 2);
      expect(await db.select(db.setRecords).get(), hasLength(2));

      await (db.delete(db.workoutSessions)..where((s) => s.id.equals(id))).go();

      expect(await db.select(db.setRecords).get(), isEmpty);
    });

    test('a set cannot reference a session that does not exist', () async {
      await expectLater(insertSet('no-such-session'), throwsA(anything));
    });

    test('per-set weight is independent of the working load', () async {
      // Raising a working weight must not rewrite what past sets recorded.
      final id = await insertSession();
      await insertSet(id, weight: 40, exerciseId: 'weighted_dips', index: 1);
      await db.saveExerciseState('weighted_dips', workingLoadKg: 45);

      final row = await db.select(db.setRecords).getSingle();
      expect(row.weightKg, 40);
      expect((await db.exerciseState('weighted_dips'))!.workingLoadKg, 45);
    });
  });

  group('body weight entries', () {
    test('round-trip in recorded order', () async {
      for (final (i, kg) in [82.1, 81.6, 81.9].indexed) {
        await db.into(db.bodyWeightEntries).insert(
              BodyWeightEntriesCompanion.insert(
                id: 'bw-$i',
                recordedAt: DateTime(2026, 3, i + 1),
                weightKg: kg,
              ),
            );
      }

      final rows = await (db.select(db.bodyWeightEntries)
            ..orderBy([(t) => OrderingTerm(expression: t.recordedAt)]))
          .get();
      expect(rows.map((r) => r.weightKg), [82.1, 81.6, 81.9]);
    });
  });

  test('migrating from v1 keeps the profile row and adds the new tables',
      () async {
    // A v1 install already has user_profile; the upgrade must add the rest
    // without disturbing it, because exported backups replay these steps.
    final profile = await db.profile;
    expect(profile.unitSystem, 'imperial');

    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'full_pullups',
    );
    expect(await db.progressionConfigsAll, hasLength(1));
  });
}

final _checkViolation = predicate(
  (e) => e.toString().contains('CHECK constraint failed'),
  'a SQLite CHECK constraint violation',
);

