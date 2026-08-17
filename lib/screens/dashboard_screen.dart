import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../state/timer_providers.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import 'warmup_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(nextSessionPlanProvider);
    final exercises = ref.watch(nextSessionExercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Triple R')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
                    onPressed:
                        plan == null ? null : () => _beginWorkout(context, ref),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Begin workout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Starts the workout clock, holds the screen awake, and opens the warmup.
///
/// The session *row* is not written here — that, and everything after the
/// warmup, is Phase 4. This is the smallest wiring that makes the wakelock and
/// the session clock actually run rather than merely exist.
Future<void> _beginWorkout(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionClockProvider.notifier);

  // Asked for here rather than at launch: the user has just said they are
  // working out, so a request to tell them when a rest ends makes sense.
  await ref.read(restNotificationsProvider).requestPermission();

  session.start();
  if (!context.mounted) {
    session.stop();
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const WarmupScreen()),
  );

  // Leaving the warmup — by finishing or by backing out — ends the session for
  // now, so the wakelock is never left on after the user walks away.
  session.stop();
  ref.read(warmupChecklistProvider.notifier).clear();
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
