import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import '../trees/tree_rules.dart';
import '../trees/tree_types.dart' as trees;

/// Lists all nine paths and lets the user pick a branch and their current
/// exercise within it.
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
            for (final group in _groups)
              ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    group.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                for (final pathId in group.pathIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PathCard(
                      path: pathById(pathId),
                      positions: map,
                      completedSessions: sessions.value ?? 0,
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

class _PathCard extends ConsumerWidget {
  const _PathCard({
    required this.path,
    required this.positions,
    required this.completedSessions,
  });

  final trees.Path path;
  final Map<String, PathPosition> positions;
  final int completedSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final position = positions[path.id]!;
    final branch = path.branchById(position.branchId) ?? path.defaultBranch;
    final alternating = branch.kind == trees.BranchKind.alternating;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(path.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              _currentLabel(branch, position),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (alternating)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Next session: '
                  '${exerciseById(branch.exerciseForSession(completedSessions)).name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _BranchDropdown(
                    path: path,
                    current: branch,
                    positions: positions,
                  ),
                ),
                const SizedBox(width: 8),
                if (!alternating)
                  Expanded(
                    child: _ExerciseDropdown(
                      path: path,
                      branch: branch,
                      position: position,
                    ),
                  ),
              ],
            ),
          ],
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

class _BranchDropdown extends ConsumerWidget {
  const _BranchDropdown({
    required this.path,
    required this.current,
    required this.positions,
  });

  final trees.Path path;
  final trees.Branch current;
  final Map<String, PathPosition> positions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<String>(
      initialValue: current.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Branch',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final branch in path.branches)
          DropdownMenuItem(
            value: branch.id,
            enabled: branchLock(path, branch, positions) == null,
            child: _BranchLabel(
              branch: branch,
              lock: branchLock(path, branch, positions),
            ),
          ),
      ],
      onChanged: (branchId) {
        if (branchId == null || branchId == current.id) return;
        final branch = path.branchById(branchId)!;
        // A locked branch still fires onChanged on some platforms, so the
        // rule is re-checked here rather than trusted to the disabled item.
        if (branchLock(path, branch, positions) != null) return;
        final next = positionAfterSwitch(path, branch);
        ref.read(databaseProvider).saveProgressionConfig(
              pathId: path.id,
              branchId: next.branchId,
              exerciseId: next.exerciseId,
            );
      },
    );
  }
}

class _BranchLabel extends StatelessWidget {
  const _BranchLabel({required this.branch, required this.lock});

  final trees.Branch branch;
  final BranchLockReason? lock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (lock == null) {
      return Text(branch.name, overflow: TextOverflow.ellipsis);
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            branch.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.disabledColor),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          lock == BranchLockReason.takenByOtherSlot
              ? Icons.swap_horiz
              : Icons.lock_outline,
          size: 14,
          color: theme.disabledColor,
        ),
      ],
    );
  }
}

class _ExerciseDropdown extends ConsumerWidget {
  const _ExerciseDropdown({
    required this.path,
    required this.branch,
    required this.position,
  });

  final trees.Path path;
  final trees.Branch branch;
  final PathPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = path.progressionFor(branch);
    return DropdownButtonFormField<String>(
      initialValue: position.exerciseId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Current',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final id in progression)
          DropdownMenuItem(
            value: id,
            child: Text(exerciseById(id).name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (exerciseId) {
        if (exerciseId == null || exerciseId == position.exerciseId) return;
        ref.read(databaseProvider).saveProgressionConfig(
              pathId: path.id,
              branchId: branch.id,
              exerciseId: exerciseId,
            );
      },
    );
  }
}
