/// Turning logged sets into something chartable.
///
/// The load-bearing decision here is that series are **per exercise, never per
/// path**. Reps reset to the bottom of the range every time a user advances,
/// so a path-level rep chart draws a sawtooth that looks like months of
/// regression. See `docs/PLAN.md` §6.
library;

import '../data/database.dart';
import '../trees/exercises.dart';
import '../trees/paths.dart';
import '../trees/tree_types.dart';


/// One session's worth of one exercise, reduced to a single plottable number.
class SeriesPoint {
  const SeriesPoint({
    required this.date,
    required this.value,
    required this.sessionId,
    required this.setCount,
  });

  final DateTime date;
  final double value;
  final String sessionId;
  final int setCount;
}

/// What a series' numbers mean, so the axis can be labelled honestly.
enum SeriesKind {
  /// Best set, in reps.
  reps,

  /// Best hold, in seconds.
  seconds,

  /// Working load. Stored in kg; the chart converts for display.
  weightKg,
}

class ExerciseSeries {
  const ExerciseSeries({
    required this.exerciseId,
    required this.kind,
    required this.points,
    required this.perSide,
  });

  final String exerciseId;
  final SeriesKind kind;
  final List<SeriesPoint> points;
  final bool perSide;

  bool get isEmpty => points.isEmpty;

  double get best =>
      points.isEmpty ? 0 : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  String get axisLabel => switch (kind) {
        SeriesKind.reps => perSide ? 'Best set (reps per side)' : 'Best set (reps)',
        SeriesKind.seconds => 'Best hold (seconds)',
        SeriesKind.weightKg => 'Working weight',
      };
}

/// Reduces [sets] to one point per session.
///
/// The reducer is the *best* set rather than the total: volume moves when a
/// session is cut short, which would read as a strength drop when the user
/// simply ran out of time. The best set is the honest signal of capability.
ExerciseSeries buildExerciseSeries(String exerciseId, List<SetRecord> sets) {
  final exercise = exercisesById[exerciseId];
  final loadMode = exercise?.mode == ProgressionMode.load;
  final timed = exercise?.metric == Metric.timed;

  final kind = loadMode
      ? SeriesKind.weightKg
      : timed
          ? SeriesKind.seconds
          : SeriesKind.reps;

  final bySession = <String, List<SetRecord>>{};
  for (final set in sets) {
    bySession.putIfAbsent(set.sessionId, () => []).add(set);
  }

  final points = <SeriesPoint>[];
  for (final entry in bySession.entries) {
    final rows = entry.value;
    final value = switch (kind) {
      SeriesKind.weightKg => _max(rows.map((r) => r.weightKg)),
      SeriesKind.seconds =>
        _max(rows.map((r) => (r.holdSeconds ?? 0).toDouble())),
      SeriesKind.reps => _max(rows.map((r) => (r.repsCompleted ?? 0).toDouble())),
    };
    points.add(
      SeriesPoint(
        date: rows.map((r) => r.recordedAt).reduce((a, b) => a.isBefore(b) ? a : b),
        value: value,
        sessionId: entry.key,
        setCount: rows.length,
      ),
    );
  }

  points.sort((a, b) => a.date.compareTo(b.date));
  return ExerciseSeries(
    exerciseId: exerciseId,
    kind: kind,
    points: points,
    perSide: exercise?.perSide ?? false,
  );
}

/// A change of exercise on one path, for the timeline beneath the charts.
///
/// This is the other half of the sawtooth fix: rather than drawing a
/// misleading continuous line across an advancement, the app states the
/// advancement as an event — "moved to Diamond Push-ups on 3 March".
class ProgressionEvent {
  const ProgressionEvent({
    required this.date,
    required this.pathId,
    required this.fromExerciseId,
    required this.toExerciseId,
  });

  final DateTime date;
  final String pathId;
  final String fromExerciseId;
  final String toExerciseId;
}

/// Derives advancement events from the log itself.
///
/// Reconstructed from `set_records` rather than read from a dedicated table:
/// the log already knows which exercise filled a path on any given day, and a
/// second source of truth would be one more thing to keep in step.
List<ProgressionEvent> progressionEvents(List<SetRecord> allSets) {
  final byPath = <String, List<SetRecord>>{};
  for (final set in allSets) {
    byPath.putIfAbsent(set.pathId, () => []).add(set);
  }

  final events = <ProgressionEvent>[];
  for (final entry in byPath.entries) {
    final rows = entry.value..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    String? previous;
    for (final row in rows) {
      if (previous != null &&
          row.exerciseId != previous &&
          !_isAlternatingSwap(entry.key, previous, row.exerciseId)) {
        events.add(
          ProgressionEvent(
            date: row.recordedAt,
            pathId: entry.key,
            fromExerciseId: previous,
            toExerciseId: row.exerciseId,
          ),
        );
      }
      previous = row.exerciseId;
    }
  }

  events.sort((a, b) => b.date.compareTo(a.date));
  return events;
}

/// Whether moving between two exercises is an alternating branch doing its
/// job rather than the user progressing.
///
/// The barbell hinge branch runs RDL on days 1 and 3 and deadlift on day 2, so
/// a naive diff of consecutive sessions reports two "advancements" every week
/// — and the timeline fills with noise for exactly the users following the
/// routine most closely. Written against [BranchKind] rather than
/// special-casing the hinge, so a second alternating branch needs no change
/// here.
bool _isAlternatingSwap(String pathId, String from, String to) {
  final path = pathsById[pathId];
  if (path == null) return false;
  for (final branch in path.branches) {
    if (branch.kind != BranchKind.alternating) continue;
    if (branch.exerciseIds.contains(from) && branch.exerciseIds.contains(to)) {
      return true;
    }
  }
  return false;
}

/// A completed session reduced to the numbers the history list shows.
class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.setCount,
    required this.exerciseCount,
  });

  final WorkoutSession session;
  final int setCount;
  final int exerciseCount;

  Duration? get duration => session.endedAt?.difference(session.startedAt);

  bool get wasAbandoned => session.status == 'abandoned';
}

SessionSummary summarise(WorkoutSession session, List<SetRecord> sets) =>
    SessionSummary(
      session: session,
      setCount: sets.length,
      exerciseCount: sets.map((s) => s.exerciseId).toSet().length,
    );

double _max(Iterable<double> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
