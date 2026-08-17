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

/// Why a branch cannot currently be selected. Null means it can.
enum BranchLockReason {
  /// The branch forks above where the user has reached.
  notYetReached,

  /// The handstand push-up chain is already filling the other vertical-push
  /// slot, and one movement cannot occupy two slots in the same workout.
  takenByOtherSlot,
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

/// Whether [branch] can be selected on [path] right now, and if not, why.
///
/// [positions] is the user's position on every path, needed only for the
/// cross-path handstand push-up rule.
BranchLockReason? branchLock(
  Path path,
  Branch branch,
  Map<String, PathPosition> positions,
) {
  final current = positions[path.id];

  // Two branches are never level-locked: the default one spans the canonical
  // line from level 1, and the branch the user is already on must stay
  // selectable or the dropdown cannot render its own current value — which
  // would strand a beginner on a squat path whose default branch forks at 3.
  final exemptFromLevel = branch.isDefault || current?.branchId == branch.id;

  // Any other branch forking at level N needs the user to have reached the
  // exercise just below it.
  if (!exemptFromLevel && branch.attachesAtLevel > 1 && current != null) {
    final level = levelFor(path, current);
    if (level < branch.attachesAtLevel - 1) return BranchLockReason.notYetReached;
  }

  // One movement cannot fill both vertical-push slots in the same session.
  if (branch.id == _hspuBranchId && _hspuPathIds.contains(path.id)) {
    final otherId = _hspuPathIds.firstWhere((id) => id != path.id);
    if (positions[otherId]?.branchId == _hspuBranchId) {
      return BranchLockReason.takenByOtherSlot;
    }
  }

  return null;
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
