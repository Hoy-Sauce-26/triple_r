import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/domain/countdown.dart';

void main() {
  final t0 = DateTime(2026, 3, 1, 9);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  const ninety = Duration(seconds: 90);

  group('lifecycle', () {
    test('starts idle showing the full length', () {
      const c = Countdown.idle(ninety);
      expect(c.isIdle, isTrue);
      expect(c.remaining(t0), ninety);
      expect(c.progress(t0), 0);
    });

    test('counts down from the deadline', () {
      final c = const Countdown.idle(ninety).start(ninety, t0);
      expect(c.isRunning, isTrue);
      expect(c.remaining(t0), ninety);
      expect(c.remaining(at(30)), const Duration(seconds: 60));
      expect(c.remaining(at(89)), const Duration(seconds: 1));
    });

    test('never reports negative time left', () {
      final c = const Countdown.idle(ninety).start(ninety, t0);
      expect(c.remaining(at(200)), Duration.zero);
    });

    test('progress runs 0 to 1 and clamps', () {
      final c = const Countdown.idle(ninety).start(ninety, t0);
      expect(c.progress(t0), 0);
      expect(c.progress(at(45)), closeTo(0.5, 1e-9));
      expect(c.progress(at(90)), 1);
      expect(c.progress(at(500)), 1);
    });
  });

  group('elapsing', () {
    test('hasElapsed flips exactly at the deadline', () {
      final c = const Countdown.idle(ninety).start(ninety, t0);
      expect(c.hasElapsed(at(89)), isFalse);
      expect(c.hasElapsed(at(90)), isTrue);
      expect(c.hasElapsed(at(91)), isTrue);
    });

    test('survives a long gap between observations', () {
      // The case a decrementing timer gets wrong: the phone sleeps for five
      // minutes and delivers one late tick instead of hundreds on time.
      final c = const Countdown.idle(ninety).start(ninety, t0);
      expect(c.hasElapsed(at(300)), isTrue);
      expect(c.remaining(at(300)), Duration.zero);
    });

    test('a finished timer is not still elapsing', () {
      // Otherwise the alert would re-fire on every subsequent tick.
      final c = const Countdown.idle(ninety).start(ninety, t0).finish();
      expect(c.isFinished, isTrue);
      expect(c.hasElapsed(at(200)), isFalse);
      expect(c.remaining(at(200)), Duration.zero);
    });

    test('an idle timer never elapses', () {
      expect(const Countdown.idle(ninety).hasElapsed(at(500)), isFalse);
    });
  });

  group('pause and resume', () {
    test('freezes the remaining time', () {
      final c = const Countdown.idle(ninety).start(ninety, t0).pause(at(30));
      expect(c.isPaused, isTrue);
      expect(c.remaining(at(30)), const Duration(seconds: 60));
      // Still 60 seconds later — a paused timer must ignore the clock.
      expect(c.remaining(at(500)), const Duration(seconds: 60));
    });

    test('resuming pushes the deadline out by the time spent paused', () {
      final paused = const Countdown.idle(ninety).start(ninety, t0).pause(at(30));
      final resumed = paused.resume(at(100));
      expect(resumed.isRunning, isTrue);
      expect(resumed.remaining(at(100)), const Duration(seconds: 60));
      expect(resumed.hasElapsed(at(160)), isTrue);
    });

    test('pausing an idle or finished timer does nothing', () {
      const idle = Countdown.idle(ninety);
      expect(idle.pause(t0).isIdle, isTrue);
      final finished = idle.start(ninety, t0).finish();
      expect(finished.pause(t0).isFinished, isTrue);
    });

    test('resuming a running timer does nothing', () {
      final running = const Countdown.idle(ninety).start(ninety, t0);
      expect(running.resume(at(10)).deadline, running.deadline);
    });
  });

  group('extending', () {
    const thirty = Duration(seconds: 30);

    test('pushes a running deadline out and grows the total', () {
      final c = const Countdown.idle(ninety).start(ninety, t0).extend(thirty, at(10));
      expect(c.remaining(at(10)), const Duration(seconds: 110));
      expect(c.total, const Duration(seconds: 120));
      expect(c.progress(at(10)), closeTo(10 / 120, 1e-9));
    });

    test('extends a paused timer without resuming it', () {
      final c = const Countdown.idle(ninety)
          .start(ninety, t0)
          .pause(at(30))
          .extend(thirty, at(30));
      expect(c.isPaused, isTrue);
      expect(c.remaining(at(30)), const Duration(seconds: 90));
    });

    test('extending a finished timer starts a fresh run', () {
      // Reviving the old deadline would put it in the past and elapse
      // instantly, which is not what "+30s" means.
      final c = const Countdown.idle(ninety).start(ninety, t0).finish();
      final extended = c.extend(thirty, at(120));
      expect(extended.isRunning, isTrue);
      expect(extended.remaining(at(120)), thirty);
      expect(extended.hasElapsed(at(149)), isFalse);
      expect(extended.hasElapsed(at(150)), isTrue);
    });
  });

  group('tick', () {
    test('produces a distinct instance with identical values', () {
      // Riverpod compares by identity, so republishing the same object
      // notifies nobody and the on-screen seconds freeze while the timer runs
      // on underneath. Only a widget test catches that, so this pins the
      // property the fix depends on.
      final running = const Countdown.idle(ninety).start(ninety, t0);
      final ticked = running.tick();

      expect(identical(ticked, running), isFalse);
      expect(ticked.phase, running.phase);
      expect(ticked.total, running.total);
      expect(ticked.deadline, running.deadline);
      expect(ticked.remaining(at(30)), running.remaining(at(30)));
    });

    test('preserves a paused timer’s frozen remainder', () {
      final paused = const Countdown.idle(ninety).start(ninety, t0).pause(at(30));
      final ticked = paused.tick();
      expect(ticked.isPaused, isTrue);
      expect(ticked.remaining(at(999)), const Duration(seconds: 60));
    });
  });

  group('session clock', () {
    test('derives elapsed time from the start instant', () {
      const clock = SessionClock.new;
      final session = clock(t0);
      expect(session.elapsed(t0), Duration.zero);
      expect(session.elapsed(at(3600)), const Duration(hours: 1));
    });

    test('a resumed session reports its original length', () {
      // Started, app killed, reopened 20 minutes later.
      final session = SessionClock(t0);
      expect(session.elapsed(at(1200)), const Duration(minutes: 20));
    });

    test('a clock skewed backwards reports zero, not negative time', () {
      final session = SessionClock(at(100));
      expect(session.elapsed(t0), Duration.zero);
    });
  });

  group('formatting', () {
    test('renders m:ss below an hour', () {
      expect(formatDuration(Duration.zero), '0:00');
      expect(formatDuration(const Duration(seconds: 9)), '0:09');
      expect(formatDuration(const Duration(seconds: 90)), '1:30');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('adds hours once a workout passes one', () {
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 5, seconds: 3)),
        '1:05:03',
      );
    });
  });
}
