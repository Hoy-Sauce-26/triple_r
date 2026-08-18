import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import '../trees/tree_rules.dart';
import '../trees/tree_types.dart' as trees;
import '../theme.dart';
import 'path_detail_screen.dart';

/// Where the user stands on all nine paths, one line each.
///
/// A status list rather than nine editors. The previous screen put a pair of
/// coupled dropdowns on every card, which made the tab a wall of controls and
/// still could not show a progression's shape — see [PathDetailScreen], which
/// owns the editing and the ladder.
class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(pathPositionsProvider);
    final sessions = ref.watch(completedSessionCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progression')),
      body: positions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load progressions.\n$e')),
        data: (map) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final group in _groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final pathId in group.pathIds)
                      _PathRow(
                        path: pathById(pathId),
                        positions: map,
                        completedSessions: sessions.value ?? 0,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Group {
  const _Group(this.label, this.pathIds);
  final String label;
  final List<String> pathIds;
}

const _groups = [
  _Group('Pair 1 — vertical pull & quads', ['pullup', 'squat']),
  _Group('Pair 2 — vertical push & hinge', ['dip', 'hinge']),
  _Group('Pair 3 — horizontal pull & push', ['row', 'pushup']),
  _Group('Core triplet', ['antiextension', 'antirotation', 'extension']),
];

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.path,
    required this.positions,
    required this.completedSessions,
  });

  final trees.Path path;
  final Map<String, PathPosition> positions;
  final int completedSessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = positions[path.id]!;
    final branch = path.branchById(position.branchId) ?? path.defaultBranch;
    final alternating = branch.kind == trees.BranchKind.alternating;

    return ListTile(
      title: Text(path.name, style: theme.textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentLabel(branch, position),
            style: theme.textTheme.bodyMedium,
          ),
          if (alternating)
            Text(
              'Next session: '
              '${exerciseById(branch.exerciseForSession(completedSessions)).name}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alternating)
            Text(
              // Position on the route the user is actually climbing, not on
              // the path as a whole — a rung count is only meaningful within
              // one route.
              '${levelFor(path, position)}/${path.progressionFor(branch).length}',
              style: theme.textTheme.labelMedium?.tabular.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PathDetailScreen(pathId: path.id),
        ),
      ),
    );
  }

  String _currentLabel(trees.Branch branch, PathPosition position) {
    if (branch.kind == trees.BranchKind.alternating) {
      return branch.exerciseIds.map((id) => exerciseById(id).name).join(' / ');
    }
    final id = position.exerciseId;
    return id == null ? '—' : exerciseById(id).name;
  }
}
