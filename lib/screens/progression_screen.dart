import 'package:flutter/material.dart';

import 'placeholder_scaffold.dart';

class ProgressionScreen extends StatelessWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Progression',
      icon: Icons.stacked_line_chart_outlined,
      phase: 'The nine progression paths land in Phase 1.',
    );
  }
}
