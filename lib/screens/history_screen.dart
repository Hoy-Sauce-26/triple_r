import 'package:flutter/material.dart';

import 'placeholder_scaffold.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'History',
      icon: Icons.history_outlined,
      phase: 'Past sessions and charts land in Phase 5.',
    );
  }
}
