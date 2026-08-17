import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings.\n$e')),
        data: (p) => ListView(
          children: [
            const _SectionHeader('Units'),
            RadioGroup<String>(
              groupValue: p.unitSystem,
              onChanged: (value) {
                if (value == null) return;
                ref.read(databaseProvider).updateProfile(
                      UserProfilesCompanion(unitSystem: Value(value)),
                    );
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'imperial',
                    title: Text('Imperial'),
                    subtitle: Text('pounds, feet and inches'),
                  ),
                  RadioListTile<String>(
                    value: 'metric',
                    title: Text('Metric'),
                    subtitle: Text('kilograms, centimetres'),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            const _SectionHeader('Workout'),
            SwitchListTile(
              value: p.rotatePairOrder,
              title: const Text('Rotate pair order'),
              subtitle: const Text(
                'Vary which pair comes first each session, so the same '
                'exercises are not always done fresh.',
              ),
              onChanged: (value) {
                ref.read(databaseProvider).updateProfile(
                      UserProfilesCompanion(rotatePairOrder: Value(value)),
                    );
              },
            ),
            ListTile(
              title: const Text('Rest between pair exercises'),
              trailing: Text('${p.defaultPairRestSeconds}s'),
              enabled: false,
            ),
            ListTile(
              title: const Text('Rest between core exercises'),
              trailing: Text('${p.defaultTripletRestSeconds}s'),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
