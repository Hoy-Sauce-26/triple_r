import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'providers.dart';
import 'screens/app_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened once here and injected, rather than constructed inside a provider,
  // so tests can swap in AppDatabase.memory() by overriding one thing.
  final database = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
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
