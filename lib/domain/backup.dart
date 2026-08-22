/// JSON export and import — the only defence against a lost phone taking a
/// year of training with it. See `docs/PLAN.md` §6.1.
///
/// **Import replaces, it does not merge.** The use case is "I got a new
/// phone", where replacing is both correct and obvious. Merging two divergent
/// histories raises questions — duplicate sessions, conflicting progression
/// state, which working load wins — that nothing here needs answered.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';


/// Bumped only when the *file format* changes, which is not the same thing as
/// the database schema changing. Adding a nullable column leaves old exports
/// readable, so it stays put; renaming or removing a field does not.
const backupFormatVersion = 1;

class BackupError implements Exception {
  const BackupError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the whole database into a single JSON document.
Future<String> exportBackup(AppDatabase db, {DateTime? now}) async {
  final profile = await db.profile;
  final document = {
    'formatVersion': backupFormatVersion,
    // Informational only — nothing reads it back. It exists so a user staring
    // at three files in their downloads folder can tell which is which.
    'schemaVersion': db.schemaVersion,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    'profile': {
      'unitSystem': profile.unitSystem,
      'defaultPairRestSeconds': profile.defaultPairRestSeconds,
      'defaultTripletRestSeconds': profile.defaultTripletRestSeconds,
      'rotatePairOrder': profile.rotatePairOrder,
      'loadIncrementKg': profile.loadIncrementKg,
    },
    'bodyWeights': [
      for (final e in await db.select(db.bodyWeightEntries).get())
        {
          'id': e.id,
          'recordedAt': e.recordedAt.toIso8601String(),
          'weightKg': e.weightKg,
        },
    ],
    'progressionConfigs': [
      for (final c in await db.progressionConfigsAll)
        {
          'pathId': c.pathId,
          'selectedBranchId': c.selectedBranchId,
          'selectedExerciseId': c.selectedExerciseId,
          'updatedAt': c.updatedAt.toIso8601String(),
        },
    ],
    'exerciseStates': [
      for (final s in await db.select(db.exerciseStates).get())
        {
          'exerciseId': s.exerciseId,
          'workingLoadKg': s.workingLoadKg,
          'lastIncrementKg': s.lastIncrementKg,
          'consecutiveFailures': s.consecutiveFailures,
          'masteredAt': s.masteredAt?.toIso8601String(),
          'updatedAt': s.updatedAt.toIso8601String(),
        },
    ],
    'sessions': [
      for (final s in await db.select(db.workoutSessions).get())
        {
          'id': s.id,
          'startedAt': s.startedAt.toIso8601String(),
          'endedAt': s.endedAt?.toIso8601String(),
          'status': s.status,
          'rotationIndex': s.rotationIndex,
          'pairRestSeconds': s.pairRestSeconds,
          'tripletRestSeconds': s.tripletRestSeconds,
          'cursorJson': s.cursorJson,
        },
    ],
    'sets': [
      for (final s in await db.select(db.setRecords).get())
        {
          'id': s.id,
          'sessionId': s.sessionId,
          'pathId': s.pathId,
          'exerciseId': s.exerciseId,
          'setIndex': s.setIndex,
          'repsCompleted': s.repsCompleted,
          'holdSeconds': s.holdSeconds,
          'weightKg': s.weightKg,
          'recordedAt': s.recordedAt.toIso8601String(),
        },
    ],
  };

  // Indented rather than compact: a backup nobody can read is a backup nobody
  // trusts, and these files are small enough that the whitespace is free.
  return const JsonEncoder.withIndent('  ').convert(document);
}

/// What an import is about to do, so the confirmation can say it out loud.
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.sessionCount,
    required this.setCount,
    required this.bodyWeightCount,
  });

  final DateTime? exportedAt;
  final int sessionCount;
  final int setCount;
  final int bodyWeightCount;
}

/// Parses and validates without touching the database.
///
/// Split from [restoreBackup] so the user can be told what they are about to
/// overwrite *before* anything is destroyed.
BackupSummary inspectBackup(String json) {
  final Map<String, dynamic> document;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupError('That file is not a Triple R backup.');
    }
    document = decoded;
  } on FormatException {
    throw const BackupError('That file is not valid JSON.');
  }

  final version = document['formatVersion'];
  if (version is! int) {
    throw const BackupError('That file is not a Triple R backup.');
  }
  if (version > backupFormatVersion) {
    // Forward compatibility is not achievable — a newer file may contain
    // fields whose meaning this build cannot guess. Refusing loudly beats
    // importing a subset and silently losing the rest.
    throw BackupError(
      'This backup was made by a newer version of Triple R '
      '(format $version, this build reads $backupFormatVersion). '
      'Update the app and try again.',
    );
  }

  return BackupSummary(
    exportedAt: _parseDate(document['exportedAt']),
    sessionCount: _list(document['sessions']).length,
    setCount: _list(document['sets']).length,
    bodyWeightCount: _list(document['bodyWeights']).length,
  );
}

