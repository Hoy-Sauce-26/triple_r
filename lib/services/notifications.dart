import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Tells the user their rest is over when they are not looking at the app.
///
/// The wakelock covers the phone-on-the-bench case; this covers the phone-in-
/// the-pocket one. Notifications are *scheduled* at the rest deadline rather
/// than fired by a timer, because a backgrounded Dart isolate is not
/// guaranteed to run at all — the OS delivers this whether or not we are
/// alive to ask.
abstract class RestNotifications {
  Future<void> init();

  /// Requests permission. Safe to call more than once.
  Future<bool> requestPermission();

  /// Schedules the "rest is over" alert for [deadline], replacing any
  /// previously scheduled one.
  Future<void> scheduleRestEnd(DateTime deadline);

  /// Cancels a pending alert — the user skipped the rest, or finished it with
  /// the app in front of them and has already heard the chime.
  Future<void> cancelRestEnd();
}

class PlatformRestNotifications implements RestNotifications {
  PlatformRestNotifications([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _restEndId = 1;
  static const _channelId = 'rest_timer';

  @override
  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    // The device's own zone matters for zonedSchedule; without it a rest
    // deadline lands wherever UTC happens to fall.
    tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly in requestPermission so the prompt appears
          // when the user starts a workout, not at first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<String> _deviceTimeZone() async {
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'UTC';
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
    } catch (error) {
      debugPrint('Triple R: notification permission failed: $error');
    }
    return false;
  }

  @override
  Future<void> scheduleRestEnd(DateTime deadline) async {
    if (!_ready) return;
    await cancelRestEnd();
    if (!deadline.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: _restEndId,
        title: 'Rest complete',
        body: 'Time for your next set.',
        scheduledDate: tz.TZDateTime.from(deadline, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Rest timer',
            channelDescription: 'Fires when a rest period ends.',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      // Exact-alarm permission is revocable on Android 13+, and scheduling is
      // a convenience — the in-app chime is the primary cue.
      debugPrint('Triple R: could not schedule rest alert: $error');
    }
  }

  @override
  Future<void> cancelRestEnd() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _restEndId);
    } catch (error) {
      debugPrint('Triple R: could not cancel rest alert: $error');
    }
  }
}

/// Records scheduling calls instead of talking to the OS.
class FakeRestNotifications implements RestNotifications {
  final scheduled = <DateTime>[];
  int cancelCount = 0;
  bool initialised = false;
  bool permissionGranted = true;

  DateTime? get pending => scheduled.isEmpty ? null : scheduled.last;

  @override
  Future<void> init() async => initialised = true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> scheduleRestEnd(DateTime deadline) async {
    cancelCount++;
    scheduled.add(deadline);
  }

  @override
  Future<void> cancelRestEnd() async {
    cancelCount++;
    scheduled.clear();
  }
}
