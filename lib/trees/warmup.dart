import 'tree_types.dart';

/// The RR warmup — 5-10 minutes, and **not** a fixed checklist.
///
/// The last four items are gated: they exist to prepare a movement the user
/// cannot do yet, so they appear only once the relevant progression reaches
/// the trigger exercise. The source plan listed all of them unconditionally
/// and omitted Hinge Activation entirely.
///
/// Nothing here is logged to history — the warmup has no progression and
/// nothing charts it, so completion lives in the session cursor only.
const warmupItems = <WarmupItem>[
  WarmupItem(
    id: 'warmup_shoulder_dislocates',
    name: 'Shoulder Dislocates',
    target: '5-10 reps',
  ),
  WarmupItem(
    id: 'warmup_squat_sky_reaches',
    name: 'Squat Sky Reaches',
    target: '5-10 per side',
    perSide: true,
  ),
  WarmupItem(
    id: 'warmup_wrist_prep',
    name: 'Wrist Prep',
    target: '10+ reps',
  ),
  WarmupItem(
    id: 'warmup_deadbugs',
    name: 'Deadbugs',
    target: '30s',
    metric: Metric.timed,
    holdSeconds: 30,
  ),
  WarmupItem(
    id: 'warmup_arch_hangs',
    name: 'Arch Hangs',
    target: '10 reps',
    unlockedBy: 'pullup_eccentrics',
  ),
  WarmupItem(
    id: 'warmup_support_hold',
    name: 'Support Hold',
    target: '30s',
    metric: Metric.timed,
    holdSeconds: 30,
    unlockedBy: 'dip_eccentrics',
  ),
  WarmupItem(
    id: 'warmup_squat_activation',
    name: 'Squat Activation',
    target: '10 reps',
    unlockedBy: 'bulgarian_split_squats',
  ),
  WarmupItem(
    id: 'warmup_hinge_activation',
    name: 'Hinge Activation',
    target: '10 reps',
    unlockedBy: 'banded_nordic_curls',
  ),
];
