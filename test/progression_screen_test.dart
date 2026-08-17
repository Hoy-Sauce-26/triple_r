import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/progression_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    // All nine cards at once: the screen is a ListView, so anything below the
    // fold is never built and findsNothing would mean "off screen", not
    // "absent". A tall surface removes that ambiguity from every assertion.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProgressionScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Disposes inside the test body so drift's stream-close timer fires while
  /// the fake clock still runs — see README.
  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows all nine paths with no config stored', (tester) async {
    await pumpScreen(tester);

    for (final name in [
      'Pull-up',
      'Squat',
      'Dip',
      'Hinge',
      'Row',
      'Push-up',
      'Anti-Extension',
      'Anti-Rotation',
      'Extension',
    ]) {
      expect(find.text(name), findsWidgets, reason: name);
    }

    await disposeScreen(tester);
  });

  testWidgets('a fresh install starts each path at its first exercise',
      (tester) async {
    await pumpScreen(tester);

    // Defaults are derived, not written — nothing is in the table yet.
    expect(await db.progressionConfigsAll, isEmpty);
    expect(find.text('Scapular Pulls'), findsWidgets);
    expect(find.text('Assisted Squats'), findsWidgets);

    await disposeScreen(tester);
  });

  testWidgets('changing the current exercise persists it', (tester) async {
    await db.saveProgressionConfig(
      pathId: 'pushup',
      branchId: 'pseudoplanche',
      exerciseId: 'incline_pushups',
    );
    await pumpScreen(tester);

    expect(find.text('Incline Push-ups'), findsWidgets);

    final stored = (await db.progressionConfigsAll)
        .firstWhere((c) => c.pathId == 'pushup');
    expect(stored.selectedExerciseId, 'incline_pushups');

    await disposeScreen(tester);
  });

  testWidgets('the alternating hinge branch names the next session\'s lift',
      (tester) async {
    await db.saveProgressionConfig(
      pathId: 'hinge',
      branchId: 'barbell',
      exerciseId: null,
    );
    await pumpScreen(tester);

    // Both are current; the card says which one comes up next.
    expect(
      find.text('Barbell Romanian Deadlift / Barbell Deadlift'),
      findsOneWidget,
    );
    expect(
      find.text('Next session: Barbell Romanian Deadlift'),
      findsOneWidget,
    );

    await disposeScreen(tester);
  });
}
