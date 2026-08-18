import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../state/active_session.dart';
import '../state/timer_providers.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import 'active_workout_screen.dart';
import 'warmup_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(nextSessionPlanProvider);
    final exercises = ref.watch(nextSessionExercisesProvider);
    final active = ref.watch(activeSessionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Triple R')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (active != null) ...[
            _ResumeBanner(startedAt: active.startedAt),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next session', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  if (plan == null)
                    Text('Loading…', style: theme.textTheme.headlineSmall)
                  else ...[
                    Text(
                      'Workout ${plan.rotationIndex + 1} of 3',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    for (final (index, pair) in plan.pairs.indexed)
                      _PlanRow(
                        label: 'Pair ${index + 1}',
                        detail: pair.pathIds
                            .map((id) =>
                                exercises[id] == null
                                    ? pathById(id).name
                                    : exerciseById(exercises[id]!).name)
                            .join('  ·  '),
                      ),
                    _PlanRow(
                      label: 'Core',
                      detail: plan.tripletPathIds
                          .map((id) => pathById(id).name)
                          .join('  ·  '),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: plan == null || active != null
                        ? null
                        : () => _beginWorkout(context, ref),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Begin workout'),
                  ),
                ],
              ),
            ),
          ),
          // Below the plan, not above it. Placed first, this pushed "Begin
          // workout" past the fold on a small screen — guidance must never
          // displace the primary action it is explaining.
          if (active == null &&
              ref.watch(completedSessionCountProvider).value == 0) ...[
            const SizedBox(height: 12),
            const _FirstRunCard(),
          ],
        ],
      ),
    );
  }
}

/// Opens a session row, starts the clock, and hands off to the warmup.
///
/// The session is written to the database *before* navigating, so a crash
/// anywhere after this point leaves something to resume into rather than
/// losing the workout.
Future<void> _beginWorkout(BuildContext context, WidgetRef ref) async {
  await ref.read(activeSessionProvider.notifier).start();
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const WarmupScreen()),
  );

  // Back on the dashboard. The session row survives — it is resumable — but
  // the clock and the wakelock must not, or a user who backed out and walked
  // away leaves the screen pinned on until the battery dies. Elapsed time is
  // derived from `startedAt`, so resuming picks up the true total.
  ref.read(sessionClockProvider.notifier).stop();
  ref.read(warmupChecklistProvider.notifier).clear();
}

/// Picks up a workout that was interrupted.
Future<void> _resumeWorkout(BuildContext context, WidgetRef ref) async {
  await ref.read(activeSessionProvider.notifier).resume();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ActiveWorkoutScreen()),
  );
  ref.read(sessionClockProvider.notifier).stop();
}

/// Offered when an `in_progress` session is found on launch.
/// One-time orientation for a fresh install.
///
/// Triple R starts every path at its easiest exercise, which is the right
/// default but is wrong for most people — someone who can already do pull-ups
/// should not spend their first session on scapular pulls. This says so once,
/// then never again.
class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.waving_hand_outlined,
                  size: 20,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'First time here',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Every progression starts at its easiest step. If some of them '
              'are already easy for you, set where you are on the Progression '
              'tab first — otherwise just begin, and the app will move you up '
              'as you hit your targets.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout in progress', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Started ${_startedLabel(startedAt)}. Your logged sets are safe.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _discard(context, ref),
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _resumeWorkout(context, ref),
                  child: const Text('Resume'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _startedLabel(DateTime at) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '$hour:${at.minute.toString().padLeft(2, '0')} '
        '${at.hour < 12 ? 'am' : 'pm'}';
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    // Abandoned rather than deleted: the sets were really performed, and the
    // rotation simply does not advance.
    await ref.read(activeSessionProvider.notifier).finish(completed: false);
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          Expanded(
            child: Text(detail, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
