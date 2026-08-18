import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import '../trees/tree_rules.dart';
import '../trees/tree_types.dart' as trees;

/// One path, drawn as the ladder it actually is.
///
/// The old screen collapsed a progression into two coupled dropdowns, which
/// hid the only thing that makes it a progression: where the user is, what is
/// behind them, and what is next. Worse, it explained a locked route with a
/// padlock — an assertion whose reason (a level comparison) lived in the very
/// structure the dropdowns were hiding.
///
/// Here the rungs are laid out in order and the fork is drawn *at its own
/// level*, so "not yet reached" stops needing an explanation: the route
/// visibly starts above where the user is standing.
class PathDetailScreen extends ConsumerWidget {
  const PathDetailScreen({super.key, required this.pathId});

  final String pathId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(pathPositionsProvider).value;
    final path = pathById(pathId);

    if (positions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final position = positions[pathId]!;
    final branch = path.branchById(position.branchId) ?? path.defaultBranch;
    final alternating = branch.kind == trees.BranchKind.alternating;
    final progression = path.progressionFor(branch);
    final level = levelFor(path, position);
    final forkAt = branch.attachesAtLevel;

    // Levels 1..forkAt-1 are common to every route on this path. Empty for
    // the two core paths that have no trunk — they are a straight choice of
    // variation, not a climb, and the layout says so by opening on the fork.
    final shared = progression.take(forkAt - 1).toList();
    final onBranch = progression.skip(forkAt - 1).toList();

    // Standing below the fork means no route has been taken yet. Showing one
    // as chosen — and listing its exercises underneath — claims a decision
    // the user has not made: someone on Full Pull-ups has not picked the
    // weighted route, they simply have the default sitting in their config
    // row. Until they climb past the fork, the routes are all just options.
    final onRoute = level >= forkAt;

    return Scaffold(
      appBar: AppBar(title: Text(path.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final (index, id) in shared.indexed)
            _Rung(
              level: index + 1,
              exerciseId: id,
              currentLevel: level,
              onTap: () => _selectShared(ref, path, id),
            ),
          _RouteChooser(
            path: path,
            current: onRoute ? branch : null,
            positions: positions,
            hasSharedPrefix: shared.isNotEmpty,
          ),
          if (onRoute)
            if (alternating)
              _AlternatingBlock(branch: branch)
            else
              for (final (index, id) in onBranch.indexed)
                _Rung(
                  level: forkAt + index,
                  exerciseId: id,
                  currentLevel: level,
                  onTap: () => _select(ref, path, branch, id),
                ),
        ],
      ),
    );
  }

  void _select(
    WidgetRef ref,
    trees.Path path,
    trees.Branch branch,
    String exerciseId,
  ) {
    // Any rung is selectable, including ones above the current position. A
    // beginner who can already do pull-ups must be able to say so — see the
    // first-run card on the dashboard.
    ref.read(databaseProvider).saveProgressionConfig(
          pathId: path.id,
          branchId: branch.id,
          exerciseId: exerciseId,
        );
  }

  /// Picking a rung from the shared climb, which belongs to no route.
  ///
  /// Stored against the default route rather than whichever one is currently
  /// configured. Keeping the old route made this a no-op on the alternating
  /// barbell hinge: `levelFor` reads an alternating branch's position from its
  /// fork point and ignores the stored exercise, so choosing Romanian
  /// Deadlifts while on that route saved a value nothing would ever read, and
  /// the workout kept programming the barbell rotation.
  ///
  /// The default route is always linear and its progression always contains
  /// the whole shared climb, so it is the one place a pre-fork position can be
  /// recorded and read back faithfully.
  void _selectShared(WidgetRef ref, trees.Path path, String exerciseId) {
    ref.read(databaseProvider).saveProgressionConfig(
          pathId: path.id,
          branchId: path.defaultBranch.id,
          exerciseId: exerciseId,
        );
  }
}

/// One step on the ladder.
class _Rung extends StatelessWidget {
  const _Rung({
    required this.level,
    required this.exerciseId,
    required this.currentLevel,
    required this.onTap,
  });

  final int level;
  final String exerciseId;
  final int currentLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = exerciseById(exerciseId);
    final isCurrent = level == currentLevel;
    final isCleared = level < currentLevel;

