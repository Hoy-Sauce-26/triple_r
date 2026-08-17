import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
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
