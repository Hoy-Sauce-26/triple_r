// flutter_test exports an accessibility `Evaluation` that collides with ours.
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:triple_r/domain/progression.dart';
import 'package:triple_r/domain/rep_scheme.dart';
import 'package:triple_r/domain/units.dart';
import 'package:triple_r/trees/paths.dart';
import 'package:triple_r/trees/tree_types.dart';

void main() {
  Evaluation run(
    ExerciseContext context,
    List<int> sets, {
    UnitSystem units = UnitSystem.imperial,
    double? configuredIncrementKg,
  }) =>
      evaluate(
        context,
        sets,
        units: units,
        configuredIncrementKg: configuredIncrementKg,
      );

  /// A mid-branch pair exercise: Full Push-ups, with Diamond above and
  /// Incline below.
  ExerciseContext pushupContext({
    int failures = 0,
    bool mastered = false,
  }) {
    final path = pathById('pushup');
    return contextFor(
      path: path,
      branch: path.branchById('pseudoplanche')!,
      exerciseId: 'full_pushups',
      consecutiveFailures: failures,
      alreadyMastered: mastered,
    );
  }

  group('rep schemes', () {
    test('pairs run 5-8 and the triplet runs 8-12', () {
      expect(pairScheme.floor, 5);
      expect(pairScheme.ceiling, 8);
      expect(tripletScheme.floor, 8);
      expect(tripletScheme.ceiling, 12);
    });

    test('metric wins over slot for timed holds', () {
      // Parallel Bar Support Hold opens a *pair* path but is timed.
      final dip = pathById('dip');
      final support = contextFor(
        path: dip,
        branch: dip.branchById('weighted')!,
        exerciseId: 'parallel_bar_support_hold',
      );
      expect(schemeFor(support.exercise, support.slot), timedScheme);

      // Planks is timed and in the triplet — same answer.
      final core = pathById('antiextension');
      final planks = contextFor(
        path: core,
        branch: core.branchById('rings')!,
        exerciseId: 'planks',
      );
      expect(schemeFor(planks.exercise, planks.slot), timedScheme);
    });

    test('a rep exercise in the triplet uses the triplet range', () {
      final core = pathById('antiextension');
      final rollouts = contextFor(
        path: core,
        branch: core.branchById('rings')!,
        exerciseId: 'ring_ab_rollouts',
      );
      expect(schemeFor(rollouts.exercise, rollouts.slot), tripletScheme);
    });
  });

  group('range boundaries', () {
    test('all sets at the ceiling advances', () {
      final result = run(pushupContext(), [8, 8, 8]);
      expect(result.outcome, isA<AdvanceOutcome>());
      expect((result.outcome as AdvanceOutcome).nextExerciseId, 'diamond_pushups');
    });

    test('one set below the ceiling holds', () {
      expect(run(pushupContext(), [8, 8, 7]).outcome, isA<HoldOutcome>());
    });

    test('above the ceiling still advances', () {
      // Targets are not caps; 11 reps against an 8 target is a clear pass.
      expect(run(pushupContext(), [11, 9, 8]).outcome, isA<AdvanceOutcome>());
    });

    test('exactly at the floor is not a failure', () {
      final result = run(pushupContext(), [5, 5, 5]);
      expect(result.outcome, isA<HoldOutcome>());
      expect(result.consecutiveFailures, 0);
    });

    test('one set below the floor is a failure', () {
      final result = run(pushupContext(), [5, 5, 4]);
      expect(result.consecutiveFailures, 1);
    });

    test('a mid-range session resets an existing failure count', () {
      final result = run(pushupContext(failures: 1), [6, 6, 6]);
      expect(result.consecutiveFailures, 0);
      expect(result.outcome, isA<HoldOutcome>());
    });
  });

  group('incomplete exercises', () {
    test('fewer sets than the scheme neither advances nor fails', () {
      final result = run(pushupContext(), [8, 8]);
      expect(result.outcome, isA<HoldOutcome>());
      expect(result.consecutiveFailures, 0);
    });

    test('a short session leaves an existing failure count untouched', () {
      // A skipped exercise must not push the user toward a deload.
      final result = run(pushupContext(failures: 1), [4]);
      expect(result.consecutiveFailures, 1);
      expect(result.outcome, isA<HoldOutcome>());
    });

    test('no sets at all is a hold', () {
      expect(run(pushupContext(), []).outcome, isA<HoldOutcome>());
    });
  });

  group('regression', () {
    test('takes two consecutive failing sessions', () {
      final first = run(pushupContext(), [4, 4, 4]);
      expect(first.outcome, isA<HoldOutcome>(),
          reason: 'one bad day is not a deload');
      expect(first.consecutiveFailures, 1);

      final second = run(pushupContext(failures: 1), [4, 4, 4]);
      expect(second.outcome, isA<RegressOutcome>());
      expect(
        (second.outcome as RegressOutcome).previousExerciseId,
        'incline_pushups',
      );
      expect(second.consecutiveFailures, 0);
    });

    test('holds at the easiest exercise but keeps counting', () {
      final path = pathById('pushup');
      final wall = contextFor(
        path: path,
        branch: path.branchById('pseudoplanche')!,
        exerciseId: 'wall_pushups',
        consecutiveFailures: 1,
      );
      final result = run(wall, [2, 2, 2]);
      expect(result.outcome, isA<HoldOutcome>(),
          reason: 'nothing easier to drop to');
      expect(result.consecutiveFailures, 2,
          reason: 'still failing; zeroing would claim otherwise');
    });
  });

  group('load mode', () {
    ExerciseContext deadlift({
      double loadKg = 100,
      double? increment,
      int failures = 0,
    }) {
      final hinge = pathById('hinge');
      return contextFor(
        path: hinge,
        branch: hinge.branchById('barbell')!,
        exerciseId: 'barbell_deadlift',
        workingLoadKg: loadKg,
        lastIncrementKg: increment,
        consecutiveFailures: failures,
      );
    }

    test('maxing out offers weight instead of a new exercise', () {
      final result = run(deadlift(increment: poundsToKg(10)), [8, 8, 8]);
      final outcome = result.outcome as AddLoadOutcome;
      expect(kgToPounds(outcome.suggestedIncrementKg), closeTo(10, 1e-9));
      expect(
        kgToPounds(outcome.resultingLoadKg),
        closeTo(kgToPounds(100) + 10, 1e-9),
      );
    });

    test('seeds the prompt at 2.5 lb when nothing is remembered', () {
      final result = run(deadlift(), [8, 8, 8]);
      final outcome = result.outcome as AddLoadOutcome;
      expect(kgToPounds(outcome.suggestedIncrementKg), closeTo(2.5, 1e-9));
    });

    test('uses the increment configured in settings when nothing is '
        'remembered', () {
      final result = run(
        deadlift(),
        [8, 8, 8],
        configuredIncrementKg: poundsToKg(5),
      );
      final outcome = result.outcome as AddLoadOutcome;
      expect(kgToPounds(outcome.suggestedIncrementKg), closeTo(5, 1e-9));
      expect(
        kgToPounds(outcome.resultingLoadKg),
        closeTo(kgToPounds(100) + 5, 1e-9),
      );
    });

    test('what this exercise last moved by still beats the setting', () {
      // A deadlift that has been climbing in 10 lb steps does not drop to the
      // 5 lb step someone chose for their weighted pull-ups.
      final result = run(
        deadlift(increment: poundsToKg(10)),
        [8, 8, 8],
        configuredIncrementKg: poundsToKg(5),
      );
      expect(
        kgToPounds((result.outcome as AddLoadOutcome).suggestedIncrementKg),
        closeTo(10, 1e-9),
      );
    });

    test('the configured increment applies to taking weight off too', () {
      final result = run(
        deadlift(failures: 1),
        [4, 4, 4],
        configuredIncrementKg: poundsToKg(5),
      );
      expect(
        kgToPounds((result.outcome as ReduceLoadOutcome).resultingLoadKg),
        closeTo(kgToPounds(100) - 5, 1e-9),
      );
    });

    test('seeds at 1 kg for metric users', () {
      final result = run(deadlift(), [8, 8, 8], units: UnitSystem.metric);
      expect((result.outcome as AddLoadOutcome).suggestedIncrementKg, 1.0);
    });

    test('two failing sessions offer to take weight off', () {
      final result = run(deadlift(increment: poundsToKg(10), failures: 1), [4, 4, 4]);
      final outcome = result.outcome as ReduceLoadOutcome;
      expect(
        kgToPounds(outcome.resultingLoadKg),
        closeTo(kgToPounds(100) - 10, 1e-9),
      );
      expect(result.consecutiveFailures, 0);
    });

    test('an alternating branch has no neighbours to advance to', () {
      // Both barbell lifts are terminal by construction; the load path is the
      // only way they progress.
      final context = deadlift();
      expect(context.nextExerciseId, isNull);
      expect(context.previousExerciseId, isNull);
    });

    test('weighted shrimp squats progress by load, not by exercise', () {
      final squat = pathById('squat');
      final shrimp = contextFor(
        path: squat,
        branch: squat.branchById('bodyweight')!,
        exerciseId: 'weighted_shrimp_squats',
      );
      expect(shrimp.nextExerciseId, isNull, reason: 'end of the branch');
      expect(run(shrimp, [8, 8, 8]).outcome, isA<AddLoadOutcome>());
    });
  });

  group('mastery', () {
    ExerciseContext pistols({bool mastered = false}) {
      final squat = pathById('squat');
      return contextFor(
        path: squat,
        branch: squat.branchById('pistol')!,
        exerciseId: 'pistol_squats',
        alreadyMastered: mastered,
      );
    }

    test('congratulates once at the end of a bodyweight branch', () {
      final result = run(pistols(), [8, 8, 8]);
      expect(result.outcome, isA<MasteredOutcome>());
      expect(result.markMastered, isTrue);
    });

    test('stays silent on every session after that', () {
      final result = run(pistols(mastered: true), [8, 8, 8]);
      expect(result.outcome, isA<HoldOutcome>());
      expect(result.markMastered, isFalse);
    });

    test('every terminal bodyweight exercise reaches it', () {
      // Roughly two dozen branches end in an exercise with nothing harder and
      // no load — the case the original rule had no answer for.
      final terminals = <String>[];
      for (final path in allPaths) {
        for (final branch in path.branches) {
          if (branch.kind == BranchKind.alternating) continue;
          final context = contextFor(
            path: path,
            branch: branch,
            exerciseId: path.progressionFor(branch).last,
          );
          if (context.exercise.mode == ProgressionMode.load) continue;
          terminals.add(context.exercise.id);
          expect(
            run(context, [99, 99, 99]).outcome,
            isA<MasteredOutcome>(),
            reason: '${path.id}/${branch.id}',
          );
        }
      }
      expect(terminals, isNotEmpty);
    });
  });

  group('timed exercises', () {
    ExerciseContext planks({int failures = 0}) {
      final core = pathById('antiextension');
      return contextFor(
        path: core,
        branch: core.branchById('abwheel')!,
        exerciseId: 'planks',
        consecutiveFailures: failures,
      );
    }

    test('60 second holds advance', () {
      final result = run(planks(), [60, 60, 60]);
      expect(result.outcome, isA<AdvanceOutcome>());
      expect(
        (result.outcome as AdvanceOutcome).nextExerciseId,
        'kneeling_ab_wheel_rollouts',
      );
    });

    test('holds beyond the ceiling are recorded and still advance', () {
      expect(run(planks(), [75, 62, 60]).outcome, isA<AdvanceOutcome>());
    });

    test('under 30 seconds counts as a failing session', () {
      expect(run(planks(), [45, 45, 22]).consecutiveFailures, 1);
    });

    test('between 30 and 60 seconds holds', () {
      expect(run(planks(), [45, 45, 45]).outcome, isA<HoldOutcome>());
    });

    test('planks have nothing easier below them, so failure only counts', () {
      // Planks open the anti-extension path; regression has nowhere to go.
      final result = run(planks(failures: 1), [22, 22, 22]);
      expect(result.outcome, isA<HoldOutcome>());
      expect(result.consecutiveFailures, 2);
    });

    test('a timed exercise mid-chain does regress', () {
      // The Copenhagen progression is timed *and* per side — the combination
      // a single-enum Metric could not express.
      final core = pathById('antirotation');
      final knee = contextFor(
        path: core,
        branch: core.branchById('copenhagen')!,
        exerciseId: 'knee_copenhagen_planks',
        consecutiveFailures: 1,
      );
      expect(knee.exercise.perSide, isTrue);

      final result = run(knee, [20, 20, 20]);
      expect(
        (result.outcome as RegressOutcome).previousExerciseId,
        'assisted_knee_copenhagen_planks',
      );
    });
  });
}
