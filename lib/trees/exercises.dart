import 'tree_types.dart';

/// Every movement in the app, keyed by its permanent slug.
///
/// **Ids here are forever.** `set_records.exercise_id` stores these strings
/// directly, so renaming one silently orphans a user's history. Display names
/// are the mutable half — change those freely. See `docs/PLAN.md` §2.4.
///
/// A few names in the source plan were misspelled ("Copenhagne", "Hamstring
/// Slids"); the ids below were chosen from the corrected spellings so the
/// typos never became permanent.
const _all = <Exercise>[
  // ── Pull-up ──────────────────────────────────────────────────────────────
  Exercise(id: 'scapular_pulls', name: 'Scapular Pulls'),
  Exercise(id: 'arch_hangs', name: 'Arch Hangs'),
  Exercise(id: 'pullup_eccentrics', name: 'Pull-up Eccentrics'),
  Exercise(id: 'full_pullups', name: 'Full Pull-ups'),
  Exercise(
    id: 'weighted_pullups',
    name: 'Weighted Pull-ups',
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(id: 'lsit_pullups', name: 'L-sit Pull-ups'),
  Exercise(id: 'arch_body_pullups', name: 'Arch-body Pull-ups'),
  Exercise(id: 'typewriter_pullups', name: 'Type-writer Pull-ups'),
  Exercise(id: 'archer_pullups', name: 'Archer Pull-ups'),

  // ── Squat ────────────────────────────────────────────────────────────────
  Exercise(id: 'assisted_squats', name: 'Assisted Squats'),
  Exercise(id: 'full_squats', name: 'Full Squats'),
  Exercise(id: 'split_squats', name: 'Split Squats', perSide: true),
  Exercise(
    id: 'bulgarian_split_squats',
    name: 'Bulgarian Split Squats',
    perSide: true,
  ),
  Exercise(
    id: 'beginner_shrimp_squats',
    name: 'Beginner Shrimp Squats',
    perSide: true,
  ),
  Exercise(
    id: 'intermediate_shrimp_squats',
    name: 'Intermediate Shrimp Squats',
    perSide: true,
  ),
  Exercise(
    id: 'advanced_shrimp_squats',
    name: 'Advanced Shrimp Squats',
    perSide: true,
  ),
  // Terminal on the default squat branch, and the one bodyweight terminal
  // that obviously should keep progressing: it is the weighted variant, so it
  // adds load like Weighted Pull-ups / Dips / Rows do at the ends of theirs.
  Exercise(
    id: 'weighted_shrimp_squats',
    name: 'Weighted Shrimp Squats',
    perSide: true,
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(
    id: 'barbell_back_squats',
    name: 'Barbell Back Squats',
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(id: 'step_ups', name: 'Step-ups', perSide: true),
  Exercise(id: 'deep_step_ups', name: 'Deep Step-ups', perSide: true),
  Exercise(
    id: 'partial_pistol_squats',
    name: 'Partial ROM Pistol Squats',
    perSide: true,
  ),
  Exercise(id: 'pistol_squats', name: 'Pistol Squats', perSide: true),

  // ── Dip ──────────────────────────────────────────────────────────────────
  Exercise(
    id: 'parallel_bar_support_hold',
    name: 'Parallel Bar Support Hold',
    metric: Metric.timed,
  ),
  Exercise(id: 'dip_eccentrics', name: 'Dip Eccentrics'),
  Exercise(id: 'parallel_bar_dips', name: 'Parallel Bar Dips'),
  Exercise(
    id: 'weighted_dips',
    name: 'Weighted Dips',
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(id: 'ring_dips', name: 'Ring Dips'),
  Exercise(id: 'ring_rto_dips', name: 'Ring RTO Dips'),

  // ── Handstand push-up chain (shared by the dip and push-up paths) ────────
  Exercise(id: 'pike_pushups', name: 'Pike Push-ups'),
  Exercise(id: 'box_pushups', name: 'Box Push-ups'),
  Exercise(
    id: 'wall_headstand_pushup_eccentrics',
    name: 'Wall Headstand Push-up Eccentrics',
  ),
  Exercise(id: 'wall_headstand_pushups', name: 'Wall Headstand Push-ups'),
  Exercise(id: 'wall_handstand_pushups', name: 'Wall Handstand Push-ups'),
  Exercise(
    id: 'freestanding_headstand_pushups',
    name: 'Freestanding Headstand Push-ups',
  ),
  Exercise(
    id: 'freestanding_handstand_pushups',
    name: 'Freestanding Handstand Push-ups',
  ),

  // ── Hinge ────────────────────────────────────────────────────────────────
  Exercise(id: 'romanian_deadlifts', name: 'Romanian Deadlifts'),
  Exercise(
    id: 'single_leg_deadlifts',
    name: 'Single Legged Deadlifts',
    perSide: true,
  ),
  Exercise(
    id: 'banded_nordic_curl_eccentrics',
    name: 'Banded Nordic Curl Eccentrics',
  ),
  Exercise(id: 'banded_nordic_curls', name: 'Banded Nordic Curls'),
  Exercise(id: 'nordic_curls', name: 'Nordic Curls'),
  Exercise(
    id: 'barbell_romanian_deadlift',
    name: 'Barbell Romanian Deadlift',
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(
    id: 'barbell_deadlift',
    name: 'Barbell Deadlift',
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(id: 'floor_slide_progressions', name: 'Floor Slide Progressions'),
  Exercise(id: 'hamstring_slide_eccentrics', name: 'Hamstring Slide Eccentrics'),
  Exercise(id: 'hamstring_slides', name: 'Hamstring Slides'),
  Exercise(
    id: 'single_leg_hamstring_slide_eccentrics',
    name: 'Single Leg Sliding Hamstring Slide Eccentrics',
    perSide: true,
  ),
  Exercise(
    id: 'single_leg_hamstring_slides',
    name: 'Single Leg Sliding Hamstring Slides',
    perSide: true,
  ),
  Exercise(id: 'beginner_harop_curls', name: 'Beginner Harop Curls'),
  Exercise(id: 'advanced_harop_curls', name: 'Advanced Harop Curls'),
  Exercise(id: 'glute_ham_raises', name: 'Glute Ham Raises'),

  // ── Row ──────────────────────────────────────────────────────────────────
  Exercise(id: 'vertical_rows', name: 'Vertical Rows'),
  Exercise(id: 'incline_rows', name: 'Incline Rows'),
  Exercise(id: 'horizontal_rows', name: 'Horizontal Rows'),
  Exercise(id: 'wide_rows', name: 'Wide Rows'),
  Exercise(
    id: 'weighted_rows',
    name: 'Weighted Rows',
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(
    id: 'tuck_front_levers',
    name: 'Tuck Front Levers',
    metric: Metric.timed,
  ),
  Exercise(id: 'tuck_front_lever_pulls', name: 'Tuck Front Lever Pulls'),
  Exercise(id: 'archer_rows', name: 'Archer Rows', perSide: true),
  Exercise(id: 'one_arm_rows', name: 'One Arm Rows', perSide: true),

  // ── Push-up ──────────────────────────────────────────────────────────────
  Exercise(id: 'wall_pushups', name: 'Wall Push-ups'),
  Exercise(id: 'incline_pushups', name: 'Incline Push-ups'),
  Exercise(id: 'full_pushups', name: 'Full Push-ups'),
  Exercise(id: 'diamond_pushups', name: 'Diamond Push-ups'),
  Exercise(id: 'pseudo_planche_pushups', name: 'Pseudo Planche Push-ups'),
  Exercise(id: 'ring_pushups', name: 'Ring Push-ups'),
  Exercise(id: 'rto_pushups', name: 'RTO Push-ups'),
  Exercise(id: 'rto_pseudo_planche_pushups', name: 'RTO Pseudo Planche Push-ups'),

  // ── Anti-extension ───────────────────────────────────────────────────────
  Exercise(id: 'planks', name: 'Planks', metric: Metric.timed),
  Exercise(id: 'ring_ab_rollouts', name: 'Ring Ab Rollouts'),
  Exercise(id: 'kneeling_ab_wheel_rollouts', name: 'Kneeling Ab Wheel Rollouts'),
  Exercise(id: 'standing_ab_wheel_rollouts', name: 'Standing Ab Wheel Rollouts'),
  Exercise(id: 'tucked_hanging_leg_raises', name: 'Tucked Hanging Leg Raises'),
  Exercise(
    id: 'pike_hanging_leg_raise_eccentrics',
    name: 'Pike Hanging Leg Raise Eccentrics',
  ),
  Exercise(id: 'straight_hanging_leg_raises', name: 'Straight Hanging Leg Raises'),
  Exercise(id: 'pike_compressions', name: 'Pike Compressions'),

  // ── Anti-rotation ────────────────────────────────────────────────────────
  Exercise(id: 'ring_pallof_press', name: 'Ring Pallof Press', perSide: true),
  Exercise(
    id: 'pallof_press',
    name: 'Pallof Press',
    perSide: true,
    loadable: true,
    mode: ProgressionMode.load,
  ),
  Exercise(
    id: 'assisted_knee_copenhagen_planks',
    name: 'Assisted Knee Copenhagen Planks',
    metric: Metric.timed,
    perSide: true,
  ),
  Exercise(
    id: 'knee_copenhagen_planks',
    name: 'Knee Copenhagen Planks',
    metric: Metric.timed,
    perSide: true,
  ),
  Exercise(
    id: 'assisted_copenhagen_planks',
    name: 'Assisted Copenhagen Planks',
    metric: Metric.timed,
    perSide: true,
  ),
  Exercise(
    id: 'copenhagen_planks',
    name: 'Copenhagen Planks',
    metric: Metric.timed,
    perSide: true,
  ),
  Exercise(
    id: 'copenhagen_planks_with_movement',
    name: 'Copenhagen Planks with Movement',
    metric: Metric.timed,
    perSide: true,
  ),

  // ── Extension / rear chain ───────────────────────────────────────────────
  Exercise(id: 'arch_raises', name: 'Arch Raises'),
  Exercise(id: 'arch_body_holds', name: 'Arch Body Holds', metric: Metric.timed),
  Exercise(id: 'arch_body_rocks', name: 'Arch Body Rocks'),
  Exercise(id: 'reverse_hyperextensions', name: 'Reverse Hyperextensions'),
  Exercise(id: 'hyperextensions', name: 'Hyperextensions'),
];

/// Lookup by slug. Built once at first access.
final Map<String, Exercise> exercisesById = {
  for (final e in _all) e.id: e,
};

/// All exercises, in catalog order.
List<Exercise> get allExercises => List.unmodifiable(_all);

/// Resolves a slug, throwing if it is unknown.
///
/// Unknown ids are a programming error for live data, but they are *expected*
/// for historical data if an exercise is ever retired — callers rendering
/// history should use [exercisesById] and handle the null themselves.
Exercise exerciseById(String id) {
  final e = exercisesById[id];
  if (e == null) throw ArgumentError('unknown exercise id: $id');
  return e;
}
