import '../trees/exercises.dart';
import '../trees/tree_types.dart';
import 'rep_scheme.dart';
import 'units.dart';

/// What the app should offer the user after an exercise is finished.
///
/// Every outcome except [HoldOutcome] and [MasteredOutcome] is a *prompt* —
/// nothing here ever applies itself. See `docs/PLAN.md` §2.2.
sealed class ProgressionOutcome {
  const ProgressionOutcome();
}

/// Nothing to say: mid-range, incomplete, or already acknowledged.
class HoldOutcome extends ProgressionOutcome {
  const HoldOutcome();
}

/// Offer to move up to [nextExerciseId].
class AdvanceOutcome extends ProgressionOutcome {
  const AdvanceOutcome(this.nextExerciseId);
  final String nextExerciseId;
}

/// Offer to drop back to [previousExerciseId].
class RegressOutcome extends ProgressionOutcome {
  const RegressOutcome(this.previousExerciseId);
  final String previousExerciseId;
}

/// Offer to add weight. [suggestedIncrementKg] pre-fills the prompt's editable
/// amount; [resultingLoadKg] is what the total becomes if accepted unchanged.
class AddLoadOutcome extends ProgressionOutcome {
  const AddLoadOutcome({
    required this.currentLoadKg,
    required this.suggestedIncrementKg,
    required this.resultingLoadKg,
  });

  final double currentLoadKg;
  final double suggestedIncrementKg;
  final double resultingLoadKg;
}

/// Offer to take weight off, the load-mode form of regression.
class ReduceLoadOutcome extends ProgressionOutcome {
  const ReduceLoadOutcome({
    required this.currentLoadKg,
    required this.suggestedIncrementKg,
    required this.resultingLoadKg,
  });

  final double currentLoadKg;
  final double suggestedIncrementKg;
  final double resultingLoadKg;
}

/// The end of a bodyweight branch: maxed out, with no harder exercise and no
/// weight to add. Shown once and then never again — which is why
/// [Evaluation.markMastered] exists and needs somewhere to persist.
class MasteredOutcome extends ProgressionOutcome {
  const MasteredOutcome();
}

/// The result of evaluating one exercise's sets, including the state changes
/// the caller must persist.
///
/// State is returned rather than written so the whole rule stays a pure
/// function — the reason this logic is testable at every boundary without a
/// database.
class Evaluation {
  const Evaluation({
    required this.outcome,
    required this.consecutiveFailures,
    this.markMastered = false,
  });

  final ProgressionOutcome outcome;

  /// The counter's new value. Persist it even when [outcome] is a hold: a
  /// first failing session produces no prompt but must still be remembered,
  /// or the second one can never see it.
  final int consecutiveFailures;

  /// Set the exercise's `masteredAt` so the congratulation does not repeat.
  final bool markMastered;
}

/// Everything the rule needs to know about where an exercise sits.
class ExerciseContext {
  const ExerciseContext({
    required this.exercise,
    required this.slot,
    required this.nextExerciseId,
    required this.previousExerciseId,
    this.workingLoadKg = 0,
    this.lastIncrementKg,
    this.consecutiveFailures = 0,
    this.alreadyMastered = false,
  });

  final Exercise exercise;
  final Slot slot;

  /// Null when this is the last exercise on the branch.
  final String? nextExerciseId;

  /// Null when this is the first exercise on the branch — there is nothing
  /// easier to drop back to.
  final String? previousExerciseId;

  final double workingLoadKg;

  /// What the user last chose to add here. Null seeds the prompt.
  final double? lastIncrementKg;

  final int consecutiveFailures;
  final bool alreadyMastered;
}

/// How many consecutive failing sessions before regression is offered.
///
/// One bad day is not a deload — see `docs/PLAN.md` §2.2.
const failuresBeforeRegression = 2;

