import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The ongoing notification that tracks a workout in progress.
///
/// A platform edge like [Alerts] and [Haptics] — an interface with a fake, so
/// the state that drives it can be tested without a plugin.
///
/// Deliberately a *progress* notification rather than an alerting one. It is
/// posted silently and updated in place, so the shade shows where the workout
/// is up to without buzzing on every set.
abstract class WorkoutNotification {
  /// Posts or updates the ongoing notification.
  ///
  /// [progress] and [maxProgress] drive the bar. Deliberately generic rather
  /// than "steps done": while a rest is running the bar tracks the rest,
  /// because that is the thing actually counting down and the reason anyone
  /// glances at the shade mid-workout.
  Future<void> show({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  });

  /// Takes it down. Safe to call when nothing is showing.
  Future<void> clear();
}

/// The real one.
class PlatformWorkoutNotification implements WorkoutNotification {
  PlatformWorkoutNotification(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// One fixed id, because there is only ever one workout and every update
  /// must replace the last rather than stack a new notification behind it.
  static const _id = 1;
  static const channelId = 'workout_progress';

  @override
  Future<void> show({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    final android = AndroidNotificationDetails(
      channelId,
      'Workout progress',
      channelDescription: 'Shows the exercise you are on while a workout runs.',
      // Low: it belongs in the shade, not in a heads-up banner over the
      // screen the user is logging sets on.
      importance: Importance.low,
      priority: Priority.low,
      // Ongoing and un-dismissable: it is a live status, and swiping it away
      // would leave a workout running with nothing pointing back to it.
      ongoing: true,
      autoCancel: false,
      // Without this every update re-alerts, which for a set-by-set workout
      // means a buzz every ninety seconds.
      onlyAlertOnce: true,
      showProgress: true,
      // A zero maximum renders as a full bar rather than an empty one, so
      // floor it at 1 and leave the progress at zero.
      maxProgress: maxProgress < 1 ? 1 : maxProgress,
      progress: progress.clamp(0, maxProgress < 1 ? 1 : maxProgress),
      playSound: false,
      enableVibration: false,
    );

    await _plugin.show(
      _id,
      title,
      body,
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentSound: false,
          presentBanner: false,
          presentList: true,
        ),
      ),
    );
  }

  @override
  Future<void> clear() => _plugin.cancel(_id);
}

/// Records what would have been shown.
class FakeWorkoutNotification implements WorkoutNotification {
  final shown = <String>[];
  int clears = 0;

  /// The most recent notification, or null if none is showing.
  String? get current => shown.isEmpty ? null : shown.last;

  bool isShowing = false;

  @override
  Future<void> show({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    shown.add('$title | $body | $progress/$maxProgress');
    isShowing = true;
  }

  @override
  Future<void> clear() async {
    clears++;
    isShowing = false;
  }
}

/// One that does nothing, for tests that never look at it.
class NoopWorkoutNotification implements WorkoutNotification {
  const NoopWorkoutNotification();

  @override
  Future<void> show({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {}

  @override
  Future<void> clear() async {}
}
