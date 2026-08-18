import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/widgets/number_entry_dialog.dart';

/// Regression cover for a crash on cancel.
///
/// The original code built a TextEditingController at the call site and
/// disposed it as soon as `showDialog` completed. Because a dialog dismisses
/// with an animation, the TextField kept rebuilding against the dead
/// controller and threw "A TextEditingController was used after being
/// disposed" a frame later — after the user had already tapped Cancel.
void main() {
  Future<String?> open(
    WidgetTester tester, {
    String initialText = '',
  }) async {
    String? result;
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  opened = true;
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => NumberEntryDialog(
                      title: 'Height',
                      initialText: initialText,
                      suffixText: 'cm',
                      decimal: true,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    return result;
  }

  testWidgets('cancelling does not touch a disposed controller',
      (tester) async {
    await open(tester, initialText: '178');

    await tester.tap(find.text('Cancel'));
    // Pumping past the dismissal animation is the whole point: the original
    // bug only surfaced during those frames, not on the tap itself.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NumberEntryDialog), findsNothing);
  });

  testWidgets('cancelling returns null so the caller writes nothing',
      (tester) async {
    String? captured = 'untouched';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                captured = await showDialog<String>(
                  context: context,
                  builder: (_) => const NumberEntryDialog(
                    title: 'Height',
                    initialText: '178',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });

  testWidgets('saving returns the trimmed text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => const NumberEntryDialog(title: 'Height'),
              ).then((v) => _lastResult = v),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  182  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_lastResult, '182');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing by tapping outside is also clean', (tester) async {
    await open(tester, initialText: '178');

    // Barrier dismissal skips the Cancel button entirely, so it exercises a
    // different teardown path than the one above.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NumberEntryDialog), findsNothing);
  });

  testWidgets('the keyboard action saves, matching the button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => const NumberEntryDialog(title: 'Reps'),
              ).then((v) => _lastResult = v),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_lastResult, '9');
    expect(find.byType(NumberEntryDialog), findsNothing);
  });
}

String? _lastResult;
