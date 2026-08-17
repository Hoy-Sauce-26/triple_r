import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/domain/session_plan.dart';
import 'package:triple_r/trees/paths.dart';
import 'package:triple_r/trees/tree_rules.dart';

void main() {
  SessionPlan plan(
    int completed, {
    bool rotate = true,
    Set<String> reached = const {},
  }) =>
      planSession(
        completedSessions: completed,
        rotatePairOrder: rotate,
        reachedExerciseIds: reached,
      );

  group('rotation', () {
    test('cycles the three pair orders', () {
      expect(plan(0).pairs.first.pathIds, ['pullup', 'squat']);
      expect(plan(1).pairs.first.pathIds, ['dip', 'hinge']);
      expect(plan(2).pairs.first.pathIds, ['row', 'pushup']);
      expect(plan(3).pairs.first.pathIds, ['pullup', 'squat']);
    });

    test('every rotation covers all six pair paths exactly once', () {
      for (var i = 0; i < 3; i++) {
        final ids = [for (final p in plan(i).pairs) ...p.pathIds];
        expect(ids.toSet(), hasLength(6), reason: 'rotation $i');
      }
    });

    test('the triplet always runs last, in a fixed order', () {
      for (var i = 0; i < 6; i++) {
        final p = plan(i);
        expect(p.tripletPathIds, ['antiextension', 'antirotation', 'extension']);
        expect(p.pathIdsInOrder.sublist(6), p.tripletPathIds);
      }
    });

    test('pins to the book order when rotation is switched off', () {
      for (var i = 0; i < 5; i++) {
        final p = plan(i, rotate: false);
        expect(p.rotationIndex, 0);
        expect(p.pairs.first.pathIds, ['pullup', 'squat']);
      }
    });

    test('a negative session count cannot produce a negative index', () {
      // Dart's % on a negative left operand returns a negative result, which
      // would throw deep inside the plan builder rather than here.
      expect(rotationIndexFor(-1, rotatePairOrder: true), isNonNegative);
      expect(rotationIndexFor(-4, rotatePairOrder: true), isNonNegative);
    });

    test('plans nine paths in order', () {
      expect(plan(0).pathIdsInOrder, hasLength(9));
      expect(plan(0).pathIdsInOrder.toSet(), hasLength(9));
    });
  });

  group('warmup gating', () {
    test('a beginner sees only the four unconditional items', () {
      final items = warmupFor({});
      expect(items.map((w) => w.name), [
        'Shoulder Dislocates',
        'Squat Sky Reaches',
        'Wrist Prep',
        'Deadbugs',
      ]);
    });

    test('each trigger adds exactly its own item', () {
      expect(
        warmupFor({'pullup_eccentrics'}).map((w) => w.name),
        contains('Arch Hangs'),
      );
      expect(
        warmupFor({'dip_eccentrics'}).map((w) => w.name),
        contains('Support Hold'),
      );
      expect(
        warmupFor({'bulgarian_split_squats'}).map((w) => w.name),
        contains('Squat Activation'),
      );
      expect(
        warmupFor({'banded_nordic_curls'}).map((w) => w.name),
        contains('Hinge Activation'),
      );
    });

    test('a fully progressed user sees all eight', () {
      final everything = {
        'pullup_eccentrics',
        'dip_eccentrics',
        'bulgarian_split_squats',
        'banded_nordic_curls',
      };
      expect(warmupFor(everything), hasLength(8));
    });

    test('order is stable regardless of what is unlocked', () {
      final partial = warmupFor({'dip_eccentrics'}).map((w) => w.id).toList();
      final full = warmupFor({
        'pullup_eccentrics',
        'dip_eccentrics',
        'bulgarian_split_squats',
        'banded_nordic_curls',
      }).map((w) => w.id).toList();
      expect(full.where(partial.contains), partial);
    });

    test('wires up to real progression positions', () {
      // End to end: a fresh install unlocks nothing extra, and reaching
      // Pull-up Eccentrics adds Arch Hangs.
      final fresh = {for (final p in allPaths) p.id: initialPosition(p)};
      expect(plan(0, reached: reachedExercises(fresh)).warmup, hasLength(4));

      final progressed = {
        ...fresh,
        'pullup': const PathPosition(
          branchId: 'weighted',
          exerciseId: 'pullup_eccentrics',
        ),
      };
      final warmup = plan(0, reached: reachedExercises(progressed)).warmup;
      expect(warmup, hasLength(5));
      expect(warmup.map((w) => w.name), contains('Arch Hangs'));
    });
  });

  group('exercise selection per session', () {
    test('a linear branch uses the stored position', () {
      final path = pathById('pushup');
      expect(
        exerciseForSession(
          path: path,
          branch: path.branchById('pseudoplanche')!,
          selectedExerciseId: 'full_pushups',
          completedSessions: 7,
        ),
        'full_pushups',
      );
    });

    test('a linear branch with nothing stored starts at the beginning', () {
      final path = pathById('pushup');
      expect(
        exerciseForSession(
          path: path,
          branch: path.branchById('pseudoplanche')!,
          selectedExerciseId: null,
          completedSessions: 0,
        ),
        'wall_pushups',
      );
    });

    test('the alternating hinge branch follows the weekly pattern', () {
      final hinge = pathById('hinge');
      final branch = hinge.branchById('barbell')!;
      final six = [
        for (var i = 0; i < 6; i++)
          exerciseForSession(
            path: hinge,
            branch: branch,
            selectedExerciseId: null,
            completedSessions: i,
          ),
      ];
      expect(six, [
        'barbell_romanian_deadlift',
        'barbell_deadlift',
        'barbell_romanian_deadlift',
        'barbell_romanian_deadlift',
        'barbell_deadlift',
        'barbell_romanian_deadlift',
      ]);
    });

    test('deadlifts land once a week, RDL twice, over a month', () {
      final hinge = pathById('hinge');
      final branch = hinge.branchById('barbell')!;
      final month = [
        for (var i = 0; i < 12; i++) branch.exerciseForSession(i),
      ];
      expect(month.where((e) => e == 'barbell_deadlift'), hasLength(4));
      expect(month.where((e) => e == 'barbell_romanian_deadlift'), hasLength(8));
    });

    test('the alternating branch ignores the stored exercise entirely', () {
      // selected_exercise_id is null for alternating branches, but a stale
      // value from a branch switch must not leak through.
      final hinge = pathById('hinge');
      expect(
        exerciseForSession(
          path: hinge,
          branch: hinge.branchById('barbell')!,
          selectedExerciseId: 'nordic_curls',
          completedSessions: 1,
        ),
        'barbell_deadlift',
      );
    });
  });
}
