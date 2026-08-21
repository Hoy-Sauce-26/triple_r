import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/backup.dart';
import '../domain/units.dart';
import '../providers.dart';
import '../state/timer_providers.dart';

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
            _RestSetting(
              label: 'Rest between pair exercises',
              seconds: p.defaultPairRestSeconds,
              onChanged: (v) => ref.read(databaseProvider).updateProfile(
                    UserProfilesCompanion(defaultPairRestSeconds: Value(v)),
                  ),
            ),
            _RestSetting(
              label: 'Rest between core exercises',
              seconds: p.defaultTripletRestSeconds,
              onChanged: (v) => ref.read(databaseProvider).updateProfile(
                    UserProfilesCompanion(defaultTripletRestSeconds: Value(v)),
                  ),
            ),
            _IncrementSetting(
              units: ref.watch(unitSystemProvider),
              incrementKg: p.loadIncrementKg,
              onChanged: (kg) => ref.read(databaseProvider).updateProfile(
                    UserProfilesCompanion(loadIncrementKg: Value(kg)),
                  ),
            ),
            const Divider(height: 32),
            const _SectionHeader('Backup'),
            const _BackupSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

}

/// Rest length, adjusted in 15-second steps.
///
/// A slider would imply more precision than anyone wants here — rest is set
/// once and then left alone, and the RR's own numbers are round.
class _RestSetting extends StatelessWidget {
  const _RestSetting({
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  static const _step = 15;
  static const _min = 30;
  static const _max = 300;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed:
                seconds > _min ? () => onChanged(seconds - _step) : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${seconds}s',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed:
                seconds < _max ? () => onChanged(seconds + _step) : null,
          ),
        ],
      ),
    );
  }
}

/// The load step the "add weight?" prompt offers by default.
///
/// A fixed list rather than a free field, for the same reason rest moves in
/// 15-second steps: these are the plate pairs that exist, and the answer is
/// decided by what is in the user's gym rather than by fine-tuning.
///
/// An exercise that has already been moved by some other amount keeps that
/// amount — the app remembers a step per exercise, and this is the fallback
/// for the ones it has no memory of yet. The subtitle says so, because
/// otherwise changing this and seeing one exercise ignore it looks broken.
class _IncrementSetting extends StatelessWidget {
  const _IncrementSetting({
    required this.units,
    required this.incrementKg,
    required this.onChanged,
  });

  final UnitSystem units;

  /// Null until the user picks one, meaning "whatever suits the units".
  final double? incrementKg;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = incrementChoices(units);
    final current = toDisplayWeight(
      incrementKg ?? seedIncrementKg(units),
      units,
    );
    // Matched loosely: the stored value is kilograms, so an imperial 2.5 lb
    // comes back as 2.4999999… and an equality test would select nothing.
    final selected = choices.firstWhere(
      (c) => (c - current).abs() < 0.01,
      orElse: () => -1,
    );

    return ListTile(
      title: const Text('Weight added when you progress'),
      subtitle: Text(
        'The step offered when an exercise is ready for more. Exercises you '
        'have already moved by a different amount keep theirs.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: DropdownButton<double>(
        value: selected < 0 ? null : selected,
        hint: Text('${current.toStringAsFixed(2)} ${units.weightSuffix}'),
        items: [
          for (final choice in choices)
            DropdownMenuItem(
              value: choice,
              child: Text(
                '${choice == choice.roundToDouble() ? choice.toStringAsFixed(0) : choice}'
                ' ${units.weightSuffix}',
              ),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          onChanged(fromDisplayWeight(value, units));
        },
      ),
      isThreeLine: true,
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

/// Export and import.
///
/// Import replaces everything, so the confirmation names what is about to be
/// destroyed and what will take its place. "Are you sure?" is not a warning;
/// "this deletes 47 sessions" is.
class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Export'),
          subtitle: const Text('Everything, as one JSON file.'),
          enabled: !_busy,
          onTap: _busy ? null : _export,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Import'),
          subtitle: const Text('Replaces all data on this device.'),
          enabled: !_busy,
          onTap: _busy ? null : _import,
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final now = ref.read(clockProvider).now();
      final json = await exportBackup(db, now: now);
      await ref.read(backupFilesProvider).share(backupFileName(now), json);
    } catch (error) {
      _say('Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(backupFilesProvider).pickAndRead();
      if (json == null) return; // Cancelled.

      // Parsed before anything is destroyed, so a bad file is rejected while
      // the user still has their data.
      final incoming = inspectBackup(json);

      // Counted straight from the database, not from sessionHistoryProvider.
      // This screen never watches that provider, and Riverpod auto-disposes
      // one with no listeners — so `read` returns AsyncLoading and the count
      // comes back 0. A confirmation that promises to delete "0 sessions"
      // immediately before wiping a year of training is the one place in the
      // app where being wrong is unforgivable.
      final db = ref.read(databaseProvider);
      final existing = (await db.select(db.workoutSessions).get()).length;

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace everything?'),
          content: Text(
            'This deletes the $existing session${existing == 1 ? '' : 's'} on '
            'this device and replaces them with '
            '${incoming.sessionCount} from the backup'
            '${incoming.exportedAt == null ? '' : ' taken '
                '${incoming.exportedAt!.day}/${incoming.exportedAt!.month}/'
                '${incoming.exportedAt!.year}'}.\n\n'
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await restoreBackup(ref.read(databaseProvider), json);
      _say('Imported ${incoming.sessionCount} sessions.');
    } on BackupError catch (error) {
      _say(error.message);
    } catch (error) {
      _say('Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
