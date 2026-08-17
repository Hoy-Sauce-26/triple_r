import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Triple R')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next session', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Not scheduled yet',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick your starting exercises on the Progression tab, and '
                    'this will show what is coming up.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    // Wired up in Phase 4.
                    onPressed: null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Begin workout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
