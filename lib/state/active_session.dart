import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/progression.dart';
import '../domain/session_plan.dart';
import '../domain/workout_steps.dart';
import '../providers.dart';
import '../trees/paths.dart';
import '../trees/tree_rules.dart';
import 'timer_providers.dart';

final _random = Random();

/// A workout in progress.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.startedAt,
    required this.plan,
    required this.steps,
    required this.cursor,
    required this.exerciseByPath,
    required this.pairRestSeconds,
    required this.tripletRestSeconds,
  });

  final String id;
  final DateTime startedAt;
  final SessionPlan plan;
  final List<WorkoutStep> steps;
  final SessionCursor cursor;

  /// Resolved once at session start and then frozen.
  ///
  /// Deliberately not recomputed as the workout runs: the alternating hinge
  /// branch picks its lift from the completed-session count, so recomputing
  /// after the count changes would swap the exercise underneath a user who is
  /// two sets into it.
  final Map<String, String> exerciseByPath;

  final int pairRestSeconds;
  final int tripletRestSeconds;

  /// The step being worked, or null when the session has run out of steps.
  WorkoutStep? get currentStep =>
      nextStep(steps, cursor.stepIndex, cursor.skippedPathIds);

  bool get isFinished => currentStep == null;

  int get stepsRemaining =>
      remainingSteps(steps, cursor.stepIndex, cursor.skippedPathIds);

  int get stepsTotal => remainingSteps(steps, 0, cursor.skippedPathIds);

  String exerciseFor(WorkoutStep step) => exerciseByPath[step.pathId]!;

  /// Rest after [step], in seconds.
  int restSecondsAfter(WorkoutStep step) =>
      step.isTriplet ? tripletRestSeconds : pairRestSeconds;

  ActiveSession copyWith({SessionCursor? cursor}) => ActiveSession(
        id: id,
        startedAt: startedAt,
        plan: plan,
        steps: steps,
        cursor: cursor ?? this.cursor,
        exerciseByPath: exerciseByPath,
        pairRestSeconds: pairRestSeconds,
        tripletRestSeconds: tripletRestSeconds,
      );
}

