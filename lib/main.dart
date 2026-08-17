import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'providers.dart';
import 'screens/app_shell.dart';
import 'services/notifications.dart';
import 'state/timer_providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened once here and injected, rather than constructed inside a provider,
  // so tests can swap in AppDatabase.memory() by overriding one thing.
  final database = AppDatabase();

  // Set up the notification channel and time zone now, but do not ask for
  // permission — that prompt belongs at the moment the user starts a workout,
  // where it has an obvious reason, not on a cold first launch.
  final notifications = PlatformRestNotifications();
  await notifications.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        restNotificationsProvider.overrideWithValue(notifications),
      ],
      child: const TripleRApp(),
    ),
  );
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
