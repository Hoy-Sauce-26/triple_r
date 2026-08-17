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
  int get schemaVersion => 2;

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
    DateTime? now,
  }) async {
    await into(exerciseStates).insertOnConflictUpdate(
      ExerciseStatesCompanion.insert(
        exerciseId: exerciseId,
        workingLoadKg: Value.absentIfNull(workingLoadKg),
        lastIncrementKg: Value.absentIfNull(lastIncrementKg),
        consecutiveFailures: Value.absentIfNull(consecutiveFailures),
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
}
