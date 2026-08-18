import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/countdown.dart';
import '../providers.dart';
import '../state/active_session.dart';
import '../state/timer_providers.dart';
import '../trees/tree_types.dart';
import '../theme.dart';
import 'active_workout_screen.dart';

/// Which warmup items the user has ticked off this session.
///
/// Session-scoped and never persisted: the warmup has no progression and
/// nothing charts it, so there is nothing worth keeping once the workout is
/// over. See `docs/PLAN.md` §3.
class WarmupChecklist extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  }

  void clear() => state = {};
}

final warmupChecklistProvider =
    NotifierProvider<WarmupChecklist, Set<String>>(WarmupChecklist.new);

/// Marks the warmup done and replaces this screen with the workout.
///
/// `pushReplacement` rather than `push`: backing out of a set should not drop
/// the user into the warmup they already finished.
Future<void> _startWorkout(BuildContext context, WidgetRef ref) async {
  await ref.read(activeSessionProvider.notifier).completeWarmup();
  if (!context.mounted) return;
  await Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const ActiveWorkoutScreen()),
  );
}

class WarmupScreen extends ConsumerWidget {
  const WarmupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(nextSessionPlanProvider);
    final done = ref.watch(warmupChecklistProvider);
    final theme = Theme.of(context);

    if (plan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = plan.warmup;
    final complete = done.length >= items.length;

    // Watched so the elapsed time repaints; the value comes from the
    // controller, which derives it from the clock.
    ref.watch(sessionClockProvider);
    final elapsed = ref.read(sessionClockProvider.notifier).elapsed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warmup'),
        actions: [
          Text(
            formatDuration(elapsed),
            style: theme.textTheme.titleMedium?.tabular,
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${done.length}/${items.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            'Five to ten minutes. Items appear here as your progressions '
            'reach the movements they prepare.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WarmupTile(
                item: item,
                isDone: done.contains(item.id),
                onToggle: () =>
                    ref.read(warmupChecklistProvider.notifier).toggle(item.id),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Never disabled. The warmup is advisory — refusing to let someone
        // start training because they did not tick a box is the app getting
        // in the way of the thing it exists to help with.
        onPressed: () => _startWorkout(context, ref),
        icon: const Icon(Icons.check),
        label: Text(complete ? 'Start workout' : 'Skip to workout'),
      ),
    );
  }
}

class _WarmupTile extends ConsumerWidget {
  const _WarmupTile({
    required this.item,
    required this.isDone,
    required this.onToggle,
  });

  final WarmupItem item;
  final bool isDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isTimed = item.metric == Metric.timed;

    return Card(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
          child: Row(
            children: [
              Checkbox(value: isDone, onChanged: (_) => onToggle()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? theme.colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                    Text(
                      item.target,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isTimed)
                _HoldButton(
                  seconds: item.holdSeconds ?? 30,
                  onComplete: () {
                    if (!isDone) onToggle();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline countdown for a timed warmup hold.
///
/// Only one hold runs at a time — they are done one after another, and two
/// competing chimes would be worse than useless. The shared
/// [holdTimerProvider] enforces that; this widget tracks whether *it* is the
/// one running.
class _HoldButton extends ConsumerStatefulWidget {
  const _HoldButton({required this.seconds, required this.onComplete});

  final int seconds;
  final VoidCallback onComplete;

  @override
  ConsumerState<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends ConsumerState<_HoldButton> {
  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(holdTimerProvider);
    final controller = ref.read(holdTimerProvider.notifier);
    final theme = Theme.of(context);

    if (_mine && timer.isFinished) {
      // Tick the item off once the hold completes, after this frame so the
      // callback does not mutate providers mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mine) return;
        setState(() => _mine = false);
        widget.onComplete();
        controller.cancel();
      });
    }

    final running = _mine && timer.isRunning;
    if (running) {
      return TextButton.icon(
        onPressed: () {
          controller.cancel();
          setState(() => _mine = false);
        },
        icon: const Icon(Icons.stop, size: 18),
        label: Text(
          formatDuration(controller.remaining),
          style: theme.textTheme.titleMedium?.tabular
              .copyWith(color: theme.colorScheme.primary),
        ),
      );
    }

    return IconButton.filledTonal(
      onPressed: () {
        controller.start(Duration(seconds: widget.seconds));
        setState(() => _mine = true);
      },
      icon: const Icon(Icons.timer_outlined),
      tooltip: 'Start ${widget.seconds}s hold',
    );
  }
}
