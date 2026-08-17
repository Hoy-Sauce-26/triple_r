import 'tree_types.dart';

/// The handstand push-up chain, referenced by both the dip and push-up paths.
///
/// One list, two branches — the source plan duplicated it at different step
/// numbers, which would have produced two sets of ids for the same movements.
/// Because it can fill either vertical-push slot, the config screen must stop
/// a user selecting it for both at once; see `paths_rules.dart`.
const _hspuChain = <String>[
  'pike_pushups',
  'box_pushups',
  'wall_headstand_pushup_eccentrics',
  'wall_headstand_pushups',
  'wall_handstand_pushups',
  'freestanding_headstand_pushups',
  'freestanding_handstand_pushups',
];

/// The nine RRR progression paths.
///
/// Every branch's `attachesAtLevel` counts against the path's *canonical
/// line* — trunk plus default branch — not the trunk alone. See
/// [Branch.attachesAtLevel].
const allPaths = <Path>[
  // ── Pair 1: vertical pull ────────────────────────────────────────────────
  Path(
    id: 'pullup',
    name: 'Pull-up',
    slot: Slot.pair1a,
    wikiUrl: 'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/pullup/',
    trunkIds: [
      'scapular_pulls',
      'arch_hangs',
      'pullup_eccentrics',
      'full_pullups',
    ],
    branches: [
      Branch(
        id: 'weighted',
        name: 'Weighted',
        attachesAtLevel: 5,
        isDefault: true,
        exerciseIds: ['weighted_pullups'],
      ),
      Branch(
        id: 'lsit',
        name: 'L-sit',
        attachesAtLevel: 5,
        exerciseIds: ['lsit_pullups'],
      ),
      Branch(
        id: 'arch',
        name: 'Arch-body',
        attachesAtLevel: 5,
        exerciseIds: ['arch_body_pullups'],
      ),
      Branch(
        id: 'typewriter',
        name: 'Type-writer',
        attachesAtLevel: 5,
        exerciseIds: ['typewriter_pullups', 'archer_pullups'],
      ),
    ],
  ),

  // ── Pair 1: quads ────────────────────────────────────────────────────────
  Path(
    id: 'squat',
    name: 'Squat',
    slot: Slot.pair1b,
    wikiUrl: 'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/squat/',
    trunkIds: ['assisted_squats', 'full_squats'],
    branches: [
      Branch(
        id: 'bodyweight',
        name: 'Bodyweight',
        attachesAtLevel: 3,
        isDefault: true,
        exerciseIds: [
          'split_squats',
          'bulgarian_split_squats',
          'beginner_shrimp_squats',
          'intermediate_shrimp_squats',
          'advanced_shrimp_squats',
          'weighted_shrimp_squats',
        ],
      ),
      Branch(
        id: 'barbell',
        name: 'Barbell',
        attachesAtLevel: 3,
        exerciseIds: ['barbell_back_squats'],
      ),
      // Forks above the trunk: levels 3-4 (Split, Bulgarian Split) come from
      // the bodyweight branch, so this is only reachable by travelling it.
      Branch(
        id: 'stepup',
        name: 'Step-up',
        attachesAtLevel: 5,
        exerciseIds: ['step_ups', 'deep_step_ups'],
      ),
      Branch(
        id: 'pistol',
        name: 'Pistol',
        attachesAtLevel: 5,
        exerciseIds: ['partial_pistol_squats', 'pistol_squats'],
      ),
    ],
  ),

  // ── Pair 2: vertical push ────────────────────────────────────────────────
  Path(
    id: 'dip',
    name: 'Dip',
    slot: Slot.pair2a,
    wikiUrl: 'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/dip/',
    trunkIds: [
      'parallel_bar_support_hold',
      'dip_eccentrics',
      'parallel_bar_dips',
    ],
    branches: [
      Branch(
        id: 'weighted',
        name: 'Weighted',
        attachesAtLevel: 4,
        isDefault: true,
        exerciseIds: ['weighted_dips'],
      ),
      Branch(
        id: 'rings',
        name: 'Rings',
        attachesAtLevel: 4,
        exerciseIds: ['ring_dips', 'ring_rto_dips'],
      ),
      Branch(
        id: 'hspu',
        name: 'Handstand Push-up',
        attachesAtLevel: 4,
        exerciseIds: _hspuChain,
      ),
    ],
  ),

  // ── Pair 2: posterior chain ──────────────────────────────────────────────
  Path(
    id: 'hinge',
    name: 'Hinge',
    slot: Slot.pair2b,
    wikiUrl: 'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/hinge',
    trunkIds: ['romanian_deadlifts'],
    branches: [
      Branch(
        id: 'bodyweight',
        name: 'Bodyweight',
        attachesAtLevel: 2,
        isDefault: true,
        exerciseIds: [
          'single_leg_deadlifts',
          'banded_nordic_curl_eccentrics',
          'banded_nordic_curls',
          'nordic_curls',
        ],
      ),
      // The app's only alternating branch: RDL on days 1 and 3, barbell
      // deadlift on day 2, repeating weekly. See `docs/PLAN.md` §2.2.2.
      Branch(
        id: 'barbell',
        name: 'Barbell',
        attachesAtLevel: 2,
        kind: BranchKind.alternating,
        exerciseIds: ['barbell_romanian_deadlift', 'barbell_deadlift'],
        pattern: [0, 1, 0],
      ),
      Branch(
        id: 'slide',
        name: 'Slides',
        attachesAtLevel: 3,
        exerciseIds: [
          'floor_slide_progressions',
          'hamstring_slide_eccentrics',
          'hamstring_slides',
          'single_leg_hamstring_slide_eccentrics',
          'single_leg_hamstring_slides',
        ],
      ),
      Branch(
        id: 'harop',
        name: 'Harop Curl',
        attachesAtLevel: 3,
        exerciseIds: ['beginner_harop_curls', 'advanced_harop_curls'],
      ),
      Branch(
        id: 'ghr',
        name: 'Glute Ham Raise',
        attachesAtLevel: 3,
        exerciseIds: ['glute_ham_raises'],
      ),
    ],
  ),

  // ── Pair 3: horizontal pull ──────────────────────────────────────────────
  Path(
    id: 'row',
    name: 'Row',
    slot: Slot.pair3a,
    wikiUrl: 'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/row/',
    trunkIds: ['vertical_rows', 'incline_rows', 'horizontal_rows', 'wide_rows'],
    branches: [
      Branch(
        id: 'weighted',
        name: 'Weighted',
        attachesAtLevel: 5,
        isDefault: true,
        exerciseIds: ['weighted_rows'],
      ),
      Branch(
        id: 'frontlever',
        name: 'Front Lever',
        attachesAtLevel: 5,
        exerciseIds: ['tuck_front_levers', 'tuck_front_lever_pulls'],
      ),
      Branch(
        id: 'onearm',
        name: 'One Arm',
        attachesAtLevel: 5,
        exerciseIds: ['archer_rows', 'one_arm_rows'],
      ),
    ],
  ),

  // ── Pair 3: horizontal push ──────────────────────────────────────────────
  Path(
    id: 'pushup',
    name: 'Push-up',
    slot: Slot.pair3b,
    wikiUrl: 'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/pushup/',
    trunkIds: [
      'wall_pushups',
      'incline_pushups',
      'full_pushups',
      'diamond_pushups',
    ],
    branches: [
      Branch(
        id: 'pseudoplanche',
        name: 'Pseudo Planche',
        attachesAtLevel: 5,
        isDefault: true,
        exerciseIds: ['pseudo_planche_pushups'],
      ),
      Branch(
        id: 'rings',
        name: 'Rings',
        attachesAtLevel: 5,
        exerciseIds: [
          'ring_pushups',
          'rto_pushups',
          'rto_pseudo_planche_pushups',
        ],
      ),
      Branch(
        id: 'hspu',
        name: 'Handstand Push-up',
        attachesAtLevel: 5,
        exerciseIds: _hspuChain,
      ),
    ],
  ),

  // ── Core triplet ─────────────────────────────────────────────────────────
  Path(
    id: 'antiextension',
    name: 'Anti-Extension',
    slot: Slot.triplet1,
    wikiUrl:
        'https://www.reddit.com/r/bodyweightfitness/wiki/exercises/core/#wiki_anti-extension',
    trunkIds: ['planks'],
    branches: [
      Branch(
        id: 'rings',
        name: 'Rings',
        attachesAtLevel: 2,
        isDefault: true,
        exerciseIds: ['ring_ab_rollouts'],
      ),
      Branch(
        id: 'abwheel',
        name: 'Ab Wheel',
        attachesAtLevel: 2,
        exerciseIds: [
          'kneeling_ab_wheel_rollouts',
          'standing_ab_wheel_rollouts',
        ],
      ),
      Branch(
        id: 'hanging',
        name: 'Hanging Leg Raise',
        attachesAtLevel: 2,
        exerciseIds: [
          'tucked_hanging_leg_raises',
          'pike_hanging_leg_raise_eccentrics',
          'straight_hanging_leg_raises',
        ],
      ),
      Branch(
        id: 'compression',
        name: 'Compression',
        attachesAtLevel: 2,
        exerciseIds: ['pike_compressions'],
      ),
    ],
  ),

  // Pallof is anti-rotation, Copenhagen is anti-lateral-flexion; the RR treats
  // them as one slot. Named for the more common reading.
  Path(
    id: 'antirotation',
    name: 'Anti-Rotation',
    slot: Slot.triplet2,
    // No shared trunk — these branches are independent entry points.
    trunkIds: [],
    branches: [
      Branch(
        id: 'ringpallof',
        name: 'Ring Pallof Press',
        attachesAtLevel: 1,
        isDefault: true,
        exerciseIds: ['ring_pallof_press'],
      ),
      Branch(
        id: 'weightedpallof',
        name: 'Weighted Pallof Press',
        attachesAtLevel: 1,
        exerciseIds: ['pallof_press'],
      ),
      Branch(
        id: 'copenhagen',
        name: 'Copenhagen Plank',
        attachesAtLevel: 1,
        exerciseIds: [
          'assisted_knee_copenhagen_planks',
          'knee_copenhagen_planks',
          'assisted_copenhagen_planks',
          'copenhagen_planks',
          'copenhagen_planks_with_movement',
        ],
      ),
    ],
  ),

  Path(
    id: 'extension',
    name: 'Extension',
    slot: Slot.triplet3,
    trunkIds: [],
    branches: [
      Branch(
        id: 'arch',
        name: 'Arch Body',
        attachesAtLevel: 1,
        isDefault: true,
        exerciseIds: ['arch_raises', 'arch_body_holds', 'arch_body_rocks'],
      ),
      Branch(
        id: 'reversehyper',
        name: 'Reverse Hyperextension',
        attachesAtLevel: 1,
        exerciseIds: ['reverse_hyperextensions'],
      ),
      Branch(
        id: 'hyper',
        name: 'Hyperextension',
        attachesAtLevel: 1,
        exerciseIds: ['hyperextensions'],
      ),
    ],
  ),
];

final Map<String, Path> pathsById = {for (final p in allPaths) p.id: p};

Path pathById(String id) {
  final p = pathsById[id];
  if (p == null) throw ArgumentError('unknown path id: $id');
  return p;
}
