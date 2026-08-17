import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// The app's local SQLite database. Everything Triple R knows lives here;
/// there is no network layer and no remote copy.
///
/// Tables arrive phase by phase (see `docs/PLAN.md` §7). Each addition gets a
/// [schemaVersion] bump and a step in [migration], because exported backups
/// from older builds have to remain importable — an import runs through these
/// same migrations rather than a separate code path.
@DriftDatabase(tables: [UserProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// An in-memory database that lives and dies with the test using it.
  ///
  /// Tests construct this directly instead of touching the file system, which
  /// is what lets database tests run on the host VM rather than a device.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Off by default in SQLite, and set_records depends on it for its
          // cascade to the parent session.
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            await into(userProfiles).insert(const UserProfilesCompanion());
          }
        },
      );

  static QueryExecutor _open() => driftDatabase(name: 'triple_r');

  /// The settings row, created on first open so this never returns null.
  Future<UserProfile> get profile =>
      (select(userProfiles)..where((p) => p.id.equals(1))).getSingle();

  Stream<UserProfile> watchProfile() =>
      (select(userProfiles)..where((p) => p.id.equals(1))).watchSingle();

  Future<void> updateProfile(UserProfilesCompanion changes) async {
    await (update(userProfiles)..where((p) => p.id.equals(1))).write(changes);
  }
}
