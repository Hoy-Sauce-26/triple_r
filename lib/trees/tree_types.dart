/// Types for the nine progression trees — see `docs/PLAN.md` §2.3.
///
/// Trees ship as typed Dart constants rather than parsed JSON: there is no
/// reason to pay parse cost or lose type safety for data that ships with the
/// binary and never changes at runtime.
library;

/// How a set is measured. Drives which input the logger shows and which rep
/// scheme applies.
///
/// Orthogonal to [Exercise.perSide] — Copenhagen Planks are timed *and* per
/// side, which a single three-valued enum could not express.
enum Metric {
  /// A count of repetitions.
  reps,

  /// A duration in seconds, e.g. Planks.
  timed,
}

/// How an exercise's next step is decided once its rep scheme is maxed out.
enum ProgressionMode {
  /// Move to the next exercise in the branch. The ordinary case.
  exercise,

  /// A terminal node: advancement means adding weight at the same rep target
  /// rather than moving on. See `docs/PLAN.md` §2.2.1.
  load,
}

/// Whether a branch is an ordered ladder or a weekly rotation.
enum BranchKind {
  /// The ordinary case: one current exercise, advancing over time.
  linear,

  /// Two exercises in flight at once, chosen per session by
  /// `completedSessions % pattern.length`. See `docs/PLAN.md` §2.2.2.
  alternating,
}

/// Which of the nine RRR slots a path fills. Order matters: pairs run A/B
/// alternating, and the triplet runs as a circuit.
enum Slot {
  pair1a,
  pair1b,
  pair2a,
  pair2b,
  pair3a,
  pair3b,
  triplet1,
  triplet2,
  triplet3;

  bool get isTriplet =>
      this == Slot.triplet1 || this == Slot.triplet2 || this == Slot.triplet3;
}

/// A single movement.
///
/// [id] is a stable slug. See `docs/PLAN.md` §2.4: `set_records.exercise_id`
/// stores it as free text with no foreign key, because the catalog lives in
/// code — so renaming one orphans every historical set that referenced it.
/// Display names may change freely; ids may not.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.metric = Metric.reps,
    this.perSide = false,
    this.loadable = false,
    this.mode = ProgressionMode.exercise,
    this.wikiUrl,
  });

  final String id;
  final String name;
  final Metric metric;

  /// Whether a logged value means "per side" rather than a total — 8 Split
  /// Squats is 8 per leg. Analytics must never pool these with bilateral
  /// volume.
  final bool perSide;

  /// Whether the logger offers a weight field. Independent of [mode]:
  /// Weighted Shrimp Squats takes added load but still progresses by moving
  /// to a harder exercise, so it is `loadable` without being `load` mode.
  final bool loadable;

  final ProgressionMode mode;
  final String? wikiUrl;
}

/// One fork of a [Path].
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.attachesAtLevel,
    required this.exerciseIds,
    this.isDefault = false,
    this.kind = BranchKind.linear,
    this.pattern,
  }) : assert(
          kind == BranchKind.alternating ? pattern != null : pattern == null,
          'alternating branches need a pattern; linear branches must not have one',
        );

  final String id;
  final String name;

  /// 1-based level on the path's canonical line that this branch's first
  /// exercise occupies.
  ///
  /// The canonical line is `trunkIds + defaultBranch.exerciseIds`, **not**
  /// the trunk alone. The squat path is why: its trunk is two exercises, but
  /// `stepup` forks at level 5 — levels 3 and 4 (Split Squats, Bulgarian
  /// Split Squats) live inside the default `bodyweight` branch. A branch
  /// forking above the trunk is therefore only reachable by having travelled
  /// the default branch to get there.
  final int attachesAtLevel;

  final bool isDefault;
  final BranchKind kind;

  /// For linear branches, an ordered progression. For alternating branches,
  /// an unordered set indexed by [pattern].
  final List<String> exerciseIds;

  /// Alternating branches only — indexes into [exerciseIds], cycled by
  /// `completedSessions % pattern.length`.
  final List<int>? pattern;

  /// The exercise performed on a given session, for alternating branches.
  String exerciseForSession(int completedSessions) {
    final p = pattern;
    if (p == null) {
      throw StateError('$id is linear; use the progression list instead');
    }
    return exerciseIds[p[completedSessions % p.length]];
  }
}

/// One of the nine RRR progression paths.
class Path {
  const Path({
    required this.id,
    required this.name,
    required this.slot,
    required this.trunkIds,
    required this.branches,
    this.wikiUrl,
  });

  final String id;
  final String name;
  final Slot slot;

  /// Shared prefix every branch starts from. May be empty: the Anti-Rotation
  /// and Extension paths have branches that are independent entry points with
  /// nothing in common.
  final List<String> trunkIds;

  final List<Branch> branches;
  final String? wikiUrl;

  Branch get defaultBranch => branches.firstWhere((b) => b.isDefault);

  Branch? branchById(String branchId) {
    for (final b in branches) {
      if (b.id == branchId) return b;
    }
    return null;
  }

  /// Trunk plus the default branch — the line [Branch.attachesAtLevel] counts
  /// against.
  List<String> get canonicalLine => [...trunkIds, ...defaultBranch.exerciseIds];

  /// The full ordered progression a user on [branch] works through.
  ///
  /// For an alternating branch the prefix is still a ladder, but the tail is
  /// a rotation — index it with [Branch.pattern] rather than walking it.
  List<String> progressionFor(Branch branch) => [
        ...canonicalLine.take(branch.attachesAtLevel - 1),
        ...branch.exerciseIds,
      ];

  /// 1-based position of [exerciseId] within [branch]'s progression, or null
  /// if it is not on that branch.
  int? levelOf(Branch branch, String exerciseId) {
    final index = progressionFor(branch).indexOf(exerciseId);
    return index < 0 ? null : index + 1;
  }
}

/// One gated item in the dynamic warmup — see `docs/PLAN.md` §3.
class WarmupItem {
  const WarmupItem({
    required this.id,
    required this.name,
    required this.target,
    this.metric = Metric.reps,
    this.perSide = false,
    this.holdSeconds,
    this.unlockedBy,
  });

  final String id;
  final String name;

  /// Display target, e.g. "5-10 reps". Deliberately free text: the warmup is
  /// a checklist with no advancement logic, so nothing parses a range out of
  /// it.
  final String target;

  final Metric metric;
  final bool perSide;

  /// Countdown length for timed items.
  final int? holdSeconds;

  /// Null means always shown. Otherwise the item appears only once the user's
  /// progression has reached this exercise.
  final String? unlockedBy;
}
