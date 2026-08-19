import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'providers.dart';
import 'screens/app_shell.dart';
import 'services/workout_notification.dart';
import 'state/timer_providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened once here and injected, rather than constructed inside a provider,
  // so tests can swap in AppDatabase.memory() by overriding one thing.
  final database = AppDatabase();
  final notifications = await _initNotifications();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        workoutNotificationProvider.overrideWithValue(notifications),
      ],
      child: const TripleRApp(),
    ),
  );
}

/// Sets up the ongoing-workout notification.
///
/// Permission is requested at launch rather than mid-workout: the first thing
/// the notification would do otherwise is interrupt someone who has just
/// started training. Denial is fine and never blocks anything — the workout
/// runs exactly the same, it simply has nothing in the shade.
Future<WorkoutNotification> _initNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Asked for explicitly below instead, so the prompt is not fired off
        // by the plugin before the app has drawn anything.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  await plugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, sound: false, badge: false);

  return PlatformWorkoutNotification(plugin);
}

class TripleRApp extends StatelessWidget {
  const TripleRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triple R',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const AppShell(),
    );
  }
}
