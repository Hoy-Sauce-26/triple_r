import 'dart:async';

/// Wall-clock time, injected so timer logic can be tested without waiting.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock a test drives by hand.
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026, 3, 1, 9);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration by) => _now = _now.add(by);
  set current(DateTime value) => _now = value;
}

/// A cancellable repeating callback.
abstract class TickerHandle {
  void cancel();
}

/// Source of periodic callbacks, injected for the same reason as [Clock].
abstract class Ticker {
  TickerHandle start(Duration interval, void Function() onTick);
}

class _TimerHandle implements TickerHandle {
  _TimerHandle(this._timer);
  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

class SystemTicker implements Ticker {
  const SystemTicker();

  @override
  TickerHandle start(Duration interval, void Function() onTick) =>
      _TimerHandle(Timer.periodic(interval, (_) => onTick()));
}

/// A ticker a test pumps manually.
///
/// Deliberately not tied to [FakeClock]: a test advances the clock and then
/// ticks, which is what lets it simulate the case that matters most — the app
/// backgrounded for thirty seconds, delivering one late tick rather than
/// thirty on time.
class FakeTicker implements Ticker {
  final _callbacks = <_FakeHandle>[];

  int get activeCount => _callbacks.length;

  @override
  TickerHandle start(Duration interval, void Function() onTick) {
    final handle = _FakeHandle(this, onTick);
    _callbacks.add(handle);
    return handle;
  }

  /// Fires every live callback once.
  void tick() {
    for (final handle in List.of(_callbacks)) {
      handle.onTick();
    }
  }
}

class _FakeHandle implements TickerHandle {
  _FakeHandle(this._owner, this.onTick);

  final FakeTicker _owner;
  final void Function() onTick;

  @override
  void cancel() => _owner._callbacks.remove(this);
}