/// Replaces everything in [db] with the contents of [json].
///
/// Runs in one transaction: a backup that fails halfway would otherwise leave
/// the user with neither their old data nor their new.
Future<void> restoreBackup(AppDatabase db, String json) async {
  inspectBackup(json); // Validate before destroying anything.
  final document = jsonDecode(json) as Map<String, dynamic>;

  await db.transaction(() async {
    await db.deleteEverything();

    final profile = _map(document['profile']);
    await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            unitSystem: Value(profile['unitSystem'] as String? ?? 'imperial'),
            defaultPairRestSeconds:
                Value(profile['defaultPairRestSeconds'] as int? ?? 90),
            defaultTripletRestSeconds:
                Value(profile['defaultTripletRestSeconds'] as int? ?? 60),
            rotatePairOrder: Value(profile['rotatePairOrder'] as bool? ?? true),
            // Absent in backups taken before schema 7, and null there means
            // "no preference" either way, so no fallback is needed.
            loadIncrementKg: Value(_toDouble(profile['loadIncrementKg'])),
          ),
        );

    for (final raw in _list(document['bodyWeights'])) {
      final e = _map(raw);
      await db.into(db.bodyWeightEntries).insert(
            BodyWeightEntriesCompanion.insert(
              id: e['id'] as String,
              recordedAt: _requireDate(e['recordedAt'], 'bodyWeights.recordedAt'),
              weightKg: _toDouble(e['weightKg']) ?? 0,
            ),
          );
    }

    for (final raw in _list(document['progressionConfigs'])) {
      final c = _map(raw);
      await db.into(db.progressionConfigs).insert(
            ProgressionConfigsCompanion.insert(
              pathId: c['pathId'] as String,
              selectedBranchId: c['selectedBranchId'] as String,
              selectedExerciseId: Value(c['selectedExerciseId'] as String?),
              updatedAt: _requireDate(c['updatedAt'], 'progressionConfigs.updatedAt'),
            ),
          );
    }

    for (final raw in _list(document['exerciseStates'])) {
      final s = _map(raw);
      await db.into(db.exerciseStates).insert(
            ExerciseStatesCompanion.insert(
              exerciseId: s['exerciseId'] as String,
              workingLoadKg: Value(_toDouble(s['workingLoadKg']) ?? 0),
              lastIncrementKg: Value(_toDouble(s['lastIncrementKg'])),
              consecutiveFailures: Value(s['consecutiveFailures'] as int? ?? 0),
              masteredAt: Value(_parseDate(s['masteredAt'])),
              updatedAt: _requireDate(s['updatedAt'], 'exerciseStates.updatedAt'),
            ),
          );
    }

    // Sessions before sets: the foreign key means the reverse order fails.
    for (final raw in _list(document['sessions'])) {
      final s = _map(raw);
      await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              id: s['id'] as String,
              startedAt: _requireDate(s['startedAt'], 'sessions.startedAt'),
              endedAt: Value(_parseDate(s['endedAt'])),
              status: s['status'] as String,
              rotationIndex: s['rotationIndex'] as int? ?? 0,
              pairRestSeconds: s['pairRestSeconds'] as int? ?? 90,
              tripletRestSeconds: s['tripletRestSeconds'] as int? ?? 60,
              cursorJson: Value(s['cursorJson'] as String?),
            ),
          );
    }

    for (final raw in _list(document['sets'])) {
      final s = _map(raw);
      await db.into(db.setRecords).insert(
            SetRecordsCompanion.insert(
              id: s['id'] as String,
              sessionId: s['sessionId'] as String,
              pathId: s['pathId'] as String,
              exerciseId: s['exerciseId'] as String,
              setIndex: s['setIndex'] as int,
              repsCompleted: Value(s['repsCompleted'] as int?),
              holdSeconds: Value(s['holdSeconds'] as int?),
              // Null stays null: it means no weight was entered, which is not
              // the same as a set logged at zero. Backups from before schema
              // 7 always carry a number, so they restore unchanged.
              weightKg: Value(_toDouble(s['weightKg'])),
              recordedAt: _requireDate(s['recordedAt'], 'sets.recordedAt'),
            ),
          );
    }
  });
}

/// A filename that sorts chronologically and survives a share sheet.
String backupFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'triple-r-${now.year}-${two(now.month)}-${two(now.day)}.json';
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// Accepts an int where a double is expected — JSON writes 80.0 as `80`.
double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

DateTime _requireDate(Object? value, String field) {
  final parsed = _parseDate(value);
  if (parsed == null) throw BackupError('Backup is missing $field.');
  return parsed;
}