    final colour = isCurrent
        ? theme.colorScheme.primary
        : isCleared
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 32,
        child: isCleared
            ? Icon(Icons.check, size: 18, color: colour)
            : Text(
                '$level',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(color: colour),
              ),
      ),
      title: Text(
        exercise.name,
        style: (isCurrent
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyLarge)
            ?.copyWith(color: colour),
      ),
      subtitle: _detail(exercise) == null ? null : Text(_detail(exercise)!),
      trailing: isCurrent
          ? Text(
              'You are here',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            )
          : null,
      onTap: onTap,
    );
  }

  /// Only the things that change how a set is logged. Anything else here is
  /// noise on a screen whose job is orientation.
  String? _detail(trees.Exercise exercise) {
    final bits = [
      if (exercise.metric == trees.Metric.timed) 'timed hold',
      if (exercise.perSide) 'per side',
      if (exercise.mode == trees.ProgressionMode.load) 'progresses by load',
    ];
    return bits.isEmpty ? null : bits.join(' · ');
  }
}

/// The fork, drawn where it happens.
class _RouteChooser extends ConsumerWidget {
  const _RouteChooser({
    required this.path,
    required this.current,
    required this.positions,
    required this.hasSharedPrefix,
  });

  final trees.Path path;

  /// Null while the user is still below the fork — nothing is chosen yet.
  final trees.Branch? current;

  final Map<String, PathPosition> positions;
  final bool hasSharedPrefix;

  /// Routes the source plan marks "(Recommended)". Presentation only — the
  /// trees stay a faithful description of the routine, not an opinion about
  /// it.
  static const _recommended = {'squat': 'barbell', 'hinge': 'barbell'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasSharedPrefix ? 'From here, pick a route' : 'Pick a variation',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final branch in path.branches)
                _RouteChip(
                  path: path,
                  branch: branch,
                  isSelected: branch.id == current?.id,
                  positions: positions,
                  isRecommended: _recommended[path.id] == branch.id,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends ConsumerWidget {
  const _RouteChip({
    required this.path,
    required this.branch,
    required this.isSelected,
    required this.positions,
    required this.isRecommended,
  });

  final trees.Path path;
  final trees.Branch branch;
  final bool isSelected;
  final Map<String, PathPosition> positions;
  final bool isRecommended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Where the route joins the path, stated as a fact about the route rather
    // than a condition on the user. Someone who already trains pistols picks
    // the pistol route on day one; the "starts at 5" simply tells them the
    // four rungs above it are being skipped, which is their call to make.
    //
    // The default route is annotated too. It forks at exactly the same place
    // as its siblings, and exempting it made the one route the user was most
    // likely to take the one that explained itself least.
    final note = [
      if (branch.attachesAtLevel > 1) 'starts at ${branch.attachesAtLevel}',
      if (isRecommended) 'recommended',
    ].join(' · ');

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => isSelected ? null : _choose(context, ref),
      // A Row, not a Column: chip labels are laid out for a single line, and
      // stacking text inside one fights the chip's own vertical metrics.
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(branch.name),
          if (note.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              note,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final conflictId = handstandConflict(path, branch, positions);
    if (conflictId != null && !await _confirmMove(context, conflictId)) return;

    final db = ref.read(databaseProvider);
    if (conflictId != null) {
      // The other slot gives the movement up rather than this one being
      // refused — and it lands on its own default route, not back at rung 1.
      final other = pathById(conflictId);
      final moved = positionAfterSwitch(other, other.defaultBranch);
      await db.saveProgressionConfig(
        pathId: other.id,
        branchId: moved.branchId,
        exerciseId: moved.exerciseId,
      );
    }

    final next = positionAfterSwitch(path, branch);
    await db.saveProgressionConfig(
      pathId: path.id,
      branchId: next.branchId,
      exerciseId: next.exerciseId,
    );
  }

  /// Asked rather than done silently: this edits a path the user is not
  /// looking at.
  Future<bool> _confirmMove(BuildContext context, String conflictId) async {
    final other = pathById(conflictId);
    final moved = positionAfterSwitch(other, other.defaultBranch);
    final landing = exerciseById(moved.exerciseId!).name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move ${other.name} off handstands?'),
        content: Text(
          'Handstand work is already filling the ${other.name} slot, and the '
          'same movement cannot be programmed twice in one workout.\n\n'
          '${other.name} would move to $landing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Move ${other.name}'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// The barbell hinge, which runs two lifts in rotation rather than a ladder.
class _AlternatingBlock extends StatelessWidget {
  const _AlternatingBlock({required this.branch});

  final trees.Branch branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alternates every session', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final id in branch.exerciseIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(exerciseById(id).name,
                    style: theme.textTheme.bodyLarge),
              ),
            const SizedBox(height: 4),
            Text(
              'Both are current — there is no single rung to stand on, so the '
              'workout picks whichever is next in the rotation.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
