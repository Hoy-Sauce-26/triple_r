import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/progression.dart';
import '../domain/units.dart';
import '../providers.dart';
import '../state/active_session.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';

/// What the workout changed, and what the app wants to offer as a result.
///
/// Every prompt here is a question, never an applied change — the user can
/// decline any of them and be re-asked next time the condition holds. See
/// `docs/PLAN.md` §2.2.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key, required this.outcomes});

  final List<SessionOutcome> outcomes;

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final _handled = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending =
        widget.outcomes.where((o) => !_handled.contains(o.exerciseId)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout complete'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.outcomes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Logged', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Nothing to change — keep going at the same exercises '
                      'next session.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              pending.isEmpty ? 'All set' : 'Ready to move on',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final outcome in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OutcomeCard(
                  outcome: outcome,
                  onResolved: () =>
                      setState(() => _handled.add(outcome.exerciseId)),
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _OutcomeCard extends ConsumerWidget {
  const _OutcomeCard({required this.outcome, required this.onResolved});

  final SessionOutcome outcome;
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final exercise = exerciseById(outcome.exerciseId);
    final pathName = pathById(outcome.pathId).name;

    final (title, body, accept) = switch (outcome.outcome) {
      AdvanceOutcome(nextExerciseId: final next) => (
          'Nice work on ${exercise.name}',
          'You hit the top of the range on every set. Move up to '
              '${exerciseById(next).name}?',
          'Move up',
        ),
      RegressOutcome(previousExerciseId: final previous) => (
          '${exercise.name} is not landing',
          'Two sessions short of the range. Drop back to '
              '${exerciseById(previous).name} and rebuild?',
          'Drop back',
        ),
      AddLoadOutcome(:final resultingLoadKg) => (
          'Nice work on ${exercise.name}',
          'Add weight for next session? That takes you to '
              '${formatWeight(resultingLoadKg, units)}.',
          'Add weight',
        ),
      ReduceLoadOutcome(:final resultingLoadKg) => (
          '${exercise.name} is not landing',
          'Take some weight off? That brings you down to '
              '${formatWeight(resultingLoadKg, units)}.',
          'Take it off',
        ),
      MasteredOutcome() => (
          'You have topped out ${exercise.name}',
          'That is the end of this progression — there is nothing harder on '
              'this branch and no weight to add. Keep it here, or pick a '
              'different branch on the Progression tab whenever you want a '
              'new challenge.',
          null,
        ),
      HoldOutcome() => ('', '', null),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pathName,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 2),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onResolved,
                  child: Text(accept == null ? 'Got it' : 'Not yet'),
                ),
                if (accept != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(activeSessionProvider.notifier)
                          .applyOutcome(outcome);
                      onResolved();
                    },
                    child: Text(accept),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
