import 'paths.dart';
import 'tree_types.dart';

/// Where a user currently is on one path.
class PathPosition {
  const PathPosition({required this.branchId, required this.exerciseId});

  final String branchId;

  /// Null for alternating branches, where the exercise is resolved per
  /// session from the branch pattern rather than stored.
  final String? exerciseId;
}

/// The two paths that can both be set to the handstand push-up chain.
const _hspuPathIds = {'dip', 'pushup'};
const _hspuBranchId = 'hspu';

/// The user's 1-based level on [path], given where they are now.
///
/// Alternating branches report the level of their fork point: every exercise
/// on them is "current" simultaneously, so there is no single position to
/// report.
int levelFor(Path path, PathPosition position) {
  final branch = path.branchById(position.branchId) ?? path.defaultBranch;
  if (branch.kind == BranchKind.alternating) return branch.attachesAtLevel;

  final exerciseId = position.exerciseId;
  if (exerciseId == null) return branch.attachesAtLevel;
  return path.levelOf(branch, exerciseId) ?? 1;
}

/// The other vertical-push path currently using the handstand chain, if
/// selecting [branch] here would put the same movement in both slots.
///
/// Deliberately **not** a lock. Routes are never gated on the user's level:
/// someone installing the app already able to do pistol squats must be able
/// to say so on day one, and a rule that makes them walk the current-exercise
/// list upward first is a puzzle, not a safeguard. The fork level is shown as
/// information on the route itself.
///
/// This is the one genuine constraint left, and it is structural rather than
/// aspirational — the same movement cannot fill both vertical-push slots of a
/// single workout, because the session builder would program it twice. The
/// caller resolves it by moving the other path, not by refusing this one.
String? handstandConflict(
  Path path,
  Branch branch,
  Map<String, PathPosition> positions,
) {
  if (branch.id != _hspuBranchId || !_hspuPathIds.contains(path.id)) return null;
  final otherId = _hspuPathIds.firstWhere((id) => id != path.id);
  final other = positions[otherId];
  if (other == null || other.branchId != _hspuBranchId) return null;

  // Naming a route in a config row is not the same as being on it. A user
  // sitting below the fork has taken nothing yet — the detail screen shows no
  // route as chosen — so treating them as occupying the handstand slot
  // produced a conflict over a movement neither path was actually doing.
  final otherPath = pathById(otherId);
  final otherBranch = otherPath.branchById(_hspuBranchId)!;
  return levelFor(otherPath, other) >= otherBranch.attachesAtLevel
      ? otherId
      : null;
}

/// The starting position for a path with nothing configured: the default
/// branch, at the first exercise of its progression.
PathPosition initialPosition(Path path) {
  final branch = path.defaultBranch;
  return PathPosition(
    branchId: branch.id,
    exerciseId: branch.kind == BranchKind.alternating
        ? null
        : path.progressionFor(branch).first,
  );
}

/// The position to land on when switching to [branch].
///
/// Lands at the branch's own first exercise rather than the start of the
/// progression: the shared prefix is already behind the user, and dropping
/// them back to Wall Push-ups for choosing rings would be absurd.
PathPosition positionAfterSwitch(Path path, Branch branch) {
  return PathPosition(
    branchId: branch.id,
    exerciseId:
        branch.kind == BranchKind.alternating ? null : branch.exerciseIds.first,
  );
}

/// Every exercise the user has reached or passed, across all paths.
///
/// Drives the gated warmup items: "reaching Pull-up Eccentrics" means that
/// exercise is at or below the user's current level on its path.
Set<String> reachedExercises(Map<String, PathPosition> positions) {
  final reached = <String>{};
  for (final path in allPaths) {
    final position = positions[path.id];
    if (position == null) continue;
    final branch = path.branchById(position.branchId) ?? path.defaultBranch;
    final progression = path.progressionFor(branch);
    final level = levelFor(path, position);
    reached.addAll(progression.take(level));
  }
  return reached;
}
