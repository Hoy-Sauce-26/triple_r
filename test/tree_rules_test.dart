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

  group('routes are never gated on level', () {
    final squat = pathById('squat');

    // Gating was removed outright. Someone installing the app who can already
    // do pistol squats has to be able to say so on day one; making them walk
    // the current-exercise list upward first to unlock the route is a puzzle,
    // not a safeguard.
    test('a route forking above the user is still selectable', () {
      final positions = freshPositions();
      expect(
        handstandConflict(squat, squat.branchById('pistol')!, positions),
        isNull,
      );
      expect(
        handstandConflict(squat, squat.branchById('barbell')!, positions),
        isNull,
      );
    });

    test('switching to it lands on its own first exercise', () {
      final next = positionAfterSwitch(squat, squat.branchById('pistol')!);
      expect(next.exerciseId, 'partial_pistol_squats');
    });
  });

  group('handstand mutual exclusion', () {
    final dip = pathById('dip');
    final pushup = pathById('pushup');

    test('no conflict when neither slot uses it', () {
      final positions = withPositions({
        'dip': const PathPosition(branchId: 'weighted', exerciseId: 'weighted_dips'),
        'pushup': const PathPosition(
          branchId: 'pseudoplanche',
          exerciseId: 'pseudo_planche_pushups',
        ),
      });
      expect(handstandConflict(dip, dip.branchById('hspu')!, positions), isNull);
      expect(
        handstandConflict(pushup, pushup.branchById('hspu')!, positions),
        isNull,
      );
    });

    test('names the other path when it already holds the chain', () {
      final positions = withPositions({
        'dip': const PathPosition(branchId: 'hspu', exerciseId: 'pike_pushups'),
        'pushup': const PathPosition(
          branchId: 'pseudoplanche',
          exerciseId: 'pseudo_planche_pushups',
        ),
      });
      // Reported so the caller can offer to move the other path — not so it
      // can refuse this one.
      expect(
        handstandConflict(pushup, pushup.branchById('hspu')!, positions),
        'dip',
      );
      // The slot already using it is not in conflict with itself.
      expect(handstandConflict(dip, dip.branchById('hspu')!, positions), isNull);
    });

    test('the rule is symmetric', () {
      final positions = withPositions({
        'pushup': const PathPosition(branchId: 'hspu', exerciseId: 'pike_pushups'),
        'dip': const PathPosition(branchId: 'weighted', exerciseId: 'weighted_dips'),
      });
      expect(handstandConflict(dip, dip.branchById('hspu')!, positions), 'pushup');
    });

    test('never fires for any other route', () {
      final positions = withPositions({
        'dip': const PathPosition(branchId: 'hspu', exerciseId: 'pike_pushups'),
      });
      expect(
        handstandConflict(pushup, pushup.branchById('rings')!, positions),
        isNull,
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
