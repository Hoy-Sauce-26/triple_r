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
import '../theme.dart';
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
      body: SafeArea(
        // The rest card sits at the bottom of the stack, which on Android
        // gesture/3-button navigation is underneath the system bar. Nothing
        // else in the app was inset either, so this guards the whole body.
        child: Stack(
          children: [
            _StepView(session: session, step: step),
            const _RestOverlay(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final logged = ref.read(currentSessionSetsProvider).value?.length ?? 0;
    ref.read(hapticsProvider).warn().ignore();
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
      style: Theme.of(context).textTheme.titleMedium?.tabular,
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

    // The rest card floats over this list. Without room reserved for it the
    // "Log set" button ends up underneath and cannot be scrolled into view.
    final resting = !ref.watch(restTimerProvider).isIdle;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, resting ? 148 : 24),
      children: [
        LinearProgressIndicator(
          value: session.stepsTotal == 0 ? 0 : done / session.stepsTotal,
        ),
        const SizedBox(height: 16),
        Text(
          '${step.blockLabel} · set ${step.setIndex} of $setsPerExercise',
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
        _LoggedSets(
          pathId: step.pathId,
          exercise: exercise,
          currentSetIndex: step.setIndex,
        ),
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
  final _entry = TextEditingController();
  final _weight = TextEditingController();

  /// The seed currently sitting in the field, so an async value arriving late
  /// can fill an untouched field without overwriting one the user has typed
  /// into.
  int? _seeded;
  bool _touched = false;

  /// Same idea for the added weight, tracked separately so typing a rep count
  /// does not freeze the weight field and vice versa.
  String? _seededWeight;
  bool _weightTouched = false;

  @override
  void initState() {
    super.initState();
    _entry.addListener(_onEntryChanged);
    _weight.addListener(_onWeightChanged);
  }

  void _onEntryChanged() {
    // Only the *first* edit matters; after that the field is the user's.
    if (!_touched) _touched = true;
    setState(() {});
  }

  void _onWeightChanged() => _weightTouched = true;

  @override
  void dispose() {
    _entry.removeListener(_onEntryChanged);
    _weight.removeListener(_onWeightChanged);
    _entry.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// What to pre-fill this set with, best source first:
  ///
  /// 1. The last set of this exercise *this session* — someone who moved from
  ///    5 pull-ups to 8 this week is going for 8 again on set 2, not 5.
  /// 2. What they managed last session.
  /// 3. The scheme floor, for an exercise with no history at all.
  ///
  /// Deliberately not the scheme *target*: hitting the ceiling is the goal,
  /// not the norm, so the target is the worse guess almost every time.
  int? _seedValue(List<SetRecord> thisSession, List<SetRecord>? lastSession) {
    final mine = thisSession
        .where((s) => s.exerciseId == widget.exercise.id)
        .toList()
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    if (mine.isNotEmpty) {
      return mine.last.repsCompleted ?? mine.last.holdSeconds;
    }
    if (lastSession != null && lastSession.isNotEmpty) {
      return lastSession.first.repsCompleted ?? lastSession.first.holdSeconds;
    }
    return widget.scheme.floor;
  }

  /// What weight to pre-fill, best source first:
  ///
  /// 1. The last set of this exercise this session — the plates do not change
  ///    between sets, and re-typing them three times invites a typo.
  /// 2. The load the progression system has this exercise at, which is ahead
  ///    of last session's if an add-load prompt was accepted.
  /// 3. What was actually on the bar last session, for anyone logging weight
  ///    without using load mode at all.
  ///
  /// Null means leave the field empty rather than assert a zero.
  double? _seedWeightKg(
    List<SetRecord> thisSession,
    List<SetRecord>? lastSession,
    ExerciseState? state,
  ) {
    final mine = thisSession
        .where((s) => s.exerciseId == widget.exercise.id)
        .toList()
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    if (mine.isNotEmpty) return mine.last.weightKg;

    final working = state?.workingLoadKg ?? 0;
    if (working > 0) return working;

    if (lastSession != null && lastSession.isNotEmpty) {
      return lastSession.first.weightKg;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final previous = ref.watch(previousSetsProvider(widget.exercise.id)).value;
    final thisSession = ref.watch(currentSessionSetsProvider).value ?? const [];
    final timed = widget.scheme.isTimed;

    final seed = _seedValue(thisSession, previous);
    if (!_touched && seed != null && seed != _seeded) {
      // Guarded by the value so this converges rather than looping: it runs
      // once when the seed first resolves, and again only if it genuinely
      // changes while the field is still untouched.
      _seeded = seed;
      _entry.value = TextEditingValue(
        text: '$seed',
        // Selected, not just placed: the common case is overtyping the whole
        // number, and a caret at the end would mean clearing it first.
        selection: TextSelection(baseOffset: 0, extentOffset: '$seed'.length),
      );
    }

    if (widget.exercise.loadable && !_weightTouched) {
      final state = ref.watch(exerciseStateProvider(widget.exercise.id)).value;
      final kg = _seedWeightKg(thisSession, previous, state);
      final text =
          kg == null || kg == 0 ? '' : formatWeight(kg, units, withSuffix: false);
      if (text.isNotEmpty && text != _seededWeight) {
        _seededWeight = text;
        _weight.text = text;
        // Set directly rather than through the listener, which would flip
        // `_weightTouched` and stop the field ever seeding again.
        _weightTouched = false;
      }
    }

    final entered = int.tryParse(_entry.text.trim());
    final valid = entered != null && entered >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _entry,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.tabular,
          onSubmitted: (_) => valid ? _log(entered, timed, units) : null,
          decoration: InputDecoration(
            labelText: timed ? 'Seconds held' : 'Reps completed',
            // A free field rather than the old +/- pair: a 60-second plank
            // took sixty taps, and typing a number is faster than nudging to
            // it even for reps.
            border: const OutlineInputBorder(),
            errorText: _entry.text.trim().isEmpty || valid
                ? null
                : 'Whole numbers only',
          ),
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
          onPressed: valid ? () => _log(entered, timed, units) : null,
          child: const Text('Log set'),
        ),
      ],
    );
  }

  Future<void> _log(int entered, bool timed, UnitSystem units) async {
    final weight = double.tryParse(_weight.text) ?? 0;
    // Confirmed by touch: the user is often looking at the bar, not the
    // phone, and needs to know the tap registered without checking.
    //
    // `ignore()` rather than `await`. Feedback must never sit between the tap
    // and the work it confirms — awaiting a platform channel here means a
    // device that answers slowly (or, in a test, never) silently swallows the
    // set instead of logging it.
    ref.read(hapticsProvider).confirm().ignore();
    await ref.read(activeSessionProvider.notifier).logSet(
          reps: timed ? null : entered,
          holdSeconds: timed ? entered : null,
          weightKg: fromDisplayWeight(weight, units),
        );
  }
}

/// Every set of this exercise, logged or not.
///
/// All three rows are present from the moment the exercise opens. Rendering
/// only the logged ones meant the list grew a row at the instant a set was
/// recorded and then the whole screen changed exercise a frame later, which
/// read as a flicker. A fixed list has nothing to shift: logging fills a
/// value in place, and only then does the step move on.
class _LoggedSets extends ConsumerWidget {
  const _LoggedSets({
    required this.pathId,
    required this.exercise,
    required this.currentSetIndex,
  });

  final String pathId;
  final Exercise exercise;
  final int currentSetIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(currentSessionSetsProvider).value ?? const [];
    final byIndex = {
      for (final record in all)
        if (record.pathId == pathId) record.setIndex: record,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This session', style: theme.textTheme.labelLarge),
        for (var index = 1; index <= setsPerExercise; index++)
          _SetRow(
            setIndex: index,
            record: byIndex[index],
            isCurrent: index == currentSetIndex,
            onEdit: byIndex[index] == null
                ? null
                : () => _edit(context, ref, byIndex[index]!),
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

/// One row: a logged value, or a placeholder holding its place.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setIndex,
    required this.record,
    required this.isCurrent,
    required this.onEdit,
  });

  final int setIndex;
  final SetRecord? record;
  final bool isCurrent;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = record != null;
    final value = done
        ? (record!.holdSeconds != null
            ? '${record!.holdSeconds}s'
            : '${record!.repsCompleted}')
        // An em dash rather than a zero: nothing has been recorded here yet,
        // and a zero is a real thing a user can log.
        : '—';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Set $setIndex',
        style: isCurrent
            ? theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.primary)
            : null,
      ),
      trailing: Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          color: done ? null : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onEdit,
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
                      style: theme.textTheme.headlineMedium?.tabular,
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
