import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/units.dart';

/// Height entry in the units people actually think in.
///
/// Imperial gets two fields, feet and inches. A single total-inches box —
/// which is what this used to be — asks the user to do arithmetic the app is
/// better placed to do, and "71" is a number almost nobody knows about
/// themselves. Metric gets the one centimetre field it wants.
///
/// Reports centimetres upward regardless, since that is what the profile
/// stores; null means "not a usable height yet".
class HeightField extends StatefulWidget {
  const HeightField({
    super.key,
    required this.units,
    required this.onChanged,
    this.initialCm,
    this.helperText,
    this.autofocus = false,
  });

  final UnitSystem units;
  final double? initialCm;
  final ValueChanged<double?> onChanged;
  final String? helperText;
  final bool autofocus;

  @override
  State<HeightField> createState() => _HeightFieldState();
}

class _HeightFieldState extends State<HeightField> {
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _cm = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cm = widget.initialCm;
    if (cm != null) {
      _cm.text = '${cm.round()}';
      final h = cmToFeetInches(cm);
      _feet.text = '${h.feet}';
      _inches.text = '${h.inches}';
    }
    for (final c in [_feet, _inches, _cm]) {
      c.addListener(_emit);
    }
  }

  @override
  void dispose() {
    for (final c in [_feet, _inches, _cm]) {
      c.removeListener(_emit);
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_value());

  double? _value() {
    if (widget.units == UnitSystem.metric) {
      final cm = double.tryParse(_cm.text.trim());
      return cm != null && cm > 0 ? cm : null;
    }
    // Inches alone is a legitimate entry (a child, or someone correcting just
    // the inches), so only the pair being empty means "nothing given".
    final feet = int.tryParse(_feet.text.trim()) ?? 0;
    final inches = int.tryParse(_inches.text.trim()) ?? 0;
    if (feet <= 0 && inches <= 0) return null;
    return feetInchesToCm(feet, inches);
  }

  static final _digitsOnly = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  @override
  Widget build(BuildContext context) {
    if (widget.units == UnitSystem.metric) {
      return TextField(
        controller: _cm,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.number,
        inputFormatters: [_digitsOnly],
        decoration: InputDecoration(
          labelText: 'Height',
          suffixText: 'cm',
          border: const OutlineInputBorder(),
          helperText: widget.helperText,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _feet,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [_digitsOnly],
            decoration: InputDecoration(
              labelText: 'Height',
              suffixText: 'ft',
              border: const OutlineInputBorder(),
              helperText: widget.helperText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _inches,
            keyboardType: TextInputType.number,
            inputFormatters: [_digitsOnly],
            decoration: const InputDecoration(
              labelText: ' ',
              suffixText: 'in',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
