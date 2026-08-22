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
import '../widgets/edit_set_dialog.dart';
import '../theme.dart';
import 'session_summary_screen.dart';

/// The two text controllers for the set being logged.
///
/// Held in a provider rather than in the field widget's state because the
/// fields live in the scrolling body while the Log-set button lives in the
/// fixed bar at the bottom, and both need the same text. Keyed by step and
/// auto-disposed, so moving to the next set gets fresh, empty controllers
/// without anyone having to remember to clear them.
class SetEntryFields {
  final value = TextEditingController();
  final weight = TextEditingController();

  /// Whether the user has typed in each field, so a seed arriving late can
  /// fill an untouched field without overwriting one they are working in.
  bool valueTouched = false;
  bool weightTouched = false;
  int? seededValue;
  String? seededWeight;

  void dispose() {
    value.dispose();
    weight.dispose();
  }
}

/// Identifies one set of one exercise — the lifetime of a set of fields.
String stepKey(WorkoutStep step) => '${step.pathId}-${step.setIndex}';

final setEntryProvider =
    Provider.autoDispose.family<SetEntryFields, String>((ref, key) {
  final fields = SetEntryFields();
  ref.onDispose(fields.dispose);
  return fields;
});

/// Selects the whole number when a numeric field is tapped.
///
/// Tapping such a field almost always means replacing the value, not editing
/// it: the seed is a guess, and the user is correcting it. Leaving the caret
/// where they tapped costs a select-all before they can type.
void selectAllOnTap(TextEditingController controller) {
  controller.selection =
      TextSelection(baseOffset: 0, extentOffset: controller.text.length);
}

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
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _StepView(session: session, step: step)),
            // Pinned above the action bar rather than sitting at the end of
            // the list. It is only relevant for as long as it is the last
            // thing that happened, and having to scroll to reach it defeats
            // the point of it being a quick correction.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _PreviousSetCard(session: session, step: step),
            ),
          ],
        ),
      ),
      // A fixed bar rather than a card floating over the list. It cannot be
      // scrolled away from, it never covers the set list, and — the reason it
      // exists — it gives Log set one permanent home. Skip rest used to sit in
      // the primary action position, so a thumb reaching for Log set hit it
      // instead and threw the rest away.
      bottomNavigationBar: _ActionBar(session: session, step: step),
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
          key: ValueKey(stepKey(step)),
          exercise: exercise,
          scheme: scheme,
          step: step,
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

/// The fields for one set. The button that submits them lives in the bar at
/// the bottom of the screen.
class _SetLogger extends ConsumerStatefulWidget {
  const _SetLogger({
    super.key,
    required this.exercise,
    required this.scheme,
    required this.step,
  });

  final Exercise exercise;
  final RepScheme scheme;
  final WorkoutStep step;

