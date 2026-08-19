import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/countdown.dart';
import '../services/alerts.dart';
import '../services/clock.dart';
import '../services/haptics.dart';
import '../services/screen_wake.dart';
import '../services/workout_notification.dart';

/// All overridden in tests with fakes; the platform implementations here are
/// what `main()` gets by default.
final clockProvider = Provider<Clock>((ref) => const SystemClock());
final tickerProvider = Provider<Ticker>((ref) => const SystemTicker());
final screenWakeProvider = Provider<ScreenWake>((ref) => const PlatformScreenWake());
final hapticsProvider = Provider<Haptics>((ref) => const PlatformHaptics());

/// Overridden in `main()` with the initialised plugin. The default does
/// nothing, so a test that never looks at notifications needs no override and
/// no plugin.
final workoutNotificationProvider =
    Provider<WorkoutNotification>((ref) => const NoopWorkoutNotification());

final alertsProvider = Provider<Alerts>((ref) {
  final alerts = PlatformAlerts();
  ref.onDispose(alerts.dispose);
  return alerts;
});

/// How often running timers re-read the clock.
///
/// Fine enough that the displayed second never looks stuck, coarse enough not
/// to rebuild the tree at frame rate. Accuracy does not depend on it — the
/// remaining time is always derived from the deadline, so a missed tick costs
/// smoothness, never correctness.
const tickInterval = Duration(milliseconds: 200);

/// The rest countdown between sets.
///
/// Owns its own ticker so the chime fires whether or not a widget is watching
/// it. This is a **foreground** cue only: the screen is held awake for the
/// whole session, and there is no scheduled OS notification behind it. An
/// inexact alarm can be deferred by minutes, which is worse than useless for a
/// 90-second rest, and an exact one costs a revocable runtime permission plus
/// a Play Store justification. If the user leaves the app entirely, they get
/// nothing — a deliberate trade, not an oversight.
class RestTimerController extends Notifier<Countdown> {
  TickerHandle? _handle;
  bool _alerted = false;

  @override
  Countdown build() {
    ref.onDispose(_stopTicking);
    return const Countdown.idle(Duration(seconds: 90));
  }

  Clock get _clock => ref.read(clockProvider);

  /// Time left right now. The UI reads this rather than holding a duration,
  /// so a rebuild from any source shows the truth.
  Duration get remaining => state.remaining(_clock.now());

  double get progress => state.progress(_clock.now());

  void start(Duration length) {
    _alerted = false;
    state = state.start(length, _clock.now());
    _startTicking();
  }

  void restart() => start(state.total);

  void pause() {
    if (!state.isRunning) return;
    state = state.pause(_clock.now());
    _stopTicking();
  }

  void resume() {
    if (!state.isPaused) return;
    state = state.resume(_clock.now());
    _startTicking();
  }

  /// The "+30s" affordance — the countdown is a suggestion, not a rule.
  void extend(Duration by) {
    final wasFinished = state.isFinished;
    state = state.extend(by, _clock.now());
    if (state.isRunning) {
      // Extending past a completed timer starts a fresh run, so the alert
      // must be armed again or the second expiry would pass in silence.
      if (wasFinished) _alerted = false;
        _startTicking();
    }
  }

  /// Ends the rest without an alert — the user chose to move on, so chiming
  /// at them would be telling them something they just told us.
  void skip() {
    _alerted = true;
    state = state.finish();
    _stopTicking();
  }

  void reset(Duration length) {
    _alerted = false;
    state = state.reset(length);
    _stopTicking();
  }

  void _startTicking() {
    _handle?.cancel();
    _handle = ref.read(tickerProvider).start(tickInterval, _onTick);
  }

  void _stopTicking() {
    _handle?.cancel();
    _handle = null;
  }

  void _onTick() {
    final now = _clock.now();
    if (state.hasElapsed(now)) {
      if (!_alerted) {
        _alerted = true;
        ref.read(alertsProvider).restComplete();
      }
      state = state.finish();
      _stopTicking();
        return;
    }
    // Republish a fresh instance so watchers recompute `remaining` —
    // reassigning the same object notifies nobody.
    state = state.tick();
  }

}

