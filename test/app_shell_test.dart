import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/main.dart';
import 'package:triple_r/providers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const TripleRApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Disposes the tree *inside* the test body.
  ///
  /// Riverpod tears down [profileProvider] when the ProviderScope goes away,
  /// which cancels drift's query stream, which schedules a zero-duration timer
  /// in `StreamQueryStore.markAsClosed`. Left to testWidgets' own teardown
  /// that timer is still pending when the fake clock stops, and every test
  /// here fails with "Pending timers". Pumping an empty tree lets it fire.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Duration.zero, not a bare pump(): pump() with no argument schedules a
    // frame without advancing the fake clock, so the zero-duration timer stays
    // pending and the test still fails the !timersPending assertion.
    await tester.pump(Duration.zero);
  }

  testWidgets('opens on the dashboard with all four destinations', (tester) async {
    await pumpApp(tester);

    expect(find.text('Triple R'), findsOneWidget);
    expect(find.text('Begin workout'), findsOneWidget);
    for (final label in ['Home', 'Progression', 'History', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }

    await disposeApp(tester);
  });

  testWidgets('changing units writes through to the database', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metric'));
    await tester.pumpAndSettle();

    // The full loop: tap → database write → stream → rebuilt radio.
    expect((await db.profile).unitSystem, 'metric');
    final selected = tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(selected.groupValue, 'metric');

    await disposeApp(tester);
  });

  testWidgets('tabs keep their state across switches', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Rotate pair order'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // IndexedStack keeps every tab mounted; Settings is offstage, not gone.
    expect(find.text('Rotate pair order', skipOffstage: false), findsOneWidget);

    await disposeApp(tester);
  });
}
