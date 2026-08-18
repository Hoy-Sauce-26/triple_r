import 'package:flutter/material.dart';

/// A single-field numeric prompt.
///
/// Deliberately a `StatefulWidget` that owns its own controller, rather than
/// the shorter-looking pattern of building a `TextEditingController` at the
/// call site and disposing it after `showDialog` completes.
///
/// That pattern is broken: a dialog dismisses with an animation, and the
/// `TextField` keeps rebuilding for the whole exit transition. `showDialog`'s
/// future completes the moment the route is popped, so disposing there kills
/// the controller while the field is still using it — "A
/// TextEditingController was used after being disposed", thrown from a frame
/// callback after the user has already tapped Cancel.
///
/// Owning it here ties disposal to the element actually unmounting, which is
/// the only moment that is safe.
///
/// Pops the raw trimmed text, or null if dismissed — callers parse it
/// themselves, since some want an int and some a double, and only they know
/// what an unparseable value should mean.
class NumberEntryDialog extends StatefulWidget {
  const NumberEntryDialog({
    super.key,
    required this.title,
    this.initialText = '',
    this.labelText,
    this.suffixText,
    this.decimal = false,
    this.confirmLabel = 'Save',
  });

  final String title;
  final String initialText;
  final String? labelText;
  final String? suffixText;

  /// Whether the keyboard offers a decimal point.
  final bool decimal;

  final String confirmLabel;

  @override
  State<NumberEntryDialog> createState() => _NumberEntryDialogState();
}

class _NumberEntryDialogState extends State<NumberEntryDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
        textInputAction: TextInputAction.done,
        // Submitting from the keyboard saves, matching the button — otherwise
        // "done" silently does nothing and the user taps twice.
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.labelText,
          suffixText: widget.suffixText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
