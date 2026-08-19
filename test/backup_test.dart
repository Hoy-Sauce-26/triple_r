import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/domain/backup.dart';

/// Export and import. The riskiest code in the app: import deletes everything
/// first, so a bug here costs a user their training history outright.
void main() {
  late AppDatabase db;

  // The round-trip test deliberately opens a second database — importing onto
  // a new phone is the whole point — and drift's warning about that is noise
  // here, not a signal.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// Fills the database with one of everything, so a round-trip that drops a
  /// table fails rather than passing on an empty set.
  Future<void> seed() async {
    await db.updateProfile(
      const UserProfilesCompanion(
        unitSystem: Value('metric'),
        defaultPairRestSeconds: Value(120),
        rotatePairOrder: Value(false),
      ),
    );
    await db.addBodyWeight(
      id: 'bw-1',
      weightKg: 81.6,
      recordedAt: DateTime(2026, 3, 1),
    );
    await db.saveProgressionConfig(
      pathId: 'hinge',
      branchId: 'barbell',
      exerciseId: null,
      now: DateTime(2026, 3, 1),
    );
    await db.saveExerciseState(
      'barbell_deadlift',
      workingLoadKg: 102.5,
      lastIncrementKg: 4.5359237,
      consecutiveFailures: 1,
      masteredAt: DateTime(2026, 2, 20),
      now: DateTime(2026, 3, 1),
    );
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: 'session-1',
            startedAt: DateTime(2026, 3, 1, 9),
            endedAt: Value(DateTime(2026, 3, 1, 10)),
            status: 'completed',
            rotationIndex: 2,
            pairRestSeconds: 90,
            tripletRestSeconds: 60,
          ),
        );
    await db.into(db.setRecords).insert(
          SetRecordsCompanion.insert(
            id: 'set-1',
            sessionId: 'session-1',
            pathId: 'pushup',
            exerciseId: 'full_pushups',
            setIndex: 1,
            repsCompleted: const Value(8),
            weightKg: const Value(0),
            recordedAt: DateTime(2026, 3, 1, 9, 30),
          ),
        );
    await db.into(db.setRecords).insert(
          SetRecordsCompanion.insert(
            id: 'set-2',
            sessionId: 'session-1',
            pathId: 'antiextension',
            exerciseId: 'planks',
            setIndex: 1,
            holdSeconds: const Value(45),
            recordedAt: DateTime(2026, 3, 1, 9, 40),
          ),
        );
  }

  group('export', () {
    test('produces readable JSON with a format version', () async {
      await seed();
      final json = await exportBackup(db, now: DateTime(2026, 3, 2));
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['formatVersion'], backupFormatVersion);
      expect(decoded['exportedAt'], startsWith('2026-03-02'));
      expect(decoded['sets'], hasLength(2));
      expect(json, contains('\n  '), reason: 'indented so a human can read it');
    });

    test('names the file by date so backups sort chronologically', () {
      expect(
        backupFileName(DateTime(2026, 3, 7)),
        'triple-r-2026-03-07.json',
      );
    });
  });

  group('round-trip', () {
    test('restores every table exactly', () async {
      await seed();
      final json = await exportBackup(db, now: DateTime(2026, 3, 2));

      // Wipe by importing into a *different* database, which is the real
      // scenario — a new phone, not the one that made the backup.
      final fresh = AppDatabase.memory();
      addTearDown(fresh.close);
      await restoreBackup(fresh, json);

      final profile = await fresh.profile;
      expect(profile.unitSystem, 'metric');
      expect(profile.defaultPairRestSeconds, 120);
      expect(profile.rotatePairOrder, isFalse);

      expect(await fresh.select(fresh.bodyWeightEntries).get(), hasLength(1));

      final config = (await fresh.progressionConfigsAll).single;
      expect(config.selectedBranchId, 'barbell');
      expect(config.selectedExerciseId, isNull,
          reason: 'alternating branches carry a null exercise');

      final state = await fresh.exerciseState('barbell_deadlift');
      expect(state!.workingLoadKg, closeTo(102.5, 1e-9));
      expect(state.lastIncrementKg, closeTo(4.5359237, 1e-9),
          reason: 'a remembered increment must survive JSON exactly');
      expect(state.consecutiveFailures, 1);
      expect(state.masteredAt, DateTime(2026, 2, 20));

      final session = (await fresh.select(fresh.workoutSessions).get()).single;
      expect(session.rotationIndex, 2);
      expect(session.endedAt, DateTime(2026, 3, 1, 10));

      final sets = await fresh.setsForSession('session-1');
      expect(sets, hasLength(2));
      expect(sets.firstWhere((s) => s.exerciseId == 'planks').holdSeconds, 45);
      expect(
        sets.firstWhere((s) => s.exerciseId == 'full_pushups').repsCompleted,
        8,
      );
    });

    test('importing twice is idempotent, not additive', () async {
      await seed();
      final json = await exportBackup(db);

      await restoreBackup(db, json);
      await restoreBackup(db, json);

      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      expect(await db.select(db.setRecords).get(), hasLength(2));
      expect(await db.select(db.userProfiles).get(), hasLength(1),
          reason: 'the singleton profile must not be duplicated');
    });

    test('replaces rather than merges', () async {
      final json = await exportBackup(db, now: DateTime(2026, 3, 2));

      // Now build up local data that the (empty) backup should wipe out.
      await seed();
      expect(await db.select(db.workoutSessions).get(), isNotEmpty);

      await restoreBackup(db, json);

      expect(await db.select(db.workoutSessions).get(), isEmpty);
      expect(await db.select(db.setRecords).get(), isEmpty);
      expect(await db.select(db.bodyWeightEntries).get(), isEmpty);
      expect((await db.profile).unitSystem, 'imperial',
          reason: 'the backup carries its own settings');
    });

    test('a weight written as a whole number survives', () async {
      // JSON encodes 80.0 as `80`, which decodes as int and would crash a
      // cast to double.
      await db.addBodyWeight(
        id: 'bw-round',
        weightKg: 80,
        recordedAt: DateTime(2026, 3, 1),
      );
      final json = await exportBackup(db);
      expect(json, contains('"weightKg": 80'));

      await restoreBackup(db, json);
      final entry = (await db.select(db.bodyWeightEntries).get()).single;
      expect(entry.weightKg, 80.0);
    });
  });

  group('inspect', () {
    test('reports what is in the file without touching the database', () async {
      await seed();
      final json = await exportBackup(db, now: DateTime(2026, 3, 2));

      final summary = inspectBackup(json);
      expect(summary.sessionCount, 1);
      expect(summary.setCount, 2);
      expect(summary.bodyWeightCount, 1);
      expect(summary.exportedAt, DateTime(2026, 3, 2));
    });

    test('rejects a file from a newer format version', () async {
      final json = jsonEncode({
        'formatVersion': backupFormatVersion + 1,
        'sessions': <dynamic>[],
      });
      expect(
        () => inspectBackup(json),
        throwsA(
          isA<BackupError>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('rejects arbitrary JSON and arbitrary text', () {
      expect(() => inspectBackup('not json at all'), throwsA(isA<BackupError>()));
      expect(() => inspectBackup('{"hello": 1}'), throwsA(isA<BackupError>()));
      expect(() => inspectBackup('[1, 2, 3]'), throwsA(isA<BackupError>()));
    });
  });

  group('failure handling', () {
    test('a malformed backup leaves existing data intact', () async {
      await seed();

      // Valid envelope, corrupt payload — a set with no timestamp.
      final json = jsonEncode({
        'formatVersion': backupFormatVersion,
        'profile': <String, dynamic>{},
        'sessions': [
          {
            'id': 's1',
            'startedAt': DateTime(2026, 3, 1).toIso8601String(),
            'status': 'completed',
            'rotationIndex': 0,
            'pairRestSeconds': 90,
            'tripletRestSeconds': 60,
          },
        ],
        'sets': [
          {
            'id': 'bad',
            'sessionId': 's1',
            'pathId': 'pushup',
            'exerciseId': 'full_pushups',
            'setIndex': 1,
            'repsCompleted': 8,
            // recordedAt deliberately missing.
          },
        ],
      });

      await expectLater(restoreBackup(db, json), throwsA(isA<BackupError>()));

      // The whole restore runs in one transaction, so the failure rolls the
      // wipe back rather than leaving the user with nothing.
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      expect((await db.select(db.workoutSessions).get()).single.id, 'session-1');
      expect(await db.select(db.setRecords).get(), hasLength(2));
    });

    test('a set referencing a missing session is rejected', () async {
      await seed();
      final json = jsonEncode({
        'formatVersion': backupFormatVersion,
        'profile': <String, dynamic>{},
        'sessions': <dynamic>[],
        'sets': [
          {
            'id': 'orphan',
            'sessionId': 'nope',
            'pathId': 'pushup',
            'exerciseId': 'full_pushups',
            'setIndex': 1,
            'repsCompleted': 8,
            'recordedAt': DateTime(2026, 3, 1).toIso8601String(),
          },
        ],
      });

      await expectLater(restoreBackup(db, json), throwsA(anything));
      expect(await db.select(db.workoutSessions).get(), hasLength(1),
          reason: 'rolled back');
    });
  });
}
