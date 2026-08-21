import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/analytics.dart';
import '../domain/countdown.dart';
import '../domain/units.dart';
import '../providers.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import '../trees/tree_types.dart';
import '../widgets/edit_set_dialog.dart';

/// Everything logged in one past session, grouped by exercise.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final sessions = ref.watch(sessionHistoryProvider).value ?? const [];
    final sets = ref.watch(sessionSetsProvider(sessionId)).value;

    final session = sessions.where((s) => s.id == sessionId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      // Inset at the bottom: the list ran under the Android navigation bar,
      // so the last card was permanently half-covered.
      body: SafeArea(
        top: false,
        child: sets == null || session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Header(session: session, sets: sets),
                const SizedBox(height: 12),
                for (final group in _groupByExercise(sets))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ExerciseGroupCard(group: group, units: units),
                  ),
                if (sets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No sets were logged in this session.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.sets});

  final WorkoutSession session;
  final List<SetRecord> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = summarise(session, sets);
    final started = session.startedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${started.day}/${started.month}/${started.year}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              [
                'Workout ${session.rotationIndex + 1} of 3',
                if (summary.duration case final d?) formatDuration(d),
                '${summary.setCount} sets',
              ].join(' · '),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (summary.wasAbandoned) ...[
              const SizedBox(height: 8),
              Text(
                'Ended early — the sets below were still counted.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseGroup {
  const _ExerciseGroup._(this.exerciseId, this.pathId, this.sets);

  final String exerciseId;
  final String pathId;
  final List<SetRecord> sets;
}

List<_ExerciseGroup> _groupByExercise(List<SetRecord> sets) {
  // Insertion-ordered so the list reads in the order the workout was done,
  // which is how the user remembers it.
  final groups = <String, List<SetRecord>>{};
  final paths = <String, String>{};
  for (final set in sets) {
    groups.putIfAbsent(set.exerciseId, () => []).add(set);
    paths[set.exerciseId] = set.pathId;
  }
  return [
    for (final entry in groups.entries)
      _ExerciseGroup._(
        entry.key,
        paths[entry.key]!,
        entry.value..sort((a, b) => a.setIndex.compareTo(b.setIndex)),
      ),
  ];
}

class _ExerciseGroupCard extends ConsumerWidget {
  const _ExerciseGroupCard({required this.group, required this.units});

  final _ExerciseGroup group;
  final UnitSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercise = exercisesById[group.exerciseId];
    final perSide = exercise?.perSide ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise?.name ?? group.exerciseId,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              pathsById[group.pathId]?.name ?? group.pathId,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final set in group.sets)
                  // Tappable: a set mistyped during a workout used to be
                  // frozen the moment the session ended, and it still feeds
                  // the charts and the personal bests.
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_label(set, perSide)),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    onPressed: () => _edit(context, ref, set, exercise),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SetRecord set,
    Exercise? exercise,
  ) async {
    final timed = set.holdSeconds != null;
    final result = await showDialog<EditSetResult>(
      context: context,
      builder: (_) => EditSetDialog(
        title: '${exercise?.name ?? set.exerciseId} · set ${set.setIndex}',
        initialValue: set.holdSeconds ?? set.repsCompleted ?? 0,
        timed: timed,
        units: units,
        initialWeightKg: (exercise?.loadable ?? false) ? set.weightKg : null,
      ),
    );
    if (result == null) return;

    // Written straight to the row. Editing history deliberately does not
    // re-run the progression rules — those already fired at the end of that
    // session and the user acted on them, so silently re-deciding an
    // advancement weeks later would be worse than a slightly stale call.
    await ref.read(databaseProvider).updateSetValues(
          set.id,
          reps: timed ? null : result.value,
          holdSeconds: timed ? result.value : null,
          weightKg: result.weightKg,
        );
  }

  String _label(SetRecord set, bool perSide) {
    final value = set.holdSeconds != null
        ? '${set.holdSeconds}s'
        : '${set.repsCompleted}${perSide ? '/side' : ''}';
    if (set.weightKg case final weight?) {
      return '$value @ ${formatWeight(weight, units)}';
    }
    return value;
  }
}
