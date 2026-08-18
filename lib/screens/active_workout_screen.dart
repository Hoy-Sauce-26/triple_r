import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/countdown.dart';
import '../domain/rep_scheme.dart';
import '../domain/units.dart';
import '../domain/workout_steps.dart';
import '../providers.dart';
import '../state/active_session.dart';
import '../state/timer_providers.dart';
import '../trees/exercises.dart';
import '../trees/tree_types.dart';
import '../widgets/number_entry_dialog.dart';
import 'session_summary_screen.dart';

/// The guided workout: one set at a time, with the rest timer between.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final step = session.currentStep;
    if (step == null) {
      return const _WorkoutDoneView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const _SessionElapsed(),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'skip':
                  await ref
                      .read(activeSessionProvider.notifier)
                      .skipCurrentExercise();
                case 'end':
                  await _confirmEnd(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'skip', child: Text('Skip this exercise')),
              PopupMenuItem(value: 'end', child: Text('End workout early')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _StepView(session: session, step: step),
          const _RestOverlay(),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final logged = ref.read(currentSessionSetsProvider).value?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End workout early?'),
        content: Text(
          logged == 0
              ? 'Nothing has been logged yet.'
              : 'Your $logged logged ${logged == 1 ? 'set' : 'sets'} are kept, '
                  'but this workout will not count toward your rotation and '
                  'will not change any progressions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End workout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(activeSessionProvider.notifier).finish(completed: false);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _SessionElapsed extends ConsumerWidget {
  const _SessionElapsed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionClockProvider);
    final elapsed = ref.read(sessionClockProvider.notifier).elapsed;
    return Text(
      formatDuration(elapsed),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}

class _StepView extends ConsumerWidget {
  const _StepView({required this.session, required this.step});

  final ActiveSession session;
  final WorkoutStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercise = exerciseById(session.exerciseFor(step));
    final scheme = schemeFor(exercise, step.slot);
    final done = session.stepsTotal - session.stepsRemaining;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LinearProgressIndicator(
          value: session.stepsTotal == 0 ? 0 : done / session.stepsTotal,
        ),
        const SizedBox(height: 16),
        Text(
          '${step.blockLabel} · set ${step.setIndex} of 3',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(exercise.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [
            'Target ${scheme.targetLabel}',
            if (exercise.perSide) 'per side',
          ].join(' · '),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _SetLogger(
          key: ValueKey('${step.pathId}-${step.setIndex}'),
          exercise: exercise,
          scheme: scheme,
        ),
        const SizedBox(height: 24),
        _LoggedSets(pathId: step.pathId, exercise: exercise),
      ],
    );
  }
}

/// The number pad for one set.
class _SetLogger extends ConsumerStatefulWidget {
  const _SetLogger({super.key, required this.exercise, required this.scheme});

  final Exercise exercise;
  final RepScheme scheme;

  @override
  ConsumerState<_SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends ConsumerState<_SetLogger> {
  int? _value;
  final _weight = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final previous = ref.watch(previousSetsProvider(widget.exercise.id)).value;

    // Pre-filled from what the user actually managed last time rather than
    // from the target: hitting the ceiling every session is the goal, not the
    // norm, so the previous value is the better one-tap guess.
    final suggested = _value ??
        (previous != null && previous.isNotEmpty
            ? (previous.first.repsCompleted ?? previous.first.holdSeconds)
            : widget.scheme.floor);

    final timed = widget.scheme.isTimed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.remove),
              onPressed: suggested == null || suggested <= 0
                  ? null
                  : () => setState(() => _value = suggested - 1),
            ),
            Expanded(
              child: Text(
                '${suggested ?? 0}${timed ? 's' : ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _value = (suggested ?? 0) + 1),
            ),
          ],
        ),
        if (widget.exercise.loadable) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Added weight (${units.weightSuffix})',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final entered = suggested ?? 0;
            final weight = double.tryParse(_weight.text) ?? 0;
            await ref.read(activeSessionProvider.notifier).logSet(
                  reps: timed ? null : entered,
                  holdSeconds: timed ? entered : null,
                  weightKg: fromDisplayWeight(weight, units),
                );
            if (mounted) setState(() => _value = null);
          },
          child: const Text('Log set'),
        ),
      ],
    );
  }
}

/// Sets already logged for this exercise today, tappable to correct.
class _LoggedSets extends ConsumerWidget {
  const _LoggedSets({required this.pathId, required this.exercise});

  final String pathId;
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(currentSessionSetsProvider).value ?? const [];
    final mine = all.where((s) => s.pathId == pathId).toList()
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));

    if (mine.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This session', style: theme.textTheme.labelLarge),
        for (final record in mine)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Set ${record.setIndex}'),
            trailing: Text(
              record.holdSeconds != null
                  ? '${record.holdSeconds}s'
                  : '${record.repsCompleted}',
              style: theme.textTheme.titleMedium,
            ),
            onTap: () => _edit(context, ref, record),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SetRecord record,
  ) async {
    final timed = record.holdSeconds != null;

    final text = await showDialog<String>(
      context: context,
      builder: (_) => NumberEntryDialog(
        title: 'Set ${record.setIndex}',
        initialText: '${record.holdSeconds ?? record.repsCompleted ?? 0}',
        labelText: timed ? 'Seconds' : 'Reps',
      ),
    );

    final corrected = text == null ? null : int.tryParse(text);
    if (corrected == null) return;
    await ref.read(activeSessionProvider.notifier).editSet(
          pathId: pathId,
          setIndex: record.setIndex,
          reps: timed ? null : corrected,
          holdSeconds: timed ? corrected : null,
          weightKg: record.weightKg,
        );
  }
}

/// The rest countdown, over the top of the next exercise so the user can see
/// what is coming while they wait.
class _RestOverlay extends ConsumerWidget {
  const _RestOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = ref.watch(restTimerProvider);
    if (countdown.isIdle) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final controller = ref.read(restTimerProvider.notifier);
    final remaining = controller.remaining;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(16),
        color: countdown.isFinished
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countdown.isFinished ? 'Rest complete' : 'Resting',
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      formatDuration(remaining),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => controller.extend(const Duration(seconds: 30)),
                child: const Text('+30s'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: controller.skip,
                child: Text(countdown.isFinished ? 'Next' : 'Skip rest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when every step is done — the hand-off into the summary.
class _WorkoutDoneView extends ConsumerWidget {
  const _WorkoutDoneView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const _SessionElapsed()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                'That is the whole workout.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final outcomes = await ref
                      .read(activeSessionProvider.notifier)
                      .evaluateSession();
                  await ref
                      .read(activeSessionProvider.notifier)
                      .finish(completed: true);
                  await navigator.pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => SessionSummaryScreen(outcomes: outcomes),
                    ),
                  );
                },
                child: const Text('Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
