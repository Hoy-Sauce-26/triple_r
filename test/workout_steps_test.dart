import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/domain/session_plan.dart';
import 'package:triple_r/domain/workout_steps.dart';

void main() {
  SessionPlan plan({int completed = 0}) => planSession(
        completedSessions: completed,
        rotatePairOrder: true,
        reachedExerciseIds: const {},
      );

  group('step list', () {
    test('is 18 pair sets plus 9 triplet sets', () {
      final steps = buildSteps(plan());
      expect(steps, hasLength(27));
      expect(steps.where((s) => s.isTriplet), hasLength(9));
    });

    test('alternates A and B within each pair set', () {
      final steps = buildSteps(plan());
      // Rotation 0 opens with Pair 1: pull-up / squat.
      expect(
        steps.take(6).map((s) => '${s.pathId}${s.setIndex}'),
        ['pullup1', 'squat1', 'pullup2', 'squat2', 'pullup3', 'squat3'],
      );
    });

    test('finishes one pair before starting the next', () {
      final steps = buildSteps(plan());
      expect(steps.take(6).every((s) => s.blockLabel == 'Pair 1'), isTrue);
      expect(steps.skip(6).take(6).every((s) => s.blockLabel == 'Pair 2'), isTrue);
    });

    test('runs the triplet as a circuit, not three sets in a row', () {
      final steps = buildSteps(plan()).where((s) => s.isTriplet).toList();
      expect(
        steps.take(3).map((s) => s.pathId),
        ['antiextension', 'antirotation', 'extension'],
      );
      // Round 2 repeats the cycle rather than continuing one exercise.
      expect(steps[3].pathId, 'antiextension');
      expect(steps[3].setIndex, 2);
    });

    test('indices match list positions', () {
      final steps = buildSteps(plan());
      for (var i = 0; i < steps.length; i++) {
        expect(steps[i].index, i);
      }
    });

    test('follows the rotation', () {
      expect(buildSteps(plan(completed: 1)).first.pathId, 'dip');
      expect(buildSteps(plan(completed: 2)).first.pathId, 'row');
    });

    test('every step carries its path slot', () {
      for (final step in buildSteps(plan())) {
        expect(step.isTriplet, step.slot.isTriplet, reason: step.pathId);
      }
    });
  });

  group('cursor traversal', () {
    final steps = buildSteps(planSession(
      completedSessions: 0,
      rotatePairOrder: true,
      reachedExerciseIds: const {},
    ));

    test('walks every step when nothing is skipped', () {
      expect(nextStep(steps, 0, {})!.index, 0);
      expect(nextStep(steps, 5, {})!.index, 5);
      expect(nextStep(steps, steps.length, {}), isNull);
    });

    test('skipping an exercise drops all of its remaining sets', () {
      final next = nextStep(steps, 0, {'pullup'});
      expect(next!.pathId, 'squat', reason: 'pull-up set 1 is skipped over');

      final remaining = remainingSteps(steps, 0, {'pullup'});
      expect(remaining, 24, reason: 'three pull-up sets removed from 27');
    });

    test('skipping the last exercises ends the session', () {
      expect(
        nextStep(steps, 0, {
          'pullup',
          'squat',
          'dip',
          'hinge',
          'row',
          'pushup',
          'antiextension',
          'antirotation',
          'extension',
        }),
        isNull,
      );
    });
  });

  group('cursor serialisation', () {
    test('round-trips through JSON', () {
      const cursor = SessionCursor(
        stepIndex: 7,
        warmupComplete: true,
        skippedPathIds: {'dip', 'row'},
      );

      final restored = SessionCursor.decode(cursor.encode());
      expect(restored.stepIndex, 7);
      expect(restored.warmupComplete, isTrue);
      expect(restored.skippedPathIds, {'dip', 'row'});
    });

    test('a fresh cursor starts at the beginning', () {
      const cursor = SessionCursor();
      expect(cursor.stepIndex, 0);
      expect(cursor.warmupComplete, isFalse);
      expect(cursor.skippedPathIds, isEmpty);
    });

    test('null and empty decode to the start rather than throwing', () {
      expect(SessionCursor.decode(null).stepIndex, 0);
      expect(SessionCursor.decode('').stepIndex, 0);
    });

    test('malformed JSON decodes to the start rather than stranding the user',
        () {
      // A corrupt cursor must lose position, not lock someone out of a
      // workout they cannot open.
      for (final bad in ['{oops', '[]', 'null', '"a string"']) {
        expect(SessionCursor.decode(bad).stepIndex, 0, reason: bad);
      }
    });

    test('missing keys fall back to defaults', () {
      expect(SessionCursor.decode('{"stepIndex":4}').stepIndex, 4);
      expect(SessionCursor.decode('{"stepIndex":4}').warmupComplete, isFalse);
      expect(SessionCursor.decode('{}').skippedPathIds, isEmpty);
    });
  });
}
