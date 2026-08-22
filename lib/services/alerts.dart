import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The cue when a rest period or a timed hold ends.
///
/// An interface because everything below it is a platform channel — a test
/// asserts the alert *fired*, without an audio device or a vibrator.
abstract class Alerts {
  Future<void> restComplete();

  /// One of the five blips leading into [restComplete].
  ///
  /// Deliberately a separate cue rather than a quieter [restComplete]: the
  /// countdown is a *warning* and the end of the rest is an *instruction*, and
  /// a user with the phone in a pocket has to be able to tell them apart
  /// without looking.
  Future<void> restCountdown();

  Future<void> holdComplete();
  Future<void> dispose();
}

/// Plays a chime and fires a haptic.
///
/// Sound and vibration are complementary rather than redundant: a phone
/// face-down on a gym floor is heard, a phone on silent in a pocket is felt.
class PlatformAlerts implements Alerts {
  PlatformAlerts({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _configured = false;

  static final _chime = AssetSource('audio/rest_complete.wav');
  static final _blip = AssetSource('audio/rest_tick.wav');

  /// Configures the audio session so the cue behaves like a workout app's:
  /// it ducks music rather than stopping it, and it still sounds when the
  /// ringer switch is silenced, because the whole point is the user is not
  /// looking at the screen.
  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setAudioContext(
      AudioContext(
        // AudioContextIOS is not const — it asserts that duckOthers is only
        // paired with a playback-style category.
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
  }

  Future<void> _fire({
    required bool heavy,
    AssetSource? sound,
    bool haptic = true,
  }) async {
    try {
      await _configure();
      await _player.stop();
      await _player.play(sound ?? _chime);
    } catch (error) {
      // A missing audio route or a denied session must not take down the
      // workout — the haptic below still lands, and the timer is unaffected.
      debugPrint('Triple R: chime failed: $error');
    }
    if (!haptic) return;
    await (heavy ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact());
  }

  @override
  Future<void> restComplete() => _fire(heavy: true);

  /// Sound only, and the quieter sound at that. A buzz per second for the
  /// five seconds before the rest ends is indistinguishable from the phone
  /// being wrong about something.
  @override
  Future<void> restCountdown() =>
      _fire(heavy: false, sound: _blip, haptic: false);

  @override
  Future<void> holdComplete() => _fire(heavy: false);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Records calls instead of making noise.
class RecordingAlerts implements Alerts {
  final restCompletions = <DateTime>[];
  final restCountdowns = <DateTime>[];
  final holdCompletions = <DateTime>[];

  int get total => restCompletions.length + holdCompletions.length;

  @override
  Future<void> restComplete() async => restCompletions.add(DateTime.now());

  @override
  Future<void> restCountdown() async => restCountdowns.add(DateTime.now());

  @override
  Future<void> holdComplete() async => holdCompletions.add(DateTime.now());

  @override
  Future<void> dispose() async {}
}