/// Owns the workout lifecycle: start, log, skip, resume, finish.
///
/// Every mutation writes through to the database before updating state, so a
/// session killed at any point resumes to exactly what the user saw.
class ActiveSessionController extends AsyncNotifier<ActiveSession?> {
  @override
  Future<ActiveSession?> build() async {
    final db = ref.read(databaseProvider);
    final row = await db.inProgressSession;
    if (row == null) return null;
    return _hydrate(row);
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Rebuilds an in-flight session from its stored row.
  ///
  /// The plan is regenerated from the session's own `rotationIndex` rather
  /// than from today's completed count, so resuming cannot reshuffle the
  /// workout the user is halfway through.
  Future<ActiveSession> _hydrate(WorkoutSession row) async {
    final positions = await _positions();
    final plan = SessionPlan(
      rotationIndex: row.rotationIndex,
      pairs: pairRotations[row.rotationIndex],
      tripletPathIds: tripletOrder,
      warmup: warmupFor(reachedExercises(positions)),
    );

    return ActiveSession(
      id: row.id,
      startedAt: row.startedAt,
      plan: plan,
      steps: buildSteps(plan),
      cursor: SessionCursor.decode(row.cursorJson),
      exerciseByPath: _resolveExercises(positions, row.rotationIndex),
      pairRestSeconds: row.pairRestSeconds,
      tripletRestSeconds: row.tripletRestSeconds,
    );
  }

  Future<Map<String, PathPosition>> _positions() async {
    final rows = await _db.progressionConfigsAll;
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
  }

  /// [sessionOrdinal] is the completed-session count this workout *is*, which
  /// is what the alternating hinge pattern indexes against.
  Map<String, String> _resolveExercises(
    Map<String, PathPosition> positions,
    int sessionOrdinal,
  ) {
    return {
      for (final path in allPaths)
        path.id: exerciseForSession(
          path: path,
          branch: path.branchById(positions[path.id]!.branchId) ??
              path.defaultBranch,
          selectedExerciseId: positions[path.id]!.exerciseId,
          completedSessions: sessionOrdinal,
        ),
    };
  }

  /// Opens a new session and starts the clock.
  Future<void> start() async {
    final profile = await _db.profile;
    final completed = await _db.completedSessionCount();
    final positions = await _positions();

    final rotationIndex = rotationIndexFor(
      completed,
      rotatePairOrder: profile.rotatePairOrder,
    );
    final plan = SessionPlan(
      rotationIndex: rotationIndex,
      pairs: pairRotations[rotationIndex],
      tripletPathIds: tripletOrder,
      warmup: warmupFor(reachedExercises(positions)),
    );

    final now = ref.read(clockProvider).now();
    // Timestamp plus randomness: the clock alone collides whenever two
    // sessions start in the same microsecond, which a fake clock does every
    // time and a real one could do after a fast abandon-and-restart.
    final id = 'session-${now.microsecondsSinceEpoch}-'
        '${_random.nextInt(1 << 32).toRadixString(36)}';
    const cursor = SessionCursor();

    await _db.startSession(
      id: id,
      startedAt: now,
      rotationIndex: rotationIndex,
      pairRestSeconds: profile.defaultPairRestSeconds,
      tripletRestSeconds: profile.defaultTripletRestSeconds,
      cursorJson: cursor.encode(),
    );

    state = AsyncData(ActiveSession(
      id: id,
      startedAt: now,
      plan: plan,
      steps: buildSteps(plan),
      cursor: cursor,
      // The hinge pattern indexes by how many sessions are already done, so
      // this session is number `completed`.
      exerciseByPath: _resolveExercises(positions, completed),
      pairRestSeconds: profile.defaultPairRestSeconds,
      tripletRestSeconds: profile.defaultTripletRestSeconds,
    ));

    ref.read(sessionClockProvider.notifier).start(startedAt: now);
  }

  /// Picks a stored in-progress session back up.
  Future<void> resume() async {
    final session = state.value;
    if (session == null) return;
    ref.read(sessionClockProvider.notifier).start(startedAt: session.startedAt);
  }

  Future<void> _persist(ActiveSession session) async {
    await _db.saveCursor(session.id, session.cursor.encode());
    state = AsyncData(session);
  }

  Future<void> completeWarmup() async {
    final session = state.value;
    if (session == null) return;
    await _persist(
      session.copyWith(cursor: session.cursor.copyWith(warmupComplete: true)),
    );
  }

  /// Records one set and moves to the next step.
  ///
  /// Exactly one of [reps] and [holdSeconds] must be set; the schema enforces
  /// it too, but failing here is a clearer error than a constraint violation.
  Future<void> logSet({
    required int? reps,
    required int? holdSeconds,
    double weightKg = 0,
  }) async {
    final session = state.value;
    final step = session?.currentStep;
    if (session == null || step == null) return;
    assert(
      (reps == null) != (holdSeconds == null),
      'a set is either reps or a hold, never both or neither',
    );

    final now = ref.read(clockProvider).now();
    final exerciseId = session.exerciseFor(step);

    await _db.logSet(
      SetRecordsCompanion.insert(
        // Deterministic rather than random: re-logging the same set after an
        // edit overwrites it instead of creating a duplicate.
        id: '${session.id}-${step.pathId}-${step.setIndex}',
        sessionId: session.id,
        pathId: step.pathId,
        exerciseId: exerciseId,
        setIndex: step.setIndex,
        repsCompleted: Value(reps),
        holdSeconds: Value(holdSeconds),
        weightKg: Value(weightKg),
        recordedAt: now,
      ),
    );

    await _advance(session, step);
  }

  Future<void> _advance(ActiveSession session, WorkoutStep step) async {
    final next = session.copyWith(
      cursor: session.cursor.copyWith(stepIndex: step.index + 1),
    );
    await _persist(next);

    if (next.currentStep != null) {
      ref
          .read(restTimerProvider.notifier)
          .start(Duration(seconds: session.restSecondsAfter(step)));
    } else {
      // The workout is over. Clearing rather than merely not starting one:
      // the rest begun after the second-to-last set is still counting down,
      // and leaving it to chime at someone who has finished is noise.
      ref.read(restTimerProvider.notifier).skip();
    }
  }

  /// Drops the current exercise for the rest of the session.
  ///
  /// Skipped exercises log nothing and are excluded from progression, so a
  /// day without a dip bar cannot push the user backwards.
  Future<void> skipCurrentExercise() async {
    final session = state.value;
    final step = session?.currentStep;
    if (session == null || step == null) return;

    await _persist(session.copyWith(
      cursor: session.cursor.copyWith(
        skippedPathIds: {...session.cursor.skippedPathIds, step.pathId},
      ),
    ));
    ref.read(restTimerProvider.notifier).skip();
  }

  /// Corrects an already-logged set without moving the cursor.
  Future<void> editSet({
    required String pathId,
    required int setIndex,
    required int? reps,
    required int? holdSeconds,
    double weightKg = 0,
  }) async {
    final session = state.value;
    if (session == null) return;

    await _db.logSet(
      SetRecordsCompanion.insert(
        id: '${session.id}-$pathId-$setIndex',
        sessionId: session.id,
        pathId: pathId,
        exerciseId: session.exerciseByPath[pathId]!,
        setIndex: setIndex,
        repsCompleted: Value(reps),
        holdSeconds: Value(holdSeconds),
        weightKg: Value(weightKg),
        recordedAt: ref.read(clockProvider).now(),
      ),
    );
    // Nudge watchers; the set list is a separate stream but the screen reads
    // both together.
    state = AsyncData(session);
  }

  /// Ends the workout. [completed] false marks it abandoned, which keeps the
  /// logged sets but does not advance the rotation.
  Future<void> finish({required bool completed}) async {
    final session = state.value;
    if (session == null) return;

    await _db.closeSession(
      session.id,
      status: completed ? 'completed' : 'abandoned',
      endedAt: ref.read(clockProvider).now(),
    );

    ref.read(restTimerProvider.notifier).skip();
    ref.read(sessionClockProvider.notifier).stop();
    ref.invalidate(completedSessionCountProvider);
    state = const AsyncData(null);
  }

  /// Runs the progression rule over everything worked this session.
  ///
  /// Returns one entry per exercise that produced a prompt. State changes are
  /// written here — including the failure counter on a silent hold, which is
  /// the easy thing to miss: a first failing session shows nothing but must
  /// still be remembered, or the second one can never see it.
  Future<List<SessionOutcome>> evaluateSession() async {
    final session = state.value;
    if (session == null) return const [];

    final units = ref.read(unitSystemProvider);
    final positions = await _positions();
    final sets = await _db.setsForSession(session.id);
    final outcomes = <SessionOutcome>[];

    final byPath = <String, List<SetRecord>>{};
    for (final record in sets) {
      byPath.putIfAbsent(record.pathId, () => []).add(record);
    }

    for (final entry in byPath.entries) {
      final path = pathById(entry.key);
      final position = positions[path.id]!;
      final branch = path.branchById(position.branchId) ?? path.defaultBranch;
      final exerciseId = session.exerciseByPath[path.id]!;
      final existing = await _db.exerciseState(exerciseId);

      final values = (entry.value..sort((a, b) => a.setIndex.compareTo(b.setIndex)))
          .map((r) => r.repsCompleted ?? r.holdSeconds ?? 0)
          .toList();

      final evaluation = evaluate(
        contextFor(
          path: path,
          branch: branch,
          exerciseId: exerciseId,
          workingLoadKg: existing?.workingLoadKg ?? 0,
          lastIncrementKg: existing?.lastIncrementKg,
          consecutiveFailures: existing?.consecutiveFailures ?? 0,
          alreadyMastered: existing?.masteredAt != null,
        ),
        values,
        units: units,
      );

      await _db.saveExerciseState(
        exerciseId,
        consecutiveFailures: evaluation.consecutiveFailures,
        masteredAt: evaluation.markMastered
            ? ref.read(clockProvider).now()
            : null,
      );

      if (evaluation.outcome is! HoldOutcome) {
        outcomes.add(SessionOutcome(
          pathId: path.id,
          exerciseId: exerciseId,
          outcome: evaluation.outcome,
        ));
      }
    }

    return outcomes;
  }

  /// Applies a prompt the user accepted.
  Future<void> applyOutcome(SessionOutcome outcome, {double? incrementKg}) async {
    final positions = await _positions();
    final path = pathById(outcome.pathId);
    final position = positions[path.id]!;
    final now = ref.read(clockProvider).now();

    switch (outcome.outcome) {
      case AdvanceOutcome(nextExerciseId: final next):
        await _db.saveProgressionConfig(
          pathId: path.id,
          branchId: position.branchId,
          exerciseId: next,
          now: now,
        );
      case RegressOutcome(previousExerciseId: final previous):
        await _db.saveProgressionConfig(
          pathId: path.id,
          branchId: position.branchId,
          exerciseId: previous,
          now: now,
        );
      case AddLoadOutcome(:final resultingLoadKg, :final suggestedIncrementKg):
        await _db.saveExerciseState(
          outcome.exerciseId,
          workingLoadKg: resultingLoadKg,
          lastIncrementKg: incrementKg ?? suggestedIncrementKg,
          now: now,
        );
      case ReduceLoadOutcome(:final resultingLoadKg, :final suggestedIncrementKg):
        await _db.saveExerciseState(
          outcome.exerciseId,
          workingLoadKg: resultingLoadKg,
          lastIncrementKg: incrementKg ?? suggestedIncrementKg,
          now: now,
        );
      case MasteredOutcome():
      case HoldOutcome():
        break;
    }
  }
}

/// A prompt to show on the summary screen.
class SessionOutcome {
  const SessionOutcome({
    required this.pathId,
    required this.exerciseId,
    required this.outcome,
  });

  final String pathId;
  final String exerciseId;
  final ProgressionOutcome outcome;
}

final activeSessionProvider =
    AsyncNotifierProvider<ActiveSessionController, ActiveSession?>(
  ActiveSessionController.new,
);

/// Sets logged in the current session, for the "already done" list and edits.
final currentSessionSetsProvider = StreamProvider<List<SetRecord>>((ref) {
  final session = ref.watch(activeSessionProvider).value;
  if (session == null) return Stream.value(const []);
  return ref.watch(databaseProvider).watchSetsForSession(session.id);
});

/// What the user managed on this exercise last time, used to pre-fill the
/// logger so the common case is one tap.
final previousSetsProvider =
    FutureProvider.family<List<SetRecord>, String>((ref, exerciseId) {
  final session = ref.watch(activeSessionProvider).value;
  return ref.watch(databaseProvider).lastSessionSets(
        exerciseId,
        excludingSessionId: session?.id,
      );
});
