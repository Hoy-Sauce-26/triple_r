import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/trees/exercises.dart';
import 'package:triple_r/trees/paths.dart';
import 'package:triple_r/trees/tree_types.dart';
import 'package:triple_r/trees/warmup.dart';

/// Structural checks over the hand-entered trees. Nearly 90 exercises were
/// transcribed by hand, and a typo'd id would otherwise surface as a crash on
/// a user's device weeks later — or worse, silently split one exercise's
/// history in two.
void main() {
  group('exercise catalog', () {
    test('every id is unique', () {
      final ids = allExercises.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('ids are lowercase snake_case slugs', () {
      // Ids are permanent and end up in exported JSON, so keep them boring.
      final slug = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');
      for (final e in allExercises) {
        expect(slug.hasMatch(e.id), isTrue, reason: '${e.id} is not a slug');
      }
    });

    test('no display name is duplicated', () {
      // Two exercises sharing a name would be indistinguishable in a dropdown.
      final names = allExercises.map((e) => e.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every catalog exercise is reachable from some path', () {
      final referenced = <String>{
        for (final p in allPaths)
          for (final b in p.branches) ...p.progressionFor(b),
      };
      final orphans =
          allExercises.map((e) => e.id).where((id) => !referenced.contains(id));
      expect(orphans, isEmpty, reason: 'dead catalog entries: $orphans');
    });

    test('load-mode exercises are loadable', () {
      for (final e in allExercises) {
        if (e.mode == ProgressionMode.load) {
          expect(e.loadable, isTrue, reason: '${e.id} progresses by load');
        }
      }
    });
  });

  group('paths', () {
    test('there are nine, one per slot', () {
      expect(allPaths, hasLength(9));
      expect(allPaths.map((p) => p.slot).toSet(), hasLength(9));
    });

    test('path ids are unique', () {
      expect(allPaths.map((p) => p.id).toSet(), hasLength(allPaths.length));
    });

    test('every referenced exercise id exists in the catalog', () {
      for (final p in allPaths) {
        for (final id in p.trunkIds) {
          expect(exercisesById, contains(id), reason: '${p.id} trunk');
        }
        for (final b in p.branches) {
          for (final id in b.exerciseIds) {
            expect(exercisesById, contains(id), reason: '${p.id}/${b.id}');
          }
        }
      }
    });

    test('each path has exactly one default branch', () {
      for (final p in allPaths) {
        final defaults = p.branches.where((b) => b.isDefault);
        expect(defaults, hasLength(1), reason: p.id);
      }
    });

    test('branch ids are unique within a path', () {
      for (final p in allPaths) {
        final ids = p.branches.map((b) => b.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: p.id);
      }
    });

    test('every attachesAtLevel lands on the canonical line', () {
      // A fork above the line's end would silently drop exercises from the
      // prefix, since `take` does not complain about running short.
      for (final p in allPaths) {
        for (final b in p.branches) {
          expect(b.attachesAtLevel, greaterThanOrEqualTo(1), reason: '${p.id}/${b.id}');
          expect(
            b.attachesAtLevel - 1,
            lessThanOrEqualTo(p.canonicalLine.length),
            reason: '${p.id}/${b.id} forks past the end of the canonical line',
          );
        }
      }
    });

    test('the default branch reproduces the canonical line', () {
      for (final p in allPaths) {
        expect(
          p.progressionFor(p.defaultBranch),
          p.canonicalLine,
          reason: p.id,
        );
      }
    });

    test('no progression repeats an exercise', () {
      for (final p in allPaths) {
        for (final b in p.branches) {
          final line = p.progressionFor(b);
          expect(line.toSet(), hasLength(line.length), reason: '${p.id}/${b.id}');
        }
      }
    });

    test('every branch contributes at least one exercise', () {
      for (final p in allPaths) {
        for (final b in p.branches) {
          expect(b.exerciseIds, isNotEmpty, reason: '${p.id}/${b.id}');
        }
      }
    });
  });

  group('default routes', () {
    test('every path lists its default route first', () {
      // The route chooser renders branches in declaration order, so the
      // default has to lead or the chosen one is not the one the eye lands
      // on first. Pinned because it is otherwise easy to break by appending.
      for (final path in allPaths) {
        expect(
          path.branches.first.isDefault,
          isTrue,
          reason: '${path.id} leads with ${path.branches.first.id}, '
              'but defaults to ${path.defaultBranch.id}',
        );
      }
    });

    test('exactly one route per path is the default', () {
      for (final path in allPaths) {
        expect(
          path.branches.where((b) => b.isDefault),
          hasLength(1),
          reason: path.id,
        );
      }
    });

    test('every default route is linear', () {
      // The detail screen records a pre-fork position against the default
      // route, because an alternating route reports its position from its
      // fork point and would silently discard the exercise. That only holds
      // while no path defaults to an alternating route.
      for (final path in allPaths) {
        expect(
          path.defaultBranch.kind,
          BranchKind.linear,
          reason: '${path.id} defaults to an alternating route',
        );
      }
    });

    test('the shared climb always lies on the default route', () {
      // Same reason: the pre-fork rungs are stored against the default route,
      // so its progression has to contain all of them.
      for (final path in allPaths) {
        final onDefault = path.progressionFor(path.defaultBranch);
        for (final branch in path.branches) {
          final shared =
              path.progressionFor(branch).take(branch.attachesAtLevel - 1);
          for (final id in shared) {
            expect(onDefault, contains(id), reason: '${path.id}/${branch.id}');
          }
        }
      }
    });

    test('the trunkless core paths follow the routine\'s own Option A', () {
      // Anti-Rotation and Extension have no shared prefix, so the default
      // route *is* the starting exercise — worth naming explicitly rather
      // than letting declaration order decide it.
      expect(pathById('antirotation').defaultBranch.id, 'weightedpallof');
      expect(pathById('extension').defaultBranch.id, 'reversehyper');
    });
  });

  group('squat step-up and pistol branches', () {
    // The case that forced attachesAtLevel to index the canonical line rather
    // than the trunk: the squat trunk is two exercises, but these fork at 5.
    final squat = pathById('squat');

    test('inherit Split and Bulgarian Split Squats from the default branch', () {
      for (final id in ['stepup', 'pistol']) {
        final line = squat.progressionFor(squat.branchById(id)!);
        expect(
          line.take(4),
          ['assisted_squats', 'full_squats', 'split_squats', 'bulgarian_split_squats'],
          reason: id,
        );
      }
    });

    test('the barbell branch forks below them and stays short', () {
      final line = squat.progressionFor(squat.branchById('barbell')!);
      expect(line, ['assisted_squats', 'full_squats', 'barbell_back_squats']);
    });
  });

  group('alternating hinge branch', () {
    final barbell = pathById('hinge').branchById('barbell')!;

    test('is the only alternating branch in the app', () {
      final alternating = [
        for (final p in allPaths)
          for (final b in p.branches)
            if (b.kind == BranchKind.alternating) '${p.id}/${b.id}',
      ];
      expect(alternating, ['hinge/barbell']);
    });

    test('runs RDL on days 1 and 3, deadlift on day 2, weekly', () {
      final week = [for (var i = 0; i < 6; i++) barbell.exerciseForSession(i)];
      expect(week, [
        'barbell_romanian_deadlift',
        'barbell_deadlift',
        'barbell_romanian_deadlift',
        'barbell_romanian_deadlift',
        'barbell_deadlift',
        'barbell_romanian_deadlift',
      ]);
    });

    test('both exercises progress by load', () {
      for (final id in barbell.exerciseIds) {
        expect(exerciseById(id).mode, ProgressionMode.load);
      }
    });

    test('linear branches reject exerciseForSession', () {
      final bodyweight = pathById('hinge').branchById('bodyweight')!;
      expect(() => bodyweight.exerciseForSession(0), throwsStateError);
    });
  });

  group('shared handstand push-up chain', () {
    test('dip and push-up reference identical exercise ids', () {
      final dip = pathById('dip').branchById('hspu')!.exerciseIds;
      final pushup = pathById('pushup').branchById('hspu')!.exerciseIds;
      expect(dip, pushup);
      expect(dip, isNotEmpty);
    });
  });

  group('warmup', () {
    test('item ids are unique', () {
      final ids = warmupItems.map((w) => w.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every unlock trigger is a real exercise', () {
      for (final item in warmupItems) {
        final trigger = item.unlockedBy;
        if (trigger != null) {
          expect(exercisesById, contains(trigger), reason: item.id);
        }
      }
    });

    test('four items are always shown and four are gated', () {
      final gated = warmupItems.where((w) => w.unlockedBy != null);
      expect(gated, hasLength(4));
      expect(warmupItems, hasLength(8));
    });

    test('timed items declare a hold length', () {
      for (final item in warmupItems) {
        if (item.metric == Metric.timed) {
          expect(item.holdSeconds, isNotNull, reason: item.id);
        }
      }
    });
  });
}