  @override
  ConsumerState<_SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends ConsumerState<_SetLogger> {
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
    final mine = _mine(thisSession);
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
  /// Null means leave the field empty rather than assert a zero — and a
  /// *recorded* zero is not null: someone who logged set 1 at 0 lb is telling
  /// the app the exercise is unloaded today, and re-seeding set 2 from the
  /// working load would overrule them every set.
  double? _seedWeightKg(
    List<SetRecord> thisSession,
    List<SetRecord>? lastSession,
    ExerciseState? state,
  ) {
    final mine = _mine(thisSession);
    if (mine.isNotEmpty) return mine.last.weightKg;

    final working = state?.workingLoadKg ?? 0;
    if (working > 0) return working;

    if (lastSession != null && lastSession.isNotEmpty) {
      return lastSession.first.weightKg;
    }
    return null;
  }

  /// Runs [action] once the current frame is over.
  ///
  /// Seeding writes to a controller the Log-set button also listens to, and
  /// that button lives in the bottom bar — a different subtree. Notifying a
  /// listener outside your own subtree during build is illegal, so the write
  /// has to wait until the build phase is done. (It was legal before only
  /// because the field itself was the controller's only listener, and a
  /// widget may always dirty its own descendants.)
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  List<SetRecord> _mine(List<SetRecord> sets) =>
      sets.where((s) => s.exerciseId == widget.exercise.id).toList()
        ..sort((a, b) => a.setIndex.compareTo(b.setIndex));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final previous = ref.watch(previousSetsProvider(widget.exercise.id)).value;
    final thisSession = ref.watch(currentSessionSetsProvider).value ?? const [];
    final fields = ref.watch(setEntryProvider(stepKey(widget.step)));
    final timed = widget.scheme.isTimed;

    final seed = _seedValue(thisSession, previous);
    if (!fields.valueTouched && seed != null && seed != fields.seededValue) {
      // Claimed synchronously so the next build does not schedule again; the
      // write itself waits for the frame to end. See [_afterFrame].
      fields.seededValue = seed;
      _afterFrame(() {
        if (fields.valueTouched) return;
        fields.value.value = TextEditingValue(
          text: '$seed',
          // Selected, not just placed: the common case is overtyping the
          // whole number, and a caret at the end means clearing it first.
          selection: TextSelection(baseOffset: 0, extentOffset: '$seed'.length),
        );
      });
    }

    if (widget.exercise.loadable && !fields.weightTouched) {
      final state = ref.watch(exerciseStateProvider(widget.exercise.id)).value;
      final kg = _seedWeightKg(thisSession, previous, state);
      // A seed of zero fills the field with "0" rather than leaving it blank:
      // the two now mean different things when the set is logged, and the
      // seed knows which one it is.
      final text = kg == null ? null : formatWeight(kg, units, withSuffix: false);
      if (text != null && text != fields.seededWeight) {
        fields.seededWeight = text;
        _afterFrame(() {
          if (fields.weightTouched) return;
          fields.weight.text = text;
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timed) ...[
          _SetStopwatch(fields: fields),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: fields.value,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.tabular,
          onTap: () => selectAllOnTap(fields.value),
          onChanged: (_) => setState(() => fields.valueTouched = true),
          decoration: InputDecoration(
            labelText: timed ? 'Seconds held' : 'Reps completed',
            // A free field rather than the old +/- pair: a 60-second plank
            // took sixty taps, and typing a number is faster than nudging to
            // it even for reps.
            border: const OutlineInputBorder(),
            errorText: _errorText(fields),
          ),
        ),
        if (widget.exercise.loadable) ...[
          const SizedBox(height: 12),
          TextField(
            controller: fields.weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => selectAllOnTap(fields.weight),
            onChanged: (_) => fields.weightTouched = true,
            decoration: InputDecoration(
              labelText: 'Added weight (${units.weightSuffix})',
              // Spelled out because the two look identical in an empty box:
              // a blank field records nothing, a typed 0 records a set done
              // with no added weight, and progression reads them differently.
              helperText: 'Empty records nothing; 0 is no added weight.',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  String? _errorText(SetEntryFields fields) {
    final text = fields.value.text.trim();
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    return parsed != null && parsed >= 0 ? null : 'Whole numbers only';
  }
}

/// Times the set as it happens, for holds.
///
/// A plank is not a number the user knows in advance — they hold it until
/// they fail and then need that duration recorded. Typing it means watching a
/// clock while shaking, so the app holds the clock instead and writes the
/// result into the field on stop.
class _SetStopwatch extends ConsumerWidget {
  const _SetStopwatch({required this.fields});

  final SetEntryFields fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(setStopwatchProvider);
    final stopwatch = ref.read(setStopwatchProvider.notifier);
    final running = stopwatch.isRunning;

    return Row(
      children: [
        Expanded(
          child: Text(
            formatDuration(stopwatch.elapsed),
            style: theme.textTheme.headlineMedium?.tabular.copyWith(
              color: running
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (running)
          FilledButton.tonalIcon(
            onPressed: () {
              final held = stopwatch.stop();
              final seconds = '${held.inSeconds}';
              fields.valueTouched = true;
              fields.value.value = TextEditingValue(
                text: seconds,
                selection:
                    TextSelection(baseOffset: 0, extentOffset: seconds.length),
              );
            },
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          )
        else
          OutlinedButton.icon(
            onPressed: stopwatch.start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start hold'),
          ),
      ],
    );
  }
}

/// The set just logged, on whichever exercise it belonged to.
///
/// Logging advances the cursor immediately, so during the rest the screen is
/// already showing the *next* exercise and the set just finished is nowhere
/// on it. Correcting a mistyped rep count meant waiting until that exercise
/// came round again two steps later. This keeps it one tap away for exactly
/// as long as it is the most recent thing that happened.
class _PreviousSetCard extends ConsumerWidget {
  const _PreviousSetCard({required this.session, required this.step});

  final ActiveSession session;
  final WorkoutStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitSystemProvider);
    final all = ref.watch(currentSessionSetsProvider).value ?? const [];

    // The most recent set that is not part of the step now on screen — which
    // during a pair is the other exercise, and on set 2 of a triplet is the
    // one before it in the circuit.
    final others = all
        .where((s) => !(s.pathId == step.pathId && s.setIndex == step.setIndex))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (others.isEmpty) return const SizedBox.shrink();

    final record = others.last;
    final exercise = exerciseById(record.exerciseId);
    final value = record.holdSeconds != null
        ? '${record.holdSeconds}s'
        : '${record.repsCompleted}';
    final weight = exercise.loadable && record.weightKg != null
        ? ' · ${formatWeight(record.weightKg!, units)}'
        : '';

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history, size: 20),
        title: Text(
          'Just logged · ${exercise.name} set ${record.setIndex}',
          style: theme.textTheme.bodySmall,
        ),
        subtitle: Text(
          '$value$weight',
          style: theme.textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => editLoggedSet(context, ref, record, exercise),
      ),
    );
  }
}

/// Every set of this exercise, logged or not, against what it was last time.
///
/// All three rows are present from the moment the exercise opens. Rendering
/// only the logged ones meant the list grew a row at the instant a set was
/// recorded and then the whole screen changed exercise a frame later, which
/// read as a flicker. A fixed list has nothing to shift: logging fills a
/// value in place, and only then does the step move on.
///
/// Each row also carries last session's number for that same set. The field
/// above is seeded from history, but a seed is a single guess that the user
/// then overtypes and loses sight of — showing all three of last week's sets
/// alongside this week's means "am I actually beating last time?" is answered
/// on the screen rather than by locking the entry box down to it.
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
    final units = ref.watch(unitSystemProvider);
    final all = ref.watch(currentSessionSetsProvider).value ?? const [];
    final byIndex = {
      for (final record in all)
        if (record.pathId == pathId) record.setIndex: record,
    };

    // The same query the field seeds itself from, so the two can never
    // disagree about what "last time" was.
    final previous = ref.watch(previousSetsProvider(exercise.id)).value;
    final lastByIndex = {
      for (final record in previous ?? const <SetRecord>[])
        record.setIndex: record,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two column headings rather than a section title and a note. Last
        // time sits *inside* this session's, so the eye lands on last week's
        // number first and this week's second — the order the comparison is
        // actually made in.
        Row(
          children: [
            const Spacer(),
            if (lastByIndex.isNotEmpty)
              SizedBox(
                width: _SetRow.columnWidth,
                child: Text(
                  'Last time',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            SizedBox(
              width: _SetRow.columnWidth,
              child: Text(
                'This session',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        for (var index = 1; index <= setsPerExercise; index++)
          _SetRow(
            setIndex: index,
            record: byIndex[index],
            previous: lastByIndex[index],
            loadable: exercise.loadable,
            units: units,
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
  ) =>
      editLoggedSet(context, ref, record, exercise);
}

/// Opens the correction dialog for [record] and writes the result back.
///
/// Shared by the current exercise's set list and the previous-exercise card,
/// so a set is corrected the same way wherever it is reached from.
Future<void> editLoggedSet(
  BuildContext context,
  WidgetRef ref,
  SetRecord record,
  Exercise exercise,
) async {
  final timed = record.holdSeconds != null;
  final result = await showDialog<EditSetResult>(
    context: context,
    builder: (_) => EditSetDialog(
      title: '${exercise.name} · set ${record.setIndex}',
      initialValue: record.holdSeconds ?? record.repsCompleted ?? 0,
      timed: timed,
      units: ref.read(unitSystemProvider),
      initialWeightKg: exercise.loadable ? record.weightKg : null,
    ),
  );
  if (result == null) return;

  await ref.read(activeSessionProvider.notifier).editSet(
        pathId: record.pathId,
        setIndex: record.setIndex,
        reps: timed ? null : result.value,
        holdSeconds: timed ? result.value : null,
        weightKg: result.weightKg,
      );
}

/// One row: a logged value, or a placeholder holding its place, next to
/// whatever the same set came to last session.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setIndex,
    required this.record,
    required this.previous,
    required this.loadable,
    required this.units,
    required this.isCurrent,
    required this.onEdit,
  });

  final int setIndex;
  final SetRecord? record;

  /// The same set index from the last session that included this exercise, or
  /// null if there was no such set — a first session, or one cut short.
  final SetRecord? previous;

  final bool loadable;
  final UnitSystem units;
  final bool isCurrent;
  final VoidCallback? onEdit;

  /// Fixed so the two columns and their headings share one edge. Wide enough
  /// for the longest thing a row holds — a hold plus a load, "45s @ 25 lb".
  static const columnWidth = 92.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = record != null;
    final value = done
        ? _describe(record!)
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Last time first, then this session, so the row reads in the
          // direction the comparison runs — what you did, then what you are
          // doing. Reserved whether or not there is a number to put in it, so
          // the three rows line up rather than stepping in and out as sets
          // that existed last week and sets that did not alternate down the
          // list.
          SizedBox(
            width: columnWidth,
            child: Text(
              previous == null ? '' : _describe(previous!),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.tabular
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: columnWidth,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium?.tabular.copyWith(
                color: done ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      onTap: onEdit,
    );
  }

  /// Reps or seconds, with the load when the exercise carries one.
  String _describe(SetRecord set) {
    final value =
        set.holdSeconds != null ? '${set.holdSeconds}s' : '${set.repsCompleted}';
    final weight = set.weightKg;
    // Null is dropped, zero is not. On an exercise that takes a load, zero is
    // a real answer — it is how someone records dropping back to bare
    // bodyweight — and hiding it makes that set look like the weight was
    // never entered.
    if (!loadable || weight == null) return value;
    return '$value @ ${formatWeight(weight, units)}';
  }
}

/// The fixed bottom bar: rest state on the left, Log set on the right.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.session, required this.step});

  final ActiveSession session;
  final WorkoutStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countdown = ref.watch(restTimerProvider);
    final controller = ref.read(restTimerProvider.notifier);
    final resting = !countdown.isIdle;
    final fields = ref.watch(setEntryProvider(stepKey(step)));

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  if (resting) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          countdown.isFinished ? 'Rest done' : 'Resting',
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          formatDuration(controller.remaining),
                          style: theme.textTheme.titleLarge?.tabular,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    // Red and unfilled. Throwing the rest away is destructive
                    // in a small way, and it should not read as the thing to
                    // do next — which is exactly how it read as a filled
                    // button in the primary position.
                    TextButton(
                      onPressed: controller.skip,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(countdown.isFinished ? 'Dismiss' : 'Skip'),
                    ),
                    TextButton(
                      onPressed: () =>
                          controller.extend(const Duration(seconds: 15)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('+15s'),
                    ),
                  ],
                  const Spacer(),
                  _LogSetButton(fields: fields, session: session, step: step),
                ],
              ),
            ),
            // The rest running out along the bottom edge, mirroring the
            // session progress bar at the top of the list.
            SizedBox(
              height: 3,
              child: resting
                  ? LinearProgressIndicator(
                      value: countdown.progress(ref.read(clockProvider).now()),
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Logs the set from whatever is currently in the fields.
class _LogSetButton extends ConsumerWidget {
  const _LogSetButton({
    required this.fields,
    required this.session,
    required this.step,
  });

  final SetEntryFields fields;
  final ActiveSession session;
  final WorkoutStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitSystemProvider);
    final exercise = exerciseById(session.exerciseFor(step));
    final timed = schemeFor(exercise, step.slot).isTimed;

    // Rebuilt from the controller rather than from widget state: the field
    // that owns the text lives in the scrolling body, and the button has to
    // enable and disable along with it.
    return ListenableBuilder(
      listenable: fields.value,
      builder: (context, _) {
        final entered = int.tryParse(fields.value.text.trim());
        final valid = entered != null && entered >= 0;
        return FilledButton(
          onPressed: valid ? () => _log(ref, entered, timed, units) : null,
          child: const Text('Log set'),
        );
      },
    );
  }

  Future<void> _log(
    WidgetRef ref,
    int entered,
    bool timed,
    UnitSystem units,
  ) async {
    // Empty is not zero. `?? 0` here was why a set logged at 0 lb and a set
    // logged with the field untouched came out of the database identical.
    final weight = double.tryParse(fields.weight.text.trim());
    // Confirmed by touch: the user is often looking at the bar, not the
    // phone, and needs to know the tap registered without checking.
    //
    // `ignore()` rather than `await`. Feedback must never sit between the tap
    // and the work it confirms — awaiting a platform channel here means a
    // device that answers slowly (or, in a test, never) silently swallows the
    // set instead of logging it.
    ref.read(hapticsProvider).confirm().ignore();
    // A running stopwatch belongs to the set being logged, not the next one.
    if (ref.read(setStopwatchProvider) != null) {
      ref.read(setStopwatchProvider.notifier).stop();
    }
    await ref.read(activeSessionProvider.notifier).logSet(
          reps: timed ? null : entered,
          holdSeconds: timed ? entered : null,
          weightKg: weight == null ? null : fromDisplayWeight(weight, units),
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
