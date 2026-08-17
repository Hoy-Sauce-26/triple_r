import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'progression_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav host for the four top-level destinations.
///
/// The Active Workout screen is deliberately not one of them — it is pushed
/// full-screen over this shell, because leaving a workout half-logged by
/// tapping a nav tab is not something the UI should make easy.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.stacked_line_chart_outlined),
      selectedIcon: Icon(Icons.stacked_line_chart),
      label: 'Progression',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack so each tab keeps its scroll position and state across
      // switches, rather than rebuilding from scratch.
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          ProgressionScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
