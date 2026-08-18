import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'domain/analytics.dart';
import 'domain/session_plan.dart';
import 'domain/units.dart';
import 'services/backup_files.dart';
import 'trees/paths.dart';
import 'trees/tree_rules.dart';

/// Overridden in tests with an in-memory database, and in [main] with the
/// instance opened at startup.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// The settings row. Watched rather than read so a unit-system change
/// repaints every screen showing a weight.
final profileProvider = StreamProvider<UserProfile>((ref) {
  return ref.watch(databaseProvider).watchProfile();
});

/// Where the user is on every path, keyed by path id.
///
/// Paths with no stored row fall back to their starting position, so this
/// always covers all nine — screens never have to handle a missing entry, and
/// a fresh install behaves identically to a configured one.
final pathPositionsProvider = StreamProvider<Map<String, PathPosition>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchProgressionConfigs().map((rows) {
    final stored = {
      for (final r in rows)
        r.pathId: PathPosition(
          branchId: r.selectedBranchId,
          exerciseId: r.selectedExerciseId,
        ),
    };
    return {
      for (final path in allPaths) path.id: stored[path.id] ?? initialPosition(path),
    };
  });
});

/// Number of completed sessions — drives the pair rotation and the
/// alternating hinge pattern.
final completedSessionCountProvider = FutureProvider<int>((ref) {
  return ref.watch(databaseProvider).completedSessionCount();
});

/// The user's unit system. Defaults to imperial until the profile loads, so
/// nothing renders a weight in the wrong unit mid-flight.
final unitSystemProvider = Provider<UnitSystem>((ref) {
  final profile = ref.watch(profileProvider).value;
  return profile == null
      ? UnitSystem.imperial
      : UnitSystem.parse(profile.unitSystem);
});

/// Every exercise the user has reached, across all paths. Drives the gated
/// warmup items.
final reachedExercisesProvider = Provider<Set<String>>((ref) {
  final positions = ref.watch(pathPositionsProvider).value;
  return positions == null ? const {} : reachedExercises(positions);
});

/// The shape of the next workout: pair order, triplet, and the warmup items
/// the user has unlocked.
///
/// Null while the pieces it needs are still loading — callers should show a
/// spinner rather than plan a session against a session count of zero, which
/// would silently pick rotation 0.
final nextSessionPlanProvider = Provider<SessionPlan?>((ref) {
  final completed = ref.watch(completedSessionCountProvider).value;
  final profile = ref.watch(profileProvider).value;
  if (completed == null || profile == null) return null;

  return planSession(
    completedSessions: completed,
    rotatePairOrder: profile.rotatePairOrder,
    reachedExerciseIds: ref.watch(reachedExercisesProvider),
  );
});

/// The exercise each path contributes to the next session, keyed by path id.
final nextSessionExercisesProvider = Provider<Map<String, String>>((ref) {
  final completed = ref.watch(completedSessionCountProvider).value;
  final positions = ref.watch(pathPositionsProvider).value;
  if (completed == null || positions == null) return const {};

  return {
    for (final path in allPaths)
      if (positions[path.id] case final position?)
        path.id: exerciseForSession(
          path: path,
          branch: path.branchById(position.branchId) ?? path.defaultBranch,
          selectedExerciseId: position.exerciseId,
          completedSessions: completed,
        ),
  };
});

// ── Phase 5: metrics, history, analytics ───────────────────────────────────

/// Moving backups in and out of the app.
final backupFilesProvider =
    Provider<BackupFiles>((ref) => const PlatformBackupFiles());

/// Body weight over time, newest first.
final bodyWeightsProvider = StreamProvider<List<BodyWeightEntry>>((ref) {
  return ref.watch(databaseProvider).watchBodyWeights();
});

/// Finished sessions, newest first. Excludes the in-progress one, which the
/// dashboard's resume banner owns.
final sessionHistoryProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(databaseProvider).watchSessionHistory();
});

/// The sets belonging to one session.
final sessionSetsProvider =
    StreamProvider.family<List<SetRecord>, String>((ref, sessionId) {
  return ref.watch(databaseProvider).watchSetsForSession(sessionId);
});

/// Exercises that have something to plot, most recently trained first.
final loggedExerciseIdsProvider = FutureProvider<List<String>>((ref) {
  // Re-runs whenever the history changes, so an exercise appears in the
  // picker the moment its first set is logged.
  ref.watch(sessionHistoryProvider);
  return ref.watch(databaseProvider).loggedExerciseIds();
});

/// One exercise's chart series.
final exerciseSeriesProvider =
    StreamProvider.family<ExerciseSeries, String>((ref, exerciseId) {
  return ref
      .watch(databaseProvider)
      .watchSetsForExercise(exerciseId)
      .map((sets) => buildExerciseSeries(exerciseId, sets));
});

/// Every advancement the log implies, newest first.
final progressionEventsProvider =
    StreamProvider<List<ProgressionEvent>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.setRecords).watch().map(progressionEvents);
});
