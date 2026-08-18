import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Touch feedback for actions the user takes, as opposed to the chime in
/// [Alerts] which fires when a *timer* finishes.
///
/// Kept behind an interface for the same reason as the other platform edges:
/// `HapticFeedback` is a channel call that throws in the test VM, and a test
/// should be able to assert that logging a set confirmed itself.
///
/// The vocabulary is deliberately small. Buzzing at every tap trains people to
/// ignore it, which costs the two moments that genuinely matter — confirming a
/// set logged when you are not looking, and warning before something
/// destructive.
abstract class Haptics {
  /// A set was recorded, an item ticked off. The common case.
  Future<void> confirm();

  /// Something irreversible is about to be offered: ending a workout early,
  /// replacing every record on the device.
  Future<void> warn();

  /// A step boundary — moving to the next exercise, a progression advancing.
  Future<void> transition();
}

class PlatformHaptics implements Haptics {
  const PlatformHaptics();

  @override
  Future<void> confirm() => _fire(HapticFeedback.selectionClick);

  @override
  Future<void> warn() => _fire(HapticFeedback.heavyImpact);

  @override
  Future<void> transition() => _fire(HapticFeedback.lightImpact);

  Future<void> _fire(Future<void> Function() effect) async {
    try {
      await effect();
    } catch (error) {
      // Devices without a vibrator, and users who have turned system haptics
      // off, both land here. Feedback is a courtesy; failing it must never
      // interrupt what the user was actually doing.
      debugPrint('Triple R: haptic failed: $error');
    }
  }
}

/// Counts calls instead of buzzing.
@visibleForTesting
class RecordingHaptics implements Haptics {
  int confirmCount = 0;
  int warnCount = 0;
  int transitionCount = 0;

  int get total => confirmCount + warnCount + transitionCount;

  @override
  Future<void> confirm() async => confirmCount++;

  @override
  Future<void> warn() async => warnCount++;

  @override
  Future<void> transition() async => transitionCount++;
}

/// Does nothing, for tests that are not about feedback at all.
@visibleForTesting
class SilentHaptics implements Haptics {
  const SilentHaptics();

  @override
  Future<void> confirm() async {}

  @override
  Future<void> warn() async {}

  @override
  Future<void> transition() async {}
}
