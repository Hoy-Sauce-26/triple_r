import 'package:flutter/material.dart';

import '../domain/units.dart';

/// Corrects a set that has already been logged.
///
/// Replaces the single-field prompt this used to share with every other
/// numeric input. Weight is per set in the schema — each row carries its own
/// `weight_kg` — but there was no way to edit it after the fact, so a set
/// logged at the wrong load stayed wrong and fed the progression evaluation
/// that way.
class EditSetResult {
  const EditSetResult({required this.value, required this.weightKg});

  final int value;
  final double weightKg;
}

class EditSetDialog extends StatefulWidget {
  const EditSetDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.timed,
    required this.units,
    this.initialWeightKg,
  });

  final String title;
  final int initialValue;
  final bool timed;
  final UnitSystem units;

  /// Null for an exercise that carries no load, which hides the weight field.
  final double? initialWeightKg;

  @override
  State<EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<EditSetDialog> {
  late final _value = TextEditingController(text: '${widget.initialValue}');
  late final _weight = TextEditingController(
    text: widget.initialWeightKg == null || widget.initialWeightKg == 0
        ? ''
        : formatWeight(widget.initialWeightKg!, widget.units, withSuffix: false),
  );

  @override
  void dispose() {
    _value.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_value.text.trim());
    if (parsed == null || parsed < 0) return;
    Navigator.of(context).pop(
      EditSetResult(
        value: parsed,
        weightKg: fromDisplayWeight(double.tryParse(_weight.text) ?? 0, widget.units),
      ),
    );
  }

  void _selectAll(TextEditingController c) =>
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: TextInputType.number,
            onTap: () => _selectAll(_value),
            decoration: InputDecoration(
              labelText: widget.timed ? 'Seconds' : 'Reps',
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.initialWeightKg != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: () => _selectAll(_weight),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Added weight (${widget.units.weightSuffix})',
                border: const OutlineInputBorder(),
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
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
