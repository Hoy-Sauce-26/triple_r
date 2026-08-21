import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/analytics.dart';
import '../domain/countdown.dart';
import '../domain/units.dart';
import '../providers.dart';
import '../trees/exercises.dart';
import '../widgets/log_weight_dialog.dart';
import '../widgets/trend_chart.dart';
import 'session_detail_screen.dart';

/// Past work, in two views: what was done, and how it has trended.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Sessions'), Tab(text: 'Progress')],
          ),
        ),
        body: const TabBarView(
          children: [_SessionsTab(), _ProgressTab()],
        ),
      ),
    );
  }
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionHistoryProvider);

    return sessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load history.\n$e')),
      data: (rows) {
        if (rows.isEmpty) {
          return const _Empty(
            icon: Icons.fitness_center_outlined,
            message: 'No workouts yet.\nYour first session will show up here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: rows.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SessionCard(session: rows[i]),
          ),
        );
      },
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sets = ref.watch(sessionSetsProvider(session.id)).value ?? const [];
    final summary = summarise(session, sets);
    final started = session.startedAt;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionDetailScreen(sessionId: session.id),
          ),
        ),
        title: Text(
          '${started.day}/${started.month}/${started.year}',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          [
            '${summary.setCount} sets',
            '${summary.exerciseCount} exercises',
            if (summary.duration case final d?) formatDuration(d),
          ].join(' · '),
        ),
        trailing: summary.wasAbandoned
            ? Chip(
                label: const Text('Ended early'),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ProgressTab extends ConsumerStatefulWidget {
  const _ProgressTab();

  @override
  ConsumerState<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<_ProgressTab> {
  String? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final weights = ref.watch(bodyWeightsProvider).value ?? const [];
    final logged = ref.watch(loggedExerciseIdsProvider).value ?? const [];
    final events = ref.watch(progressionEventsProvider).value ?? const [];

    // Defaults to the most recently trained exercise, so the chart is useful
    // before the user touches the picker.
    final selected = _exerciseId ?? (logged.isEmpty ? null : logged.first);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (selected == null)
          const _CardSection(
            title: 'Strength',
            child: SizedBox(
              height: 120,
              child: Center(child: Text('Log a workout to see progress here.')),
            ),
          )
        else
          _ExerciseProgressCard(
            exerciseId: selected,
            options: logged,
            onChanged: (id) => setState(() => _exerciseId = id),
          ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CardSection(
            title: 'Progressions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charts reset when you move up, so advancements are listed '
                  'rather than drawn.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                for (final event in events.take(12))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.trending_up,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Two lines rather than one. Exercise names are long
                        // — "Bulgarian Split Squat — from Split Squat" ran
                        // into the date and ellipsed away the half that says
                        // what changed.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name(event.toExerciseId),
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                'from ${_name(event.fromExerciseId)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${event.date.day}/${event.date.month}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        // Last, under the training charts. Body weight is context for the
        // workout data rather than the point of the screen, and it was
        // pushing the strength chart — the thing actually being tracked —
        // below the fold.
        const SizedBox(height: 12),
        _CardSection(
          title: 'Body weight',
          action: TextButton.icon(
            onPressed: () => LogWeightDialog.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log'),
          ),
          child: TrendChart(
            axisLabel: 'Body weight (${units.weightSuffix})',
            points: [
              for (final e in weights)
                TrendPoint(
                  date: e.recordedAt,
                  value: toDisplayWeight(e.weightKg, units),
                ),
            ],
            formatValue: (v) =>
                '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}'
                ' ${units.weightSuffix}',
          ),
        ),
      ],
    );
  }

  String _name(String exerciseId) =>
      exercisesById[exerciseId]?.name ?? exerciseId;
}

class _ExerciseProgressCard extends ConsumerWidget {
  const _ExerciseProgressCard({
    required this.exerciseId,
    required this.options,
    required this.onChanged,
  });

  final String exerciseId;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitSystemProvider);
    final series = ref.watch(exerciseSeriesProvider(exerciseId)).value;

    return _CardSection(
      title: 'Strength',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: options.contains(exerciseId) ? exerciseId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final id in options)
                DropdownMenuItem(
                  value: id,
                  child: Text(
                    exercisesById[id]?.name ?? id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) onChanged(id);
            },
          ),
          const SizedBox(height: 8),
          if (series != null)
            // The axis label is handed to the chart rather than printed above
            // it: over the card it read as a second heading, and left the
            // numbers down the side of the plot unexplained.
            TrendChart(
              axisLabel: series.axisLabel,
              points: [
                for (final p in series.points)
                  TrendPoint(
                    date: p.date,
                    value: series.kind == SeriesKind.weightKg
                        ? toDisplayWeight(p.value, units)
                        : p.value,
                  ),
              ],
              formatValue: (v) => series.kind == SeriesKind.weightKg
                  ? '${v.round()} ${units.weightSuffix}'
                  : v.round().toString(),
            ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
