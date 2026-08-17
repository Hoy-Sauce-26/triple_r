import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/trees/paths.dart';
import 'package:triple_r/trees/tree_rules.dart';

/// Branch gating and level arithmetic — the logic the config screen leans on
/// to decide what a user is allowed to pick.
void main() {
  /// Every path at its starting position, as a fresh install would be.
  Map<String, PathPosition> freshPositions() => {
        for (final p in allPaths) p.id: initialPosition(p),
      };

  /// Fresh positions with [overrides] applied. Takes a map so several paths
  /// can be moved at once — composing two single-path helpers by spreading
  /// silently reverts the first, since each returns all nine paths.
  Map<String, PathPosition> withPositions(
    Map<String, PathPosition> overrides,
  ) {
    return {...freshPositions(), ...overrides};
  }

  Map<String, PathPosition> withPosition(
    String pathId,
    String branchId,
    String? exerciseId,
  ) {
    return withPositions({
      pathId: PathPosition(branchId: branchId, exerciseId: exerciseId),
    });
  }

  group('initial position', () {
    test('starts every path on its default branch at the first exercise', () {
      for (final path in allPaths) {
        final start = initialPosition(path);
        expect(start.branchId, path.defaultBranch.id, reason: path.id);
        expect(
          start.exerciseId,
          path.canonicalLine.first,
          reason: path.id,
        );
      }
    });
  });

  group('levelFor', () {
    final squat = pathById('squat');

    test('counts along the branch progression', () {
      final bodyweight = squat.branchById('bodyweight')!;
      expect(
        levelFor(squat, PathPosition(branchId: 'bodyweight', exerciseId: 'assisted_squats')),
        1,
      );
      expect(
        levelFor(squat, PathPosition(branchId: 'bodyweight', exerciseId: 'bulgarian_split_squats')),
        4,
      );
      expect(squat.levelOf(bodyweight, 'weighted_shrimp_squats'), 8);
    });

    test('reports the fork point for alternating branches', () {
      final hinge = pathById('hinge');
      // Both exercises are current at once, so there is no single position.
      expect(
        levelFor(hinge, const PathPosition(branchId: 'barbell', exerciseId: null)),
        2,
      );
    });
  });

  group('branch gating', () {
    final squat = pathById('squat');

    test('step-up and pistol are locked at the start of the squat path', () {
      final positions = freshPositions();
      for (final id in ['stepup', 'pistol']) {
        expect(
          branchLock(squat, squat.branchById(id)!, positions),
          BranchLockReason.notYetReached,
          reason: id,
        );
      }
    });

    test('they unlock once the user reaches Bulgarian Split Squats', () {
      final positions =
          withPosition('squat', 'bodyweight', 'bulgarian_split_squats');
      for (final id in ['stepup', 'pistol']) {
        expect(branchLock(squat, squat.branchById(id)!, positions), isNull,
            reason: id);
      }
    });

    test('the default branch is never locked, even below its own fork', () {
      // Squat's default branch forks at 3, but a beginner sits at level 1 on
      // it. Locking it would disable the dropdown's own current value.
      final positions = freshPositions();
      expect(branchLock(squat, squat.branchById('bodyweight')!, positions), isNull);
    });

    test('a non-default branch still waits for its fork level', () {
      final positions = freshPositions();
      expect(
        branchLock(squat, squat.branchById('barbell')!, positions),
        BranchLockReason.notYetReached,
      );

      final afterFullSquats = withPosition('squat', 'bodyweight', 'full_squats');
      expect(
        branchLock(squat, squat.branchById('barbell')!, afterFullSquats),
        isNull,
      );
    });

    test('the branch the user is on stays selectable', () {
      // Reachable only by having travelled there, so it must not re-lock.
      final positions = withPosition('squat', 'pistol', 'pistol_squats');
      expect(branchLock(squat, squat.branchById('pistol')!, positions), isNull);
    });
  });

  group('handstand push-up mutual exclusion', () {
    final dip = pathById('dip');
    final pushup = pathById('pushup');

    test('is available on both slots when neither uses it', () {
      // Both paths high enough that only the cross-path rule could lock it.
      final positions = withPositions({
        'dip': const PathPosition(branchId: 'weighted', exerciseId: 'weighted_dips'),
        'pushup': const PathPosition(
          branchId: 'pseudoplanche',
          exerciseId: 'pseudo_planche_pushups',
        ),
      });
      expect(branchLock(dip, dip.branchById('hspu')!, positions), isNull);
      expect(branchLock(pushup, pushup.branchById('hspu')!, positions), isNull);
    });

    test('selecting it for dips locks it for push-ups', () {
      final positions = withPositions({
        'dip': const PathPosition(branchId: 'hspu', exerciseId: 'pike_pushups'),
        'pushup': const PathPosition(
          branchId: 'pseudoplanche',
          exerciseId: 'pseudo_planche_pushups',
        ),
      });
      expect(
        branchLock(pushup, pushup.branchById('hspu')!, positions),
        BranchLockReason.takenByOtherSlot,
      );
      // Still selectable on the slot already using it, so the dropdown can
      // show it as the current value.
      expect(branchLock(dip, dip.branchById('hspu')!, positions), isNull);
    });

    test('the rule is symmetric', () {
      final positions = withPositions({
        'pushup': const PathPosition(branchId: 'hspu', exerciseId: 'pike_pushups'),
        'dip': const PathPosition(branchId: 'weighted', exerciseId: 'weighted_dips'),
      });
      expect(
        branchLock(dip, dip.branchById('hspu')!, positions),
        BranchLockReason.takenByOtherSlot,
      );
    });
  });

  group('positionAfterSwitch', () {
    test('lands on the new branch, not back at the start of the path', () {
      final squat = pathById('squat');
      final next = positionAfterSwitch(squat, squat.branchById('pistol')!);
      expect(next.branchId, 'pistol');
      expect(next.exerciseId, 'partial_pistol_squats');
    });

    test('leaves the exercise unset for alternating branches', () {
      final hinge = pathById('hinge');
      final next = positionAfterSwitch(hinge, hinge.branchById('barbell')!);
      expect(next.exerciseId, isNull);
    });
  });

  group('reachedExercises', () {
    test('includes everything at or below the current level', () {
      final positions =
          withPosition('pushup', 'pseudoplanche', 'full_pushups');
      final reached = reachedExercises(positions);
      expect(reached, contains('wall_pushups'));
      expect(reached, contains('full_pushups'));
      expect(reached, isNot(contains('diamond_pushups')));
    });

    test('drives the gated warmup items', () {
      // Arch Hangs appear in the warmup once Pull-up Eccentrics is reached.
      final before = reachedExercises(freshPositions());
      expect(before, isNot(contains('pullup_eccentrics')));

      final after = reachedExercises(
        withPosition('pullup', 'weighted', 'pullup_eccentrics'),
      );
      expect(after, contains('pullup_eccentrics'));
    });
  });
}
