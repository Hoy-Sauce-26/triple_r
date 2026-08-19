import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/units.dart';
import '../providers.dart';
import '../state/timer_providers.dart';

/// Logs a body weight.
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
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitSystemProvider);

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
            onSubmitted: (_) => _save(units),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _save(units),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save(UnitSystem units) async {
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

    if (mounted) Navigator.of(context).pop();
  }
}
