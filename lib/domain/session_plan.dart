import '../trees/tree_types.dart';
import '../trees/warmup.dart';

/// Two paths worked alternately, A/B, with a rest between every set.
class PairBlock {
  const PairBlock(this.aPathId, this.bPathId);

  final String aPathId;
  final String bPathId;

  List<String> get pathIds => [aPathId, bPathId];
}

/// The ordered shape of one workout.
class SessionPlan {
  const SessionPlan({
    required this.rotationIndex,
    required this.pairs,
    required this.tripletPathIds,
    required this.warmup,
  });

  /// Which of the three orders this session used. Stored on the session row
  /// so history stays truthful if the completed count later changes.
  final int rotationIndex;

  final List<PairBlock> pairs;
  final List<String> tripletPathIds;
  final List<WarmupItem> warmup;

  /// Every path in the order it will be worked.
  List<String> get pathIdsInOrder =>
      [for (final p in pairs) ...p.pathIds, ...tripletPathIds];
}

const _pair1 = PairBlock('pullup', 'squat');
const _pair2 = PairBlock('dip', 'hinge');
const _pair3 = PairBlock('row', 'pushup');

/// The three cyclic orders. Rotating spreads fatigue bias so the same pair is
/// not always worked fresh.
///
/// **Not part of the RR**, which prescribes a fixed order — hence
/// [rotationIndexFor] pinning to 0 when the user turns rotation off.
const pairRotations = <List<PairBlock>>[
  [_pair1, _pair2, _pair3],
  [_pair2, _pair3, _pair1],
  [_pair3, _pair1, _pair2],
];

/// The triplet always runs last, in a fixed order.
const tripletOrder = ['antiextension', 'antirotation', 'extension'];

int rotationIndexFor(int completedSessions, {required bool rotatePairOrder}) {
  if (!rotatePairOrder) return 0;
  // Guard against a negative count rather than trusting the caller; Dart's %
  // would return a negative index and throw deep inside the plan builder.
  return completedSessions.remainder(pairRotations.length).abs();
}

/// Warmup items the user has unlocked. The last four exist to prepare a
/// movement they cannot do yet, so they appear only once reached.
List<WarmupItem> warmupFor(Set<String> reachedExerciseIds) => [
      for (final item in warmupItems)
        if (item.unlockedBy == null || reachedExerciseIds.contains(item.unlockedBy))
          item,
    ];

/// Builds the plan for the next session.
SessionPlan planSession({
  required int completedSessions,
  required bool rotatePairOrder,
  required Set<String> reachedExerciseIds,
}) {
  final index =
      rotationIndexFor(completedSessions, rotatePairOrder: rotatePairOrder);
  return SessionPlan(
    rotationIndex: index,
    pairs: pairRotations[index],
    tripletPathIds: tripletOrder,
    warmup: warmupFor(reachedExerciseIds),
  );
}

/// The exercise a path contributes to a session.
///
/// Linear branches use the stored position. Alternating branches have no
/// single position — the exercise comes from the branch pattern and the
/// session count. See `docs/PLAN.md` §2.2.2.
String exerciseForSession({
  required Path path,
  required Branch branch,
  required String? selectedExerciseId,
  required int completedSessions,
}) {
  if (branch.kind == BranchKind.alternating) {
    return branch.exerciseForSession(completedSessions);
  }
  return selectedExerciseId ?? path.progressionFor(branch).first;
}
