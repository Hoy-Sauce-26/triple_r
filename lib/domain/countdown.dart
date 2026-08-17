/// Rest-timer and session-clock arithmetic.
///
/// Everything here is **deadline-based**, not decrement-based: a running
/// countdown stores the wall-clock instant it ends and derives what is left,
/// rather than subtracting on each tick.
///
/// That distinction is the whole design. A phone that locks, sleeps, or
/// throttles timers for thirty seconds delivers one late tick instead of
/// thirty on time — a decrementing counter would come back thirty seconds
/// wrong and a rest period would silently stretch. A deadline is simply
/// correct whenever it is next observed.
library;

enum CountdownPhase { idle, running, paused, finished }

class Countdown {
  const Countdown._({
    required this.total,
    required this.phase,
    this.deadline,
    this.frozenRemaining,
  });

  const Countdown.idle(this.total)
      : phase = CountdownPhase.idle,
        deadline = null,
        frozenRemaining = null;

  /// The configured length, kept so a paused or finished timer can still
  /// report progress and so [restart] needs no argument.
  final Duration total;

  final CountdownPhase phase;

  /// When the timer runs out. Set only while running.
  final DateTime? deadline;

  /// What was left when paused. Set only while paused.
  final Duration? frozenRemaining;

  bool get isRunning => phase == CountdownPhase.running;
  bool get isPaused => phase == CountdownPhase.paused;
  bool get isFinished => phase == CountdownPhase.finished;
  bool get isIdle => phase == CountdownPhase.idle;

  /// Time left at [now], never negative.
  Duration remaining(DateTime now) {
    switch (phase) {
      case CountdownPhase.idle:
        return total;
      case CountdownPhase.paused:
        return frozenRemaining!;
      case CountdownPhase.finished:
        return Duration.zero;
      case CountdownPhase.running:
        final left = deadline!.difference(now);
        return left.isNegative ? Duration.zero : left;
    }
  }

  /// Whether a running timer has passed its deadline at [now].
  ///
  /// Distinct from [isFinished], which is the state after the caller has
  /// acknowledged it — the gap between the two is where the alert fires,
  /// exactly once.
  bool hasElapsed(DateTime now) =>
      isRunning && !deadline!.isAfter(now);

  /// 0.0 at the start, 1.0 when done. Useful for a progress ring.
  double progress(DateTime now) {
    if (total == Duration.zero) return 1;
    final left = remaining(now).inMilliseconds;
    return (1 - left / total.inMilliseconds).clamp(0.0, 1.0);
  }

  Countdown start(Duration length, DateTime now) => Countdown._(
        total: length,
        phase: CountdownPhase.running,
        deadline: now.add(length),
      );

  Countdown restart(DateTime now) => start(total, now);

  Countdown pause(DateTime now) {
    if (!isRunning) return this;
    return Countdown._(
      total: total,
      phase: CountdownPhase.paused,
      frozenRemaining: remaining(now),
    );
  }

  Countdown resume(DateTime now) {
    if (!isPaused) return this;
    return Countdown._(
      total: total,
      phase: CountdownPhase.running,
      deadline: now.add(frozenRemaining!),
    );
  }

  /// Pushes the deadline out by [by]. Used by the "+30s" affordance.
  ///
  /// Extending a finished timer restarts it from [by] rather than reviving a
  /// deadline already in the past, which would elapse instantly.
  Countdown extend(Duration by, DateTime now) {
    switch (phase) {
      case CountdownPhase.running:
        return Countdown._(
          total: total + by,
          phase: CountdownPhase.running,
          deadline: deadline!.add(by),
        );
      case CountdownPhase.paused:
        return Countdown._(
          total: total + by,
          phase: CountdownPhase.paused,
          frozenRemaining: frozenRemaining! + by,
        );
      case CountdownPhase.idle:
      case CountdownPhase.finished:
        return Countdown.idle(total).start(by, now);
    }
  }

  /// Marks a running timer done. Used both when the deadline passes and when
  /// the user skips the rest.
  Countdown finish() => Countdown._(
        total: total,
        phase: CountdownPhase.finished,
      );

  /// A distinct instance holding identical values.
  ///
  /// A running countdown's *state* does not change between ticks — only the
  /// clock does, and [remaining] is derived from it. But Riverpod compares by
  /// identity, so republishing the same object notifies nobody and the
  /// on-screen seconds freeze while the timer keeps running underneath.
  Countdown tick() => Countdown._(
        total: total,
        phase: phase,
        deadline: deadline,
        frozenRemaining: frozenRemaining,
      );

  Countdown reset(Duration length) => Countdown.idle(length);
}

/// Elapsed time for the whole workout.
///
/// Derived from [startedAt] rather than accumulated, so a session resumed
/// after the app was killed still reports the true duration.
class SessionClock {
  const SessionClock(this.startedAt);

  final DateTime startedAt;

  Duration elapsed(DateTime now) {
    final span = now.difference(startedAt);
    return span.isNegative ? Duration.zero : span;
  }
}

/// `m:ss`, or `h:mm:ss` once a workout passes an hour.
String formatDuration(Duration d) {
  final total = d.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  return '$minutes:$ss';
}
