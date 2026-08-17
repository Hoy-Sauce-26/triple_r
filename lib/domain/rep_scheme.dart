import '../trees/tree_types.dart';

/// Sets and target range for one exercise — see `docs/PLAN.md` §2.1.
class RepScheme {
  const RepScheme({
    required this.sets,
    required this.floor,
    required this.ceiling,
    required this.metric,
  });

  final int sets;

  /// Bottom of the target range. Falling below it on any set is what counts
  /// as a failing session.
  final int floor;

  /// Top of the range. Hitting it on every set is what triggers advancement.
  final int ceiling;

  final Metric metric;

  bool get isTimed => metric == Metric.timed;

  /// Whether [values] — one entry per completed set — clears the whole range.
  bool isMaxedBy(Iterable<int> values) =>
      values.length >= sets && values.every((v) => v >= ceiling);

  /// Whether any set fell short. Uses the values as logged; nothing is
  /// clamped to the range on the way in.
  bool isFailedBy(Iterable<int> values) =>
      values.length >= sets && values.any((v) => v < floor);

  String get targetLabel =>
      isTimed ? '$sets x $floor-${ceiling}s' : '$sets x $floor-$ceiling';
}

/// Pair exercises: the RR's core prescription.
const pairScheme = RepScheme(sets: 3, floor: 5, ceiling: 8, metric: Metric.reps);

/// The core triplet runs a higher range than the pairs do.
const tripletScheme =
    RepScheme(sets: 3, floor: 8, ceiling: 12, metric: Metric.reps);

/// Timed holds. Not from the RR, which gives no range for these — see
/// `docs/PLAN.md` §2.1.
const timedScheme =
    RepScheme(sets: 3, floor: 30, ceiling: 60, metric: Metric.timed);

/// The scheme for [exercise] in [slot].
///
/// **Metric wins over slot.** A timed hold uses the timed range wherever it
/// sits, because a rep count is meaningless for it. That does mean a path can
/// change schemes partway: Parallel Bar Support Hold opens the dip path on
/// 30-60s and everything after it runs 5-8 reps.
RepScheme schemeFor(Exercise exercise, Slot slot) {
  if (exercise.metric == Metric.timed) return timedScheme;
  return slot.isTriplet ? tripletScheme : pairScheme;
}
