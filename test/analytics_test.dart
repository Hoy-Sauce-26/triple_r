import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/domain/analytics.dart';

void main() {
  var counter = 0;

  SetRecord makeSet({
    required String sessionId,
    required String exerciseId,
    String pathId = 'pushup',
    int? reps,
    int? hold,
    double weightKg = 0,
    required DateTime at,
    int setIndex = 1,
  }) {
    return SetRecord(
      id: 'set-${counter++}',
      sessionId: sessionId,
      pathId: pathId,
      exerciseId: exerciseId,
      setIndex: setIndex,
      repsCompleted: reps,
      holdSeconds: hold,
      weightKg: weightKg,
      recordedAt: at,
    );
  }

  setUp(() => counter = 0);

  group('series kind follows the exercise', () {
    test('a load-mode exercise plots weight', () {
      final series = buildExerciseSeries('barbell_deadlift', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'barbell_deadlift',
          reps: 5,
          weightKg: 100,
          at: DateTime(2026, 3, 1),
        ),
      ]);
      expect(series.kind, SeriesKind.weightKg);
      expect(series.points.single.value, 100);
    });

    test('a timed exercise plots seconds', () {
      final series = buildExerciseSeries('planks', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'planks',
          hold: 45,
          at: DateTime(2026, 3, 1),
        ),
      ]);
      expect(series.kind, SeriesKind.seconds);
      expect(series.points.single.value, 45);
    });

    test('a bodyweight rep exercise plots reps and knows if it is per side', () {
      final reps = buildExerciseSeries('full_pushups', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 8,
          at: DateTime(2026, 3, 1),
        ),
      ]);
      expect(reps.kind, SeriesKind.reps);
      expect(reps.perSide, isFalse);
      expect(reps.axisLabel, 'Best set (reps)');

      final perSide = buildExerciseSeries('pistol_squats', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'pistol_squats',
          pathId: 'squat',
          reps: 5,
          at: DateTime(2026, 3, 1),
        ),
      ]);
      expect(perSide.perSide, isTrue);
      expect(perSide.axisLabel, contains('per side'));
    });

    test('an unknown exercise id still produces a series', () {
      // Retired ids must stay renderable — see the id stability policy.
      final series = buildExerciseSeries('gone_forever', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'gone_forever',
          reps: 6,
          at: DateTime(2026, 3, 1),
        ),
      ]);
      expect(series.kind, SeriesKind.reps);
      expect(series.points, hasLength(1));
    });
  });

  group('one point per session', () {
    test('takes the best set, not the total', () {
      // A short session logging two sets must not read as a strength drop
      // against a full one logging three.
      final series = buildExerciseSeries('full_pushups', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 8,
          setIndex: 1,
          at: DateTime(2026, 3, 1, 9),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 6,
          setIndex: 2,
          at: DateTime(2026, 3, 1, 9, 5),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 7,
          setIndex: 3,
          at: DateTime(2026, 3, 1, 9, 10),
        ),
      ]);

      expect(series.points, hasLength(1));
      expect(series.points.single.value, 8);
      expect(series.points.single.setCount, 3);
    });

    test('dates the point from the first set of the session', () {
      final series = buildExerciseSeries('full_pushups', [
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 5,
          at: DateTime(2026, 3, 1, 9, 40),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 5,
          at: DateTime(2026, 3, 1, 9, 10),
        ),
      ]);
      expect(series.points.single.date, DateTime(2026, 3, 1, 9, 10));
    });

    test('orders points oldest first regardless of input order', () {
      final series = buildExerciseSeries('full_pushups', [
        makeSet(
          sessionId: 's3',
          exerciseId: 'full_pushups',
          reps: 8,
          at: DateTime(2026, 3, 5),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 5,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's2',
          exerciseId: 'full_pushups',
          reps: 6,
          at: DateTime(2026, 3, 3),
        ),
      ]);
      expect(series.points.map((p) => p.value), [5, 6, 8]);
      expect(series.best, 8);
    });

    test('an empty log is empty, not zero', () {
      final series = buildExerciseSeries('full_pushups', []);
      expect(series.isEmpty, isTrue);
      expect(series.points, isEmpty);
    });
  });

  group('progression events', () {
    test('records the move when a path changes exercise', () {
      final events = progressionEvents([
        makeSet(
          sessionId: 's1',
          exerciseId: 'incline_pushups',
          reps: 8,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's2',
          exerciseId: 'full_pushups',
          reps: 5,
          at: DateTime(2026, 3, 3),
        ),
      ]);

      expect(events, hasLength(1));
      expect(events.single.fromExerciseId, 'incline_pushups');
      expect(events.single.toExerciseId, 'full_pushups');
      expect(events.single.date, DateTime(2026, 3, 3));
      expect(events.single.pathId, 'pushup');
    });

    test('does not fire when the exercise stays put', () {
      final events = progressionEvents([
        for (var day = 1; day <= 5; day++)
          makeSet(
            sessionId: 's$day',
            exerciseId: 'full_pushups',
            reps: 6,
            at: DateTime(2026, 3, day),
          ),
      ]);
      expect(events, isEmpty);
    });

    test('records a regression too, since it is also a move', () {
      final events = progressionEvents([
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 4,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's2',
          exerciseId: 'incline_pushups',
          reps: 8,
          at: DateTime(2026, 3, 3),
        ),
      ]);
      expect(events.single.toExerciseId, 'incline_pushups');
    });

    test('tracks paths independently', () {
      final events = progressionEvents([
        makeSet(
          sessionId: 's1',
          exerciseId: 'incline_pushups',
          pathId: 'pushup',
          reps: 8,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'assisted_squats',
          pathId: 'squat',
          reps: 8,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's2',
          exerciseId: 'full_pushups',
          pathId: 'pushup',
          reps: 5,
          at: DateTime(2026, 3, 3),
        ),
      ]);

      // The squat path never changed, so only the push-up move is an event.
      expect(events, hasLength(1));
      expect(events.single.pathId, 'pushup');
    });

    test('the alternating hinge branch is not mistaken for progression', () {
      // RDL / deadlift / RDL across three sessions is the weekly pattern, not
      // the user advancing and regressing every workout.
      final events = progressionEvents([
        makeSet(
          sessionId: 's1',
          exerciseId: 'barbell_romanian_deadlift',
          pathId: 'hinge',
          reps: 5,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's2',
          exerciseId: 'barbell_deadlift',
          pathId: 'hinge',
          reps: 5,
          at: DateTime(2026, 3, 3),
        ),
        makeSet(
          sessionId: 's3',
          exerciseId: 'barbell_romanian_deadlift',
          pathId: 'hinge',
          reps: 5,
          at: DateTime(2026, 3, 5),
        ),
      ]);

      expect(
        events,
        isEmpty,
        reason: 'alternating lifts swap by design and are not advancements',
      );
    });

    test('newest first, for a list that reads top-down', () {
      final events = progressionEvents([
        makeSet(
          sessionId: 's1',
          exerciseId: 'wall_pushups',
          reps: 8,
          at: DateTime(2026, 3, 1),
        ),
        makeSet(
          sessionId: 's2',
          exerciseId: 'incline_pushups',
          reps: 8,
          at: DateTime(2026, 3, 3),
        ),
        makeSet(
          sessionId: 's3',
          exerciseId: 'full_pushups',
          reps: 5,
          at: DateTime(2026, 3, 5),
        ),
      ]);
      expect(events.map((e) => e.toExerciseId), [
        'full_pushups',
        'incline_pushups',
      ]);
    });
  });

  group('session summary', () {
    WorkoutSession session({String status = 'completed', DateTime? ended}) =>
        WorkoutSession(
          id: 's1',
          startedAt: DateTime(2026, 3, 1, 9),
          endedAt: ended,
          status: status,
          rotationIndex: 0,
          pairRestSeconds: 90,
          tripletRestSeconds: 60,
        );

    test('counts sets and distinct exercises', () {
      final summary = summarise(session(ended: DateTime(2026, 3, 1, 10)), [
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 8,
          at: DateTime(2026, 3, 1, 9),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'full_pushups',
          reps: 8,
          setIndex: 2,
          at: DateTime(2026, 3, 1, 9, 5),
        ),
        makeSet(
          sessionId: 's1',
          exerciseId: 'planks',
          hold: 45,
          at: DateTime(2026, 3, 1, 9, 30),
        ),
      ]);

      expect(summary.setCount, 3);
      expect(summary.exerciseCount, 2);
      expect(summary.duration, const Duration(hours: 1));
      expect(summary.wasAbandoned, isFalse);
    });

    test('has no duration while the end time is unknown', () {
      expect(summarise(session(), const []).duration, isNull);
    });

    test('flags an abandoned session', () {
      expect(summarise(session(status: 'abandoned'), const []).wasAbandoned,
          isTrue);
    });
  });
}
