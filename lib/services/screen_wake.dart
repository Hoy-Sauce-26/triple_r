import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake during a workout.
///
/// The user sets the phone down between sets and comes back to a running rest
/// timer; a screen that slept through it is the difference between a usable
/// app and a stopwatch they have to babysit.
abstract class ScreenWake {
  Future<void> enable();
  Future<void> disable();
}

class PlatformScreenWake implements ScreenWake {
  const PlatformScreenWake();

  @override
  Future<void> enable() => _set(true);

  @override
  Future<void> disable() => _set(false);

  Future<void> _set(bool value) async {
    try {
      await WakelockPlus.toggle(enable: value);
    } catch (error) {
      // Unsupported on some platforms and revocable on others. Losing the
      // wakelock costs the user a screen tap; crashing costs them the
      // session.
      debugPrint('Triple R: wakelock ${value ? 'enable' : 'disable'} failed: $error');
    }
  }
}

/// Records state instead of touching the platform.
class FakeScreenWake implements ScreenWake {
  bool isEnabled = false;
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enable() async {
    isEnabled = true;
    enableCount++;
  }

  @override
  Future<void> disable() async {
    isEnabled = false;
    disableCount++;
  }
}