final restTimerProvider =
    NotifierProvider<RestTimerController, Countdown>(RestTimerController.new);

/// A timed hold inside the warmup — Deadbugs, Support Hold.
///
/// Separate from the rest timer because both can be relevant at once and
/// because finishing a hold is a softer cue than finishing a rest.
class HoldTimerController extends Notifier<Countdown> {
  TickerHandle? _handle;
  bool _alerted = false;

  @override
  Countdown build() {
    ref.onDispose(() => _handle?.cancel());
    return const Countdown.idle(Duration(seconds: 30));
  }

  Clock get _clock => ref.read(clockProvider);

  Duration get remaining => state.remaining(_clock.now());

  void start(Duration length) {
    _alerted = false;
    state = state.start(length, _clock.now());
    _handle?.cancel();
    _handle = ref.read(tickerProvider).start(tickInterval, _onTick);
  }

  void cancel() {
    _alerted = true;
    state = state.reset(state.total);
    _handle?.cancel();
    _handle = null;
  }

  void _onTick() {
    final now = _clock.now();
    if (state.hasElapsed(now)) {
      if (!_alerted) {
        _alerted = true;
        ref.read(alertsProvider).holdComplete();
      }
      state = state.finish();
      _handle?.cancel();
      _handle = null;
      return;
    }
    state = state.tick();
  }
}

final holdTimerProvider =
    NotifierProvider<HoldTimerController, Countdown>(HoldTimerController.new);

/// A count-up timer for the set being worked.
///
/// Separate from [HoldTimerController], which counts *down* to a fixed warmup
/// target. A working set is open-ended: the user holds a plank until they
/// fail, and the number they want logged is however long that turned out to
/// be. Counting down would mean knowing the answer first.
///
/// Reuses [SessionClock] because the shape is identical — an instant plus
/// derived elapsed time — including the reason a fresh instance is published
/// on every tick.
class SetStopwatchController extends Notifier<SessionClock?> {
  TickerHandle? _handle;

  @override
  SessionClock? build() {
    ref.onDispose(_stopTicking);
    return null;
  }

  Clock get _clock => ref.read(clockProvider);

  bool get isRunning => state != null;

  Duration get elapsed => state?.elapsed(_clock.now()) ?? Duration.zero;

  void start() {
    state = SessionClock(_clock.now());
    _handle?.cancel();
    _handle = ref.read(tickerProvider).start(
          tickInterval,
          () => state = state == null ? null : SessionClock(state!.startedAt),
        );
  }

  /// Stops and reports the total, for the caller to write into the field.
  Duration stop() {
    final total = elapsed;
    state = null;
    _stopTicking();
    return total;
  }

  void _stopTicking() {
    _handle?.cancel();
    _handle = null;
  }
}

final setStopwatchProvider =
    NotifierProvider<SetStopwatchController, SessionClock?>(
  SetStopwatchController.new,
);

/// Elapsed workout time. Null when no session is running.
///
/// Holds only the start instant; elapsed time is derived, so a session
/// resumed after the app was killed still reports its true length.
class SessionClockController extends Notifier<SessionClock?> {
  TickerHandle? _handle;

  @override
  SessionClock? build() {
    ref.onDispose(_stopTicking);
    return null;
  }

  Clock get _clock => ref.read(clockProvider);

  Duration get elapsed => state?.elapsed(_clock.now()) ?? Duration.zero;

  /// [startedAt] lets a resumed session carry its original start time rather
  /// than restarting the clock at zero.
  void start({DateTime? startedAt}) {
    state = SessionClock(startedAt ?? _clock.now());
    ref.read(screenWakeProvider).enable();
    _handle?.cancel();
    // A new SessionClock each tick, for the same identity reason the
    // countdowns rebuild themselves.
    _handle = ref.read(tickerProvider).start(
          tickInterval,
          () => state = state == null ? null : SessionClock(state!.startedAt),
        );
  }

  void stop() {
    state = null;
    _stopTicking();
    ref.read(screenWakeProvider).disable();
  }

  void _stopTicking() {
    _handle?.cancel();
    _handle = null;
  }
}

final sessionClockProvider =
    NotifierProvider<SessionClockController, SessionClock?>(
  SessionClockController.new,
);
