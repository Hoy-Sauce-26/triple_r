import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/progression_screen.dart';

/// The ladder view: rungs in order, the fork drawn at its own level, and a
/// locked route that says when it opens rather than only that it is shut.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall surface so `findsNothing` means absent, not merely below the fold.
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

  Future<void> openPath(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  /// Chips hit-test through their own InkWell, not the label Text, so taps
  /// must target the chip itself.
  Future<void> tapRoute(WidgetTester tester, String name) async {
    await tester.tap(find.ancestor(
      of: find.text(name),
      matching: find.byType(ChoiceChip),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('the status list opens the ladder for a path', (tester) async {
    await pumpScreen(tester);
    // Scoped to the row: Row is also a five-rung path, so a bare text match
    // would be ambiguous.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Pull-up'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('1/5'),
      ),
      findsOneWidget,
      reason: 'pull-up rung count',
    );

    await openPath(tester, 'Pull-up');

    // The shared climb, in order, rather than one label in a dropdown.
    for (final name in [
      'Scapular Pulls',
      'Arch Hangs',
      'Pull-up Eccentrics',
      'Full Pull-ups',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('You are here'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('below the fork, no route is chosen and none is expanded',
      (tester) async {
    // A config row naming the default route is not a decision the user made.
    // Standing on Full Pull-ups, they have not picked the weighted route, so
    // nothing is shown as selected and its exercises stay out of sight.
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'full_pullups',
    );
    await pumpScreen(tester);
    await openPath(tester, 'Pull-up');

    expect(find.text('Weighted Pull-ups'), findsNothing);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.selected, isFalse, reason: 'nothing is chosen yet');
    }

    await disposeScreen(tester);
  });

  testWidgets('past the fork, the chosen route is marked and expanded',
      (tester) async {
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'typewriter',
      exerciseId: 'typewriter_pullups',
    );
    await pumpScreen(tester);
    await openPath(tester, 'Pull-up');

    expect(find.text('Type-writer Pull-ups'), findsOneWidget);
    expect(find.text('Archer Pull-ups'), findsOneWidget);
    expect(find.text('Weighted Pull-ups'), findsNothing,
        reason: 'only the route actually taken is expanded');

    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((c) => c.selected);
    expect(selected, hasLength(1));

    await disposeScreen(tester);
  });

  testWidgets('every route says where it joins the path, default included',
      (tester) async {
    await pumpScreen(tester);
    await openPath(tester, 'Pull-up');

    // All four pull-up routes fork at 5, the default among them.
    expect(find.text('starts at 5'), findsNWidgets(4));

    await disposeScreen(tester);
  });

  testWidgets('a route forking higher up is annotated but not gated',
      (tester) async {
    // Nothing is locked. Someone installing the app who already trains
    // pistols picks the pistol route from a standing start; "starts at 5"
    // tells them four rungs are being skipped, which is their call.
    await pumpScreen(tester);
    await openPath(tester, 'Squat');

    expect(find.text('Pistol'), findsOneWidget);
    expect(find.text('starts at 5'), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tapRoute(tester, 'Pistol');

    final stored =
        (await db.progressionConfigsAll).firstWhere((c) => c.pathId == 'squat');
    expect(stored.selectedBranchId, 'pistol');
    expect(stored.selectedExerciseId, 'partial_pistol_squats');

    await disposeScreen(tester);
  });

  testWidgets('taking handstands on the second slot offers to move the first',
      (tester) async {
    // The one constraint left, and it is structural: the same movement cannot
    // fill both vertical-push slots of one workout. Resolved by moving the
    // other path, never by refusing this one.
    await db.saveProgressionConfig(
      pathId: 'dip',
      branchId: 'hspu',
      exerciseId: 'pike_pushups',
    );
    await pumpScreen(tester);
    await openPath(tester, 'Push-up');

    await tapRoute(tester, 'Handstand Push-up');

    expect(find.text('Move Dip off handstands?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move Dip'));
    await tester.pumpAndSettle();

    final configs = await db.progressionConfigsAll;
    expect(
      configs.firstWhere((c) => c.pathId == 'pushup').selectedBranchId,
      'hspu',
    );
    expect(
      configs.firstWhere((c) => c.pathId == 'dip').selectedBranchId,
      'weighted',
      reason: 'the other slot gives it up rather than this one being refused',
    );

    await disposeScreen(tester);
  });

  testWidgets('no conflict when the other path only names handstands',
      (tester) async {
    // Dip's config row says 'hspu' but its position is Dip Eccentrics, below
    // the fork — the screen shows no route chosen there, so nothing is
    // occupying the handstand slot and Push-up may take it uncontested.
    await db.saveProgressionConfig(
      pathId: 'dip',
      branchId: 'hspu',
      exerciseId: 'dip_eccentrics',
    );
    await pumpScreen(tester);
    await openPath(tester, 'Push-up');

    await tapRoute(tester, 'Handstand Push-up');

    expect(find.text('Move Dip off handstands?'), findsNothing);
    final configs = await db.progressionConfigsAll;
    expect(
      configs.firstWhere((c) => c.pathId == 'pushup').selectedBranchId,
      'hspu',
    );
    expect(
      configs.firstWhere((c) => c.pathId == 'dip').selectedExerciseId,
      'dip_eccentrics',
      reason: 'the untouched path is left exactly as it was',
    );

    await disposeScreen(tester);
  });

  testWidgets('a shared rung is selectable while on the alternating route',
      (tester) async {
    // Choosing Romanian Deadlifts from the barbell route used to save against
    // that route, whose position is read from its fork point — so the value
    // was never read back and the workout kept programming the rotation.
    await db.saveProgressionConfig(
      pathId: 'hinge',
      branchId: 'barbell',
      exerciseId: null,
    );
    await pumpScreen(tester);
    await openPath(tester, 'Hinge');
    expect(find.text('Alternates every session'), findsOneWidget);

    await tester.tap(find.text('Romanian Deadlifts'));
    await tester.pumpAndSettle();

    final stored =
        (await db.progressionConfigsAll).firstWhere((c) => c.pathId == 'hinge');
    expect(stored.selectedExerciseId, 'romanian_deadlifts');
    expect(stored.selectedBranchId, 'bodyweight',
        reason: 'the shared climb belongs to no route, so it lands on the '
            'default one where the position can actually be read back');

    // And the screen agrees: back below the fork, nothing is chosen.
    expect(find.text('Alternates every session'), findsNothing);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.selected, isFalse);
    }

    await disposeScreen(tester);
  });

  testWidgets('cancelling the handstand move leaves both paths alone',
      (tester) async {
    await db.saveProgressionConfig(
      pathId: 'dip',
      branchId: 'hspu',
      exerciseId: 'pike_pushups',
    );
    await pumpScreen(tester);
    await openPath(tester, 'Push-up');

    await tapRoute(tester, 'Handstand Push-up');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    final configs = await db.progressionConfigsAll;
    expect(configs.firstWhere((c) => c.pathId == 'dip').selectedBranchId, 'hspu');
    expect(configs.where((c) => c.pathId == 'pushup'), isEmpty);

    await disposeScreen(tester);
  });

  testWidgets('a path with no trunk opens on the choice, not a climb',
      (tester) async {
    // Anti-Rotation and Extension have no shared prefix at all — they are a
    // straight pick between variations, and the heading says so.
    await pumpScreen(tester);
    await openPath(tester, 'Extension');

    expect(find.text('Pick a variation'), findsOneWidget);
    expect(find.text('From here, pick a route'), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('a path with a trunk frames the fork as coming later',
      (tester) async {
    await pumpScreen(tester);
    await openPath(tester, 'Pull-up');

    expect(find.text('From here, pick a route'), findsOneWidget);
    expect(find.text('Pick a variation'), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('tapping a rung sets the current exercise', (tester) async {
    await pumpScreen(tester);
    await openPath(tester, 'Pull-up');

    // Selecting a rung above the current one is allowed: someone who can
    // already do pull-ups must be able to say so.
    await tester.tap(find.text('Pull-up Eccentrics'));
    await tester.pumpAndSettle();

    final stored =
        (await db.progressionConfigsAll).firstWhere((c) => c.pathId == 'pullup');
    expect(stored.selectedExerciseId, 'pullup_eccentrics');

    await disposeScreen(tester);
  });

  testWidgets('choosing an available route switches to its first exercise',
      (tester) async {
    await db.saveProgressionConfig(
      pathId: 'pullup',
      branchId: 'weighted',
      exerciseId: 'full_pullups',
    );
    await pumpScreen(tester);
    await openPath(tester, 'Pull-up');

    await tapRoute(tester, 'Type-writer');

    final stored =
        (await db.progressionConfigsAll).firstWhere((c) => c.pathId == 'pullup');
    expect(stored.selectedBranchId, 'typewriter');
    expect(stored.selectedExerciseId, 'typewriter_pullups');

    await disposeScreen(tester);
  });

  testWidgets('the alternating hinge route explains itself', (tester) async {
    await db.saveProgressionConfig(
      pathId: 'hinge',
      branchId: 'barbell',
      exerciseId: null,
    );
    await pumpScreen(tester);
    await openPath(tester, 'Hinge');

    expect(find.text('Alternates every session'), findsOneWidget);
    expect(find.text('Barbell Romanian Deadlift'), findsOneWidget);
    expect(find.text('Barbell Deadlift'), findsOneWidget);

    await disposeScreen(tester);
  });
}
