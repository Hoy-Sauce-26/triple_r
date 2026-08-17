import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/domain/countdown.dart';
import 'package:triple_r/services/alerts.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/services/notifications.dart';
import 'package:triple_r/services/screen_wake.dart';
import 'package:triple_r/state/timer_providers.dart';

/// The timer controllers, driven by a fake clock and a hand-pumped ticker so
/// a ninety-second rest takes no time to test.
void main() {
  late FakeClock clock;
  late FakeTicker ticker;
  late RecordingAlerts alerts;
  late FakeScreenWake wake;
  late FakeRestNotifications notifications;
  late ProviderContainer container;

  setUp(() {
    clock = FakeClock();
    ticker = FakeTicker();
    alerts = RecordingAlerts();
    wake = FakeScreenWake();
    notifications = FakeRestNotifications();
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        tickerProvider.overrideWithValue(ticker),
        alertsProvider.overrideWithValue(alerts),
        screenWakeProvider.overrideWithValue(wake),
        restNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    // Riverpod 3 auto-disposes unlistened providers, which would tear the
    // controller down between calls and drop its ticker.
    container.listen(restTimerProvider, (_, _) {});
    container.listen(holdTimerProvider, (_, _) {});
    container.listen(sessionClockProvider, (_, _) {});
  });

  // A closure, not `tearDown(container.dispose)` — a tear-off is evaluated
  // here, before setUp assigns the late field.
  tearDown(() => container.dispose());

  RestTimerController rest() => container.read(restTimerProvider.notifier);
  HoldTimerController hold() => container.read(holdTimerProvider.notifier);
  SessionClockController session() =>
      container.read(sessionClockProvider.notifier);

  /// Advances the clock and delivers a single tick, the way a real timer does.
  void elapse(Duration by) {
    clock.advance(by);
    ticker.tick();
  }

  group('rest timer', () {
    test('counts down and fires the chime exactly once', () {
      rest().start(const Duration(seconds: 90));
      expect(container.read(restTimerProvider).isRunning, isTrue);

      elapse(const Duration(seconds: 45));
      expect(rest().remaining, const Duration(seconds: 45));
      expect(alerts.total, 0);

      elapse(const Duration(seconds: 45));
      expect(alerts.restCompletions, hasLength(1));
      expect(container.read(restTimerProvider).isFinished, isTrue);

      // Nothing left ticking, and no second chime.
      ticker.tick();
      expect(alerts.restCompletions, hasLength(1));
    });

    test('stops ticking once finished', () {
      rest().start(const Duration(seconds: 10));
      expect(ticker.activeCount, 1);
      elapse(const Duration(seconds: 10));
      expect(ticker.activeCount, 0, reason: 'a finished timer should not tick');
    });

    test('a single late tick still fires the alert', () {
      // The phone slept through the whole rest period.
      rest().start(const Duration(seconds: 90));
      elapse(const Duration(minutes: 5));
      expect(alerts.restCompletions, hasLength(1));
      expect(rest().remaining, Duration.zero);
    });

    test('pausing freezes the countdown and cancels the scheduled alert', () {
      rest().start(const Duration(seconds: 90));
      elapse(const Duration(seconds: 30));
      rest().pause();

      final cancelsAfterPause = notifications.cancelCount;
      clock.advance(const Duration(minutes: 10));
      expect(rest().remaining, const Duration(seconds: 60));
      expect(notifications.pending, isNull);
      expect(ticker.activeCount, 0);

      rest().resume();
      expect(notifications.cancelCount, greaterThan(cancelsAfterPause - 1));
      expect(rest().remaining, const Duration(seconds: 60));

      elapse(const Duration(seconds: 60));
      expect(alerts.restCompletions, hasLength(1));
    });

    test('skipping ends the rest without chiming', () {
      // The user already decided to move on; telling them so is noise.
      rest().start(const Duration(seconds: 90));
      elapse(const Duration(seconds: 10));
      rest().skip();

      expect(container.read(restTimerProvider).isFinished, isTrue);
      expect(alerts.total, 0);
      expect(notifications.pending, isNull);

      elapse(const Duration(seconds: 300));
      expect(alerts.total, 0, reason: 'a skipped rest never chimes');
    });

    test('+30s pushes the deadline out', () {
      rest().start(const Duration(seconds: 90));
      elapse(const Duration(seconds: 80));
      rest().extend(const Duration(seconds: 30));

      elapse(const Duration(seconds: 10));
      expect(alerts.total, 0, reason: 'the original deadline has passed');
      expect(rest().remaining, const Duration(seconds: 30));

      elapse(const Duration(seconds: 30));
      expect(alerts.restCompletions, hasLength(1));
    });

    test('extending after the chime re-arms it', () {
      rest().start(const Duration(seconds: 10));
      elapse(const Duration(seconds: 10));
      expect(alerts.restCompletions, hasLength(1));

      rest().extend(const Duration(seconds: 30));
      elapse(const Duration(seconds: 30));
      expect(
        alerts.restCompletions,
        hasLength(2),
        reason: 'a fresh run must chime again',
      );
    });

    test('schedules a notification for the deadline', () {
      rest().start(const Duration(seconds: 90));
      expect(
        notifications.pending,
        clock.now().add(const Duration(seconds: 90)),
      );
    });

    test('cancels the notification when the rest completes in-app', () {
      // The user heard the chime; a notification afterwards is duplicate.
      rest().start(const Duration(seconds: 30));
      elapse(const Duration(seconds: 30));
      expect(notifications.pending, isNull);
    });

    test('restart reuses the configured length', () {
      rest().start(const Duration(seconds: 60));
      elapse(const Duration(seconds: 60));
      rest().restart();
      expect(rest().remaining, const Duration(seconds: 60));
      expect(container.read(restTimerProvider).isRunning, isTrue);
    });

    test('reset returns it to idle at a new length', () {
      rest().start(const Duration(seconds: 90));
      rest().reset(const Duration(seconds: 60));
      expect(container.read(restTimerProvider).isIdle, isTrue);
      expect(rest().remaining, const Duration(seconds: 60));
      expect(ticker.activeCount, 0);
    });
  });

  group('hold timer', () {
    test('fires the softer cue when a hold ends', () {
      hold().start(const Duration(seconds: 30));
      elapse(const Duration(seconds: 30));

      expect(alerts.holdCompletions, hasLength(1));
      expect(alerts.restCompletions, isEmpty);
      expect(container.read(holdTimerProvider).isFinished, isTrue);
    });

    test('cancelling mid-hold stays silent', () {
      hold().start(const Duration(seconds: 30));
      elapse(const Duration(seconds: 10));
      hold().cancel();

      expect(container.read(holdTimerProvider).isIdle, isTrue);
      elapse(const Duration(seconds: 60));
      expect(alerts.total, 0);
    });

    test('starting a second hold replaces the first', () {
      // Warmup holds are done one at a time; two live tickers would chime
      // over each other.
      hold().start(const Duration(seconds: 30));
      hold().start(const Duration(seconds: 60));
      expect(ticker.activeCount, 1);

      elapse(const Duration(seconds: 60));
      expect(alerts.holdCompletions, hasLength(1));
    });
  });

  group('session clock', () {
    test('is null until a workout starts', () {
      expect(container.read(sessionClockProvider), isNull);
      expect(session().elapsed, Duration.zero);
    });

    test('tracks elapsed time and holds the screen awake', () {
      session().start();
      expect(wake.isEnabled, isTrue);

      elapse(const Duration(minutes: 12));
      expect(session().elapsed, const Duration(minutes: 12));

      session().stop();
      expect(wake.isEnabled, isFalse);
      expect(container.read(sessionClockProvider), isNull);
      expect(ticker.activeCount, 0);
    });

    test('a resumed session keeps its original start time', () {
      // Reopened 20 minutes after the workout began.
      final started = clock.now();
      clock.advance(const Duration(minutes: 20));
      session().start(startedAt: started);

      expect(session().elapsed, const Duration(minutes: 20));
    });

    test('stopping clears any pending rest notification', () {
      session().start();
      rest().start(const Duration(seconds: 90));
      expect(notifications.pending, isNotNull);

      session().stop();
      expect(notifications.pending, isNull);
    });
  });

  group('display formatting', () {
    test('the rest timer renders as m:ss while counting down', () {
      rest().start(const Duration(seconds: 90));
      expect(formatDuration(rest().remaining), '1:30');
      elapse(const Duration(seconds: 31));
      expect(formatDuration(rest().remaining), '0:59');
    });
  });
}
