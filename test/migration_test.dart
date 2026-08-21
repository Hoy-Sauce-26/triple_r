import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart';
import 'package:triple_r/data/database.dart';

/// The v6 → v7 upgrade, run against a database built by hand at the old
/// shape.
///
/// Worth its own group because v7 is the first migration that *widens* a
/// column rather than adding one: `set_records.weight_kg` goes from NOT NULL
/// to nullable so null can mean "no weight entered" as distinct from a set
/// logged at zero. SQLite has no ALTER for that, so drift rebuilds the table
/// — and a rebuild that silently dropped rows, or left the indexes behind on
/// a table that no longer exists, would only surface on someone else's phone
/// restoring a backup.
void _v6Schema(CommonDatabase raw) {
  raw.execute('''
    CREATE TABLE user_profiles (
      id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY CHECK (id = 1),
      planned_rotation_index INTEGER NULL,
      unit_system TEXT NOT NULL DEFAULT 'imperial',
      default_pair_rest_seconds INTEGER NOT NULL DEFAULT 90,
      default_triplet_rest_seconds INTEGER NOT NULL DEFAULT 60,
      rotate_pair_order INTEGER NOT NULL DEFAULT 1
    );
    CREATE TABLE body_weight_entries (
      id TEXT NOT NULL PRIMARY KEY,
      recorded_at INTEGER NOT NULL,
      weight_kg REAL NOT NULL
    );
    CREATE TABLE progression_configs (
      path_id TEXT NOT NULL PRIMARY KEY,
      selected_branch_id TEXT NOT NULL,
      selected_exercise_id TEXT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE exercise_states (
      exercise_id TEXT NOT NULL PRIMARY KEY,
      working_load_kg REAL NOT NULL DEFAULT 0,
      last_increment_kg REAL NULL,
      consecutive_failures INTEGER NOT NULL DEFAULT 0,
      mastered_at INTEGER NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE workout_sessions (
      id TEXT NOT NULL PRIMARY KEY,
      started_at INTEGER NOT NULL,
      ended_at INTEGER NULL,
      status TEXT NOT NULL,
      rotation_index INTEGER NOT NULL,
      session_ordinal INTEGER NULL,
      pair_rest_seconds INTEGER NOT NULL,
      triplet_rest_seconds INTEGER NOT NULL,
      cursor_json TEXT NULL
    );
    CREATE TABLE set_records (
      id TEXT NOT NULL PRIMARY KEY,
      session_id TEXT NOT NULL REFERENCES workout_sessions (id) ON DELETE CASCADE,
      path_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      set_index INTEGER NOT NULL,
      reps_completed INTEGER NULL,
      hold_seconds INTEGER NULL,
      weight_kg REAL NOT NULL DEFAULT 0,
      recorded_at INTEGER NOT NULL,
      CHECK ((reps_completed IS NULL) != (hold_seconds IS NULL))
    );
    CREATE INDEX idx_sets_session ON set_records (session_id);

    INSERT INTO user_profiles (id, unit_system) VALUES (1, 'metric');
    INSERT INTO workout_sessions
      (id, started_at, status, rotation_index, pair_rest_seconds,
       triplet_rest_seconds)
      VALUES ('s1', 1740000000, 'completed', 0, 90, 60);
    INSERT INTO set_records
      (id, session_id, path_id, exercise_id, set_index, reps_completed,
       weight_kg, recorded_at)
      VALUES ('r1', 's1', 'pushup', 'full_pushups', 1, 8, 20.0, 1740000000);
  ''');
  raw.execute('PRAGMA user_version = 6');
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: _v6Schema));
  });
  tearDown(() => db.close());

  test('carries the existing rows across the set_records rebuild', () async {
    final rows = await db.select(db.setRecords).get();
    expect(rows, hasLength(1));
    expect(rows.single.repsCompleted, 8);
    expect(
      rows.single.weightKg,
      20.0,
      reason: 'a load recorded before v7 is still a load after it',
    );
  });

  test('leaves old rows reading as real numbers, never as "no entry"', () async {
    // Everything written under v6 was NOT NULL, so nothing in an upgraded
    // database can come back null. The distinction only starts applying to
    // sets logged from here on.
    final rows = await db.select(db.setRecords).get();
    expect(rows.every((r) => r.weightKg != null), isTrue);
  });

  test('accepts a null weight once upgraded', () async {
    await db.into(db.setRecords).insert(
          SetRecordsCompanion.insert(
            id: 'r2',
            sessionId: 's1',
            pathId: 'pushup',
            exerciseId: 'full_pushups',
            setIndex: 2,
            repsCompleted: const Value(9),
            recordedAt: DateTime(2026, 3, 1, 10),
          ),
        );
    final row = await (db.select(db.setRecords)
          ..where((s) => s.id.equals('r2')))
        .getSingle();
    expect(row.weightKg, isNull);
  });

  test('keeps the profile and adds the increment setting', () async {
    final profile = await db.profile;
    expect(profile.unitSystem, 'metric', reason: 'settings survive a rebuild');
    expect(
      profile.loadIncrementKg,
      isNull,
      reason: 'null means "whatever suits the units", which is the old default',
    );

    await db.updateProfile(const UserProfilesCompanion(loadIncrementKg: Value(2.5)));
    expect((await db.profile).loadIncrementKg, 2.5);
  });

  test('rebuilds the indexes the dropped table took with it', () async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'set_records'",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(names, containsAll(['idx_sets_session', 'idx_sets_exercise']));
  });

  test('the reps-or-hold check survives the rebuild', () async {
    await expectLater(
      db.into(db.setRecords).insert(
            SetRecordsCompanion.insert(
              id: 'bad',
              sessionId: 's1',
              pathId: 'pushup',
              exerciseId: 'full_pushups',
              setIndex: 3,
              repsCompleted: const Value(5),
              holdSeconds: const Value(20),
              recordedAt: DateTime(2026, 3, 1, 10),
            ),
          ),
      throwsA(
        predicate(
          (e) => e.toString().contains('CHECK constraint failed'),
          'a SQLite CHECK constraint violation',
        ),
      ),
    );
  });
}