/// Decides what to offer after [setValues] were logged for one exercise.
///
/// [setValues] holds reps or seconds, one per completed set, exactly as
/// recorded — nothing is clamped to the target range.
Evaluation evaluate(
  ExerciseContext context,
  List<int> setValues, {
  required UnitSystem units,
}) {
  final scheme = schemeFor(context.exercise, context.slot);

  // Fewer sets than the scheme calls for means the exercise was skipped or
  // the session ended early. That is neither a success nor a failure, and it
  // must not touch the counter — otherwise a short day pushes the user
  // backwards. See `docs/PLAN.md` §5.3.
  if (setValues.length < scheme.sets) {
    return Evaluation(
      outcome: const HoldOutcome(),
      consecutiveFailures: context.consecutiveFailures,
    );
  }

  if (scheme.isMaxedBy(setValues)) return _advance(context, units);
  if (scheme.isFailedBy(setValues)) return _fail(context, units);

  // In range: not a failure, so the counter resets.
  return const Evaluation(outcome: HoldOutcome(), consecutiveFailures: 0);
}

Evaluation _advance(ExerciseContext context, UnitSystem units) {
  if (context.exercise.mode == ProgressionMode.load) {
    final increment = context.lastIncrementKg ?? seedIncrementKg(units);
    return Evaluation(
      outcome: AddLoadOutcome(
        currentLoadKg: context.workingLoadKg,
        suggestedIncrementKg: increment,
        resultingLoadKg:
            applyIncrement(context.workingLoadKg, increment, units),
      ),
      consecutiveFailures: 0,
    );
  }

  final next = context.nextExerciseId;
  if (next != null) {
    return Evaluation(outcome: AdvanceOutcome(next), consecutiveFailures: 0);
  }

  // End of a bodyweight branch: nothing harder, nothing to load. Say so once.
  if (context.alreadyMastered) {
    return const Evaluation(outcome: HoldOutcome(), consecutiveFailures: 0);
  }
  return const Evaluation(
    outcome: MasteredOutcome(),
    consecutiveFailures: 0,
    markMastered: true,
  );
}

Evaluation _fail(ExerciseContext context, UnitSystem units) {
  final failures = context.consecutiveFailures + 1;
  if (failures < failuresBeforeRegression) {
    return Evaluation(
      outcome: const HoldOutcome(),
      consecutiveFailures: failures,
    );
  }

  if (context.exercise.mode == ProgressionMode.load) {
    final increment = context.lastIncrementKg ?? seedIncrementKg(units);
    return Evaluation(
      outcome: ReduceLoadOutcome(
        currentLoadKg: context.workingLoadKg,
        suggestedIncrementKg: increment,
        resultingLoadKg:
            removeIncrement(context.workingLoadKg, increment, units),
      ),
      consecutiveFailures: 0,
    );
  }

  final previous = context.previousExerciseId;
  if (previous != null) {
    return Evaluation(
      outcome: RegressOutcome(previous),
      consecutiveFailures: 0,
    );
  }

  // Already at the easiest exercise on the branch. Keep counting rather than
  // resetting: the user is still failing, and silently zeroing would claim
  // otherwise.
  return Evaluation(
    outcome: const HoldOutcome(),
    consecutiveFailures: failures,
  );
}

/// Builds an [ExerciseContext] by locating [exerciseId] on [branch].
ExerciseContext contextFor({
  required Path path,
  required Branch branch,
  required String exerciseId,
  double workingLoadKg = 0,
  double? lastIncrementKg,
  int consecutiveFailures = 0,
  bool alreadyMastered = false,
}) {
  // Alternating branches have no ladder, so neighbours come from the branch
  // itself only when it is linear.
  final line = branch.kind == BranchKind.alternating
      ? const <String>[]
      : path.progressionFor(branch);
  final index = line.indexOf(exerciseId);

  return ExerciseContext(
    exercise: exerciseById(exerciseId),
    slot: path.slot,
    nextExerciseId: index >= 0 && index < line.length - 1 ? line[index + 1] : null,
    previousExerciseId: index > 0 ? line[index - 1] : null,
    workingLoadKg: workingLoadKg,
    lastIncrementKg: lastIncrementKg,
    consecutiveFailures: consecutiveFailures,
    alreadyMastered: alreadyMastered,
  );
}
