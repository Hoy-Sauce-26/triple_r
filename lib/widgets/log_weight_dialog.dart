import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/units.dart';
import '../providers.dart';
import '../state/timer_providers.dart';

/// Logs a body weight, and height the first time round.
///
/// Height is asked for here rather than in Settings because it is only ever
/// entered once, and the moment someone is already typing their weight is the
/// one moment they will tolerate a second field.
class LogWeightDialog extends ConsumerStatefulWidget {
  const LogWeightDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const LogWeightDialog(),
      );

  @override
  ConsumerState<LogWeightDialog> createState() => _LogWeightDialogState();
}

class _LogWeightDialogState extends ConsumerState<LogWeightDialog> {
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitSystemProvider);
    final profile = ref.watch(profileProvider).value;
    final needsHeight = profile?.heightCm == null;
    final imperial = units == UnitSystem.imperial;

    return AlertDialog(
      title: const Text('Log weight'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weight,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Weight',
              suffixText: units.weightSuffix,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(units, needsHeight),
          ),
          if (needsHeight) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Height (optional)',
                suffixText: imperial ? 'in' : 'cm',
                border: const OutlineInputBorder(),
                helperText: 'Asked once — it does not change.',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _save(units, needsHeight),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save(UnitSystem units, bool needsHeight) async {
    final entered = double.tryParse(_weight.text.trim());
    if (entered == null || entered <= 0) {
      setState(() => _error = 'Enter a weight');
      return;
    }

    final db = ref.read(databaseProvider);
    final now = ref.read(clockProvider).now();

    await db.addBodyWeight(
      // Second-resolution id, so logging twice in one day keeps both entries
      // but a double-tap on Save does not create two.
      id: 'bw-${now.toIso8601String().split('.').first}',
      weightKg: fromDisplayWeight(entered, units),
      recordedAt: now,
    );

    if (needsHeight) {
      final height = double.tryParse(_height.text.trim());
      if (height != null && height > 0) {
        await db.updateProfile(
          UserProfilesCompanion(
            // Inches in imperial: nobody knows their height in centimetres in
            // a country that measures it in feet.
            heightCm: Value(
              units == UnitSystem.imperial ? height * 2.54 : height,
            ),
          ),
        );
      }
    }

    if (mounted) Navigator.of(context).pop();
  }
}
