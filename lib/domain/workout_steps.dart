import 'dart:convert';

import '../trees/paths.dart';
import '../trees/tree_types.dart';
import 'session_plan.dart';

/// One set of one exercise — the atom of a workout.
///
/// A session is a flat, ordered list of these. Flattening up front is what
/// makes the alternating pair rhythm (A1, B1, A2, B2, A3, B3) and the triplet
/// circuit (G1, H1, I1, G2, …) the same shape, so the screen and the resume
/// logic have one thing to walk instead of nested loops with special cases.
class WorkoutStep {
  const WorkoutStep({
    required this.index,
    required this.pathId,
    required this.setIndex,
    required this.slot,
    required this.blockLabel,
  });

  /// Position in the session's step list.
  final int index;

  final String pathId;

  /// 1-based: set 1, 2 or 3.
  final int setIndex;

  final Slot slot;

  /// Shown above the exercise, e.g. "Pair 2" or "Core triplet".
  final String blockLabel;

  bool get isTriplet => slot.isTriplet;
}

/// Flattens a plan into the order the user actually works through it.
///
/// Pairs alternate within each set so one side rests while the other works;
/// the triplet is a circuit, cycling all three before repeating.
List<WorkoutStep> buildSteps(SessionPlan plan, {int sets = 3}) {
  final steps = <WorkoutStep>[];

  void add(String pathId, int setIndex, Slot slot, String label) {
    steps.add(WorkoutStep(
      index: steps.length,
      pathId: pathId,
      setIndex: setIndex,
      slot: slot,
      blockLabel: label,
    ));
  }

  for (final (blockIndex, pair) in plan.pairs.indexed) {
    final label = 'Pair ${blockIndex + 1}';
    for (var set = 1; set <= sets; set++) {
      add(pair.aPathId, set, pathById(pair.aPathId).slot, label);
      add(pair.bPathId, set, pathById(pair.bPathId).slot, label);
    }
  }

  for (var round = 1; round <= sets; round++) {
    for (final pathId in plan.tripletPathIds) {
      add(pathId, round, pathById(pathId).slot, 'Core triplet');
    }
  }

  return steps;
}

/// Where the user is in a session, and what they have opted out of.
///
/// Serialised into `workout_sessions.cursor_json` after every change, so an
/// app that is killed mid-workout resumes exactly where it left off rather
/// than losing the sets already logged.
class SessionCursor {
  const SessionCursor({
    this.stepIndex = 0,
    this.warmupComplete = false,
    this.skippedPathIds = const {},
  });

  final int stepIndex;
  final bool warmupComplete;

  /// Skipping is per exercise, not per set: a user who cannot do dips today
  /// means all three sets, not just this one.
  final Set<String> skippedPathIds;

  SessionCursor copyWith({
    int? stepIndex,
    bool? warmupComplete,
    Set<String>? skippedPathIds,
  }) {
    return SessionCursor(
      stepIndex: stepIndex ?? this.stepIndex,
      warmupComplete: warmupComplete ?? this.warmupComplete,
      skippedPathIds: skippedPathIds ?? this.skippedPathIds,
    );
  }

  Map<String, Object?> toJson() => {
        'stepIndex': stepIndex,
        'warmupComplete': warmupComplete,
        'skippedPathIds': skippedPathIds.toList(),
      };

  static SessionCursor fromJson(Map<String, Object?> json) => SessionCursor(
        stepIndex: json['stepIndex'] as int? ?? 0,
        warmupComplete: json['warmupComplete'] as bool? ?? false,
        skippedPathIds: {
          ...?(json['skippedPathIds'] as List?)?.cast<String>(),
        },
      );

  String encode() => jsonEncode(toJson());

  /// Decodes a stored cursor, falling back to the start of the session.
  ///
  /// A malformed cursor must not strand the user in an unopenable workout —
  /// restarting the walk is recoverable, a crash loop is not.
  static SessionCursor decode(String? raw) {
    if (raw == null || raw.isEmpty) return const SessionCursor();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const SessionCursor();
      return fromJson(decoded);
    } on FormatException {
      return const SessionCursor();
    }
  }
}

/// The next step at or after [from] whose path has not been skipped, or null
/// when the session is finished.
WorkoutStep? nextStep(
  List<WorkoutStep> steps,
  int from,
  Set<String> skippedPathIds,
) {
  for (var i = from; i < steps.length; i++) {
    if (!skippedPathIds.contains(steps[i].pathId)) return steps[i];
  }
  return null;
}

/// How many steps remain to be worked, ignoring skipped exercises. Drives the
/// "3 of 24" progress label.
int remainingSteps(
  List<WorkoutStep> steps,
  int from,
  Set<String> skippedPathIds,
) {
  var count = 0;
  for (var i = from; i < steps.length; i++) {
    if (!skippedPathIds.contains(steps[i].pathId)) count++;
  }
  return count;
}
