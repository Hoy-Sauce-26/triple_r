import 'dart:collection';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// The app's local SQLite database. Everything Triple R knows lives here;
/// there is no network layer and no remote copy.
///
/// Every schema change needs a [schemaVersion] bump *and* a step in
/// [migration], even pre-release. Exported backups carry their schema version
/// and are re-imported through these same migrations, so a skipped step breaks
/// restore on someone else's device rather than failing loudly here.
@DriftDatabase(
  tables: [
    UserProfiles,
    BodyWeightEntries,
    ProgressionConfigs,
    ExerciseStates,
    WorkoutSessions,
    SetRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// An in-memory database that lives and dies with the test using it.
  ///
  /// Tests construct this directly instead of touching the file system, which
  /// is what lets database tests run on the host VM rather than a device.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes(m);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(bodyWeightEntries);
            await m.createTable(progressionConfigs);
            await m.createTable(exerciseStates);
            await m.createTable(workoutSessions);
            await m.createTable(setRecords);
            await _createIndexes(m);
          }
          if (from < 3) {
            await m.addColumn(exerciseStates, exerciseStates.masteredAt);
          }
          if (from < 4) {
            await m.addColumn(workoutSessions, workoutSessions.sessionOrdinal);
          }
          if (from < 5) {
            // Height was dropped. SQLite cannot drop a column in place at the
            // versions this supports, so the table is rebuilt from the
            // current schema and the surviving columns copied across.
            await m.alterTable(TableMigration(userProfiles));
          }
          if (from < 6) {
            await m.addColumn(userProfiles, userProfiles.plannedRotationIndex);
          }
          if (from < 7) {
            await m.addColumn(userProfiles, userProfiles.loadIncrementKg);
            // set_records.weight_kg went from NOT NULL DEFAULT 0 to nullable,
            // so null can mean "no weight entered" as distinct from a
            // deliberate zero. Widening a column is still a table rebuild in
            // SQLite.
            await m.alterTable(TableMigration(setRecords));
            // The rebuild drops the table's indexes with the old table.
            await _createIndexes(m);
            // Then every stored zero becomes null. Under the old schema the
            // column could not be empty and the UI could not enter a zero, so
            // a zero there never meant "lifted nothing" — it meant the column
            // had a default and nobody filled it. Copying those across as
            // deliberate zeros put "@ 0 lb" on every push-up ever logged.
            // Only rows written from v7 onward can mean it.
            await (update(setRecords)..where((s) => s.weightKg.equals(0)))
                .write(const SetRecordsCompanion(weightKg: Value(null)));
          }
        },
        beforeOpen: (details) async {
          // Off by default in SQLite, and set_records depends on it for its
          // cascade to the parent session.
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            await into(userProfiles).insert(const UserProfilesCompanion());
          }
        },
      );

  Future<void> _createIndexes(Migrator m) async {
    await m.createIndex(Index(
      'idx_bwe_recorded',
      'CREATE INDEX IF NOT EXISTS idx_bwe_recorded '
          'ON body_weight_entries (recorded_at)',
    ));
    await m.createIndex(Index(
      'idx_sessions_started',
      'CREATE INDEX IF NOT EXISTS idx_sessions_started '
          'ON workout_sessions (started_at)',
    ));
    await m.createIndex(Index(
      'idx_sets_session',
      'CREATE INDEX IF NOT EXISTS idx_sets_session ON set_records (session_id)',
    ));
    await m.createIndex(Index(
      'idx_sets_exercise',
      'CREATE INDEX IF NOT EXISTS idx_sets_exercise '
          'ON set_records (exercise_id, recorded_at)',
    ));
  }

  static QueryExecutor _open() => driftDatabase(name: 'triple_r');

  // ── Profile ──────────────────────────────────────────────────────────────

  /// The settings row, created on first open so this never returns null.
  Future<UserProfile> get profile =>
      (select(userProfiles)..where((p) => p.id.equals(1))).getSingle();

  Stream<UserProfile> watchProfile() =>
      (select(userProfiles)..where((p) => p.id.equals(1))).watchSingle();

  Future<void> updateProfile(UserProfilesCompanion changes) async {
    await (update(userProfiles)..where((p) => p.id.equals(1))).write(changes);
  }

  // ── Progression ──────────────────────────────────────────────────────────

  Future<List<ProgressionConfig>> get progressionConfigsAll =>
      select(progressionConfigs).get();

  Stream<List<ProgressionConfig>> watchProgressionConfigs() =>
      select(progressionConfigs).watch();

  Future<void> saveProgressionConfig({
    required String pathId,
    required String branchId,
    required String? exerciseId,
    DateTime? now,
  }) async {
    await into(progressionConfigs).insertOnConflictUpdate(
      ProgressionConfigsCompanion.insert(
        pathId: pathId,
        selectedBranchId: branchId,
        selectedExerciseId: Value(exerciseId),
        updatedAt: now ?? DateTime.now(),
      ),
    );
  }

  Future<ExerciseState?> exerciseState(String exerciseId) =>
      (select(exerciseStates)..where((e) => e.exerciseId.equals(exerciseId)))
          .getSingleOrNull();

  Future<void> saveExerciseState(
    String exerciseId, {
    double? workingLoadKg,
    double? lastIncrementKg,
    int? consecutiveFailures,
    DateTime? masteredAt,
    DateTime? now,
  }) async {
    await into(exerciseStates).insertOnConflictUpdate(
      ExerciseStatesCompanion.insert(
        exerciseId: exerciseId,
        workingLoadKg: Value.absentIfNull(workingLoadKg),
        lastIncrementKg: Value.absentIfNull(lastIncrementKg),
        consecutiveFailures: Value.absentIfNull(consecutiveFailures),
        masteredAt: Value.absentIfNull(masteredAt),
        updatedAt: now ?? DateTime.now(),
      ),
    );
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  /// Only completed sessions count — an abandoned workout must not advance the
  /// rotation or the alternating hinge pattern.
  Future<int> completedSessionCount() async {
    final count = workoutSessions.id.count();
    final query = selectOnly(workoutSessions)
      ..addColumns([count])
      ..where(workoutSessions.status.equals('completed'));
    return await query.map((row) => row.read(count)!).getSingle();
  }

  Future<WorkoutSession?> get inProgressSession =>
      (select(workoutSessions)..where((s) => s.status.equals('in_progress')))
          .getSingleOrNull();

  Stream<WorkoutSession?> watchInProgressSession() =>
      (select(workoutSessions)..where((s) => s.status.equals('in_progress')))
          .watchSingleOrNull();

  /// Opens a session. Written at *start*, with `status = in_progress`, so a
  /// crash mid-workout leaves the already-logged sets attached to something.
  Future<void> startSession({
    required String id,
    required DateTime startedAt,
    required int rotationIndex,
    required int sessionOrdinal,
    required int pairRestSeconds,
    required int tripletRestSeconds,
    required String cursorJson,
  }) async {
    await into(workoutSessions).insert(
      WorkoutSessionsCompanion.insert(
        id: id,
        startedAt: startedAt,
        status: 'in_progress',
        rotationIndex: rotationIndex,
        sessionOrdinal: Value(sessionOrdinal),
        pairRestSeconds: pairRestSeconds,
        tripletRestSeconds: tripletRestSeconds,
        cursorJson: Value(cursorJson),
      ),
    );
  }

  /// Persisted after every logged set and every skip, so resume is exact
  /// rather than approximate.
  Future<void> saveCursor(String sessionId, String cursorJson) async {
    await (update(workoutSessions)..where((s) => s.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(cursorJson: Value(cursorJson)));
  }

  /// Closes a session as completed or abandoned.
  ///
  /// The cursor is cleared either way: it only means "where to resume", and a
  /// finished session has nowhere to resume to.
  Future<void> closeSession(
    String sessionId, {
    required String status,
    required DateTime endedAt,
  }) async {
    await (update(workoutSessions)..where((s) => s.id.equals(sessionId))).write(
      WorkoutSessionsCompanion(
        status: Value(status),
        endedAt: Value(endedAt),
        cursorJson: const Value(null),
      ),
    );
  }

  Future<void> logSet(SetRecordsCompanion record) =>
      into(setRecords).insertOnConflictUpdate(record);

  Future<void> deleteSet(String id) async {
    await (delete(setRecords)..where((s) => s.id.equals(id))).go();
  }

  Future<List<SetRecord>> setsForSession(String sessionId) =>
      (select(setRecords)
            ..where((s) => s.sessionId.equals(sessionId))
            ..orderBy([(s) => OrderingTerm(expression: s.recordedAt)]))
          .get();

  Stream<List<SetRecord>> watchSetsForSession(String sessionId) =>
      (select(setRecords)
            ..where((s) => s.sessionId.equals(sessionId))
            ..orderBy([(s) => OrderingTerm(expression: s.recordedAt)]))
          .watch();

  /// The sets logged for [exerciseId] in the most recent session that
  /// contains it — not simply the last N rows, which would blend two sessions
  /// together when the previous one was cut short.
  ///
  /// Drives the pre-filled targets: what the user managed last time is the
  /// best guess at what they will manage now.
  /// The session number the next workout will be.
  ///
  /// Carried forward from the last completed session rather than counted from
  /// the rows, so starting a workout out of order advances the sequence
  /// instead of leaving it stuck: finishing the workout you were actually due
  /// must hand you the *next* one, not the same one again.
  ///
  /// Falls back to the row count for databases whose sessions predate the
  /// column.
  /// Corrects one already-logged set, in any session.
  ///
  /// Distinct from [logSet], which upserts a whole row against a deterministic
  /// id and belongs to the workout in progress. History has no active session
  /// to route through, and the row already knows its exercise, so this edits
  /// the values in place.
  Future<void> updateSetValues(
    String id, {
    required int? reps,
    required int? holdSeconds,
    required double? weightKg,
  }) async {
    await (update(setRecords)..where((s) => s.id.equals(id))).write(
      SetRecordsCompanion(
        repsCompleted: Value(reps),
        holdSeconds: Value(holdSeconds),
        weightKg: Value(weightKg),
      ),
    );
  }

  /// Records, or clears, the workout the user picked by hand.
  Future<void> setPlannedRotation(int? rotationIndex) => updateProfile(
        UserProfilesCompanion(plannedRotationIndex: Value(rotationIndex)),
      );

  Future<int> nextSessionOrdinal() async {
    final last = await (select(workoutSessions)
          ..where((s) => s.status.equals('completed'))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    final ordinal = last?.sessionOrdinal;
    return ordinal == null ? await completedSessionCount() : ordinal + 1;
  }

  Future<List<SetRecord>> lastSessionSets(
    String exerciseId, {
    String? excludingSessionId,
  }) async {
    // Two bounded queries rather than one unbounded one. Reading every set
    // ever recorded for an exercise and filtering in Dart worked, but the
    // read grew with training history forever, and this runs on every set of
    // every workout. The first query finds which session was last; the second
    // fetches only that session's sets.
    final latest = await (select(setRecords)
          ..where((s) => s.exerciseId.equals(exerciseId))
          ..where((s) => excludingSessionId == null
              ? const Constant(true)
              : s.sessionId.equals(excludingSessionId).not())
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.recordedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (latest == null) return const [];

    return (select(setRecords)
          ..where((s) => s.exerciseId.equals(exerciseId))
          ..where((s) => s.sessionId.equals(latest.sessionId))
          ..orderBy([(s) => OrderingTerm(expression: s.setIndex)]))
        .get();
  }

  // ── Body metrics ─────────────────────────────────────────────────────────

  /// Newest first, which is the order both the chart and the list want.
  Stream<List<BodyWeightEntry>> watchBodyWeights() => (select(bodyWeightEntries)
        ..orderBy([
          (e) => OrderingTerm(expression: e.recordedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<BodyWeightEntry?> latestBodyWeight() => (select(bodyWeightEntries)
        ..orderBy([
          (e) => OrderingTerm(expression: e.recordedAt, mode: OrderingMode.desc),
        ])
        ..limit(1))
      .getSingleOrNull();

  Future<void> addBodyWeight({
    required String id,
    required double weightKg,
    required DateTime recordedAt,
  }) =>
      into(bodyWeightEntries).insertOnConflictUpdate(
        BodyWeightEntriesCompanion.insert(
          id: id,
          weightKg: weightKg,
          recordedAt: recordedAt,
        ),
      );

  Future<void> deleteBodyWeight(String id) async {
    await (delete(bodyWeightEntries)..where((e) => e.id.equals(id))).go();
  }

  // ── History ──────────────────────────────────────────────────────────────

  /// Finished sessions, newest first.
  ///
  /// Abandoned sessions are included: the sets in them are real work the user
  /// did, and hiding them would make the history look like days were skipped.
  /// In-progress ones are excluded — that is the resume banner's job.
  Stream<List<WorkoutSession>> watchSessionHistory() => (select(workoutSessions)
        ..where((s) => s.status.equals('in_progress').not())
        ..orderBy([
          (s) => OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  /// Every set for [exerciseId], oldest first — the shape a chart wants.
  Stream<List<SetRecord>> watchSetsForExercise(String exerciseId) =>
      (select(setRecords)
            ..where((s) => s.exerciseId.equals(exerciseId))
            ..orderBy([(s) => OrderingTerm(expression: s.recordedAt)]))
          .watch();

  /// Exercise ids that appear anywhere in the log, most recently used first.
  ///
  /// Drives the analytics picker, so it offers only exercises with something
  /// to plot rather than all 87 in the catalog.
  Future<List<String>> loggedExerciseIds() async {
    final query = selectOnly(setRecords, distinct: true)
      ..addColumns([setRecords.exerciseId, setRecords.recordedAt])
      ..orderBy([
        OrderingTerm(expression: setRecords.recordedAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.map((r) => r.read(setRecords.exerciseId)!).get();
    // DISTINCT covers (id, recordedAt) pairs, so ids still repeat here.
    return LinkedHashSet<String>.from(rows).toList();
  }

  /// Wipes every user table. Used by import, which replaces rather than
  /// merges — see `docs/PLAN.md` §6.1.
  ///
  /// The profile row is deleted too and re-inserted by the caller, so an
  /// imported backup carries its own units and rest defaults rather than
  /// keeping this device's.
  Future<void> deleteEverything() async {
    await transaction(() async {
      // Sets cascade from sessions, but the delete is explicit so this does
      // not silently depend on the foreign_keys pragma being on.
      await delete(setRecords).go();
      await delete(workoutSessions).go();
      await delete(exerciseStates).go();
      await delete(progressionConfigs).go();
      await delete(bodyWeightEntries).go();
      await delete(userProfiles).go();
    });
  }
}
