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

  /// Tabs the user has actually opened.
  ///
  /// An `IndexedStack` builds every child, so all four screens used to mount
  /// and subscribe at launch — including the two analytics tabs, whose
  /// providers watch whole tables. Every set logged during a workout then
  /// re-ran chart maths for screens nobody had ever looked at. Building a tab
  /// only once it has been visited keeps the state-preserving behaviour for
  /// tabs in use and costs nothing for tabs that are not.
  final _visited = <int>{0};

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

  static const _screens = <Widget>[
    DashboardScreen(),
    ProgressionScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack so a tab already opened keeps its scroll position and
      // state across switches, rather than rebuilding from scratch.
      body: IndexedStack(
        index: _index,
        children: [
          for (final (i, screen) in _screens.indexed)
            _visited.contains(i) ? screen : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
      ),
    );
  }
}
