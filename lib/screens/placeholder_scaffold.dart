import 'package:flutter/material.dart';

/// Stand-in for a screen that lands in a later phase.
///
/// It states which phase fills it in, so running the Phase 0 skeleton looks
/// unmistakably unfinished rather than looking broken.
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.phase,
  });

  final String title;
  final IconData icon;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 16),
              Text(
                phase,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
