import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';
import 'package:triple_r/domain/backup.dart';
import 'package:triple_r/providers.dart';
import 'package:triple_r/screens/settings_screen.dart';
import 'package:triple_r/services/backup_files.dart';
import 'package:triple_r/services/clock.dart';
import 'package:triple_r/state/timer_providers.dart';
import 'package:triple_r/theme.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeBackupFiles files;

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() {
    db = AppDatabase.memory();
    files = FakeBackupFiles();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupFilesProvider.overrideWithValue(files),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 3, 10, 9))),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: lightTheme, home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(Duration.zero);
  }

  Future<void> tapListTile(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> addSession(String id, DateTime at) =>
      db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              id: id,
              startedAt: at,
              endedAt: Value(at.add(const Duration(minutes: 40))),
              status: 'completed',
              rotationIndex: 0,
              pairRestSeconds: 90,
              tripletRestSeconds: 60,
            ),
          );

  group('rest defaults', () {
    testWidgets('adjust in 15 second steps and persist', (tester) async {
      await pump(tester);

      expect(find.text('90s'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();

      expect((await db.profile).defaultPairRestSeconds, 105);
      await disposeApp(tester);
    });

    testWidgets('will not go below the floor', (tester) async {
      await db.updateProfile(
        const UserProfilesCompanion(defaultPairRestSeconds: Value(30)),
      );
      await pump(tester);

      final minus = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline).first,
      );
      expect(minus.onPressed, isNull, reason: '30s is the floor');
      await disposeApp(tester);
    });
  });

  group('export', () {
    testWidgets('hands a dated file to the share sheet', (tester) async {
      await addSession('s1', DateTime(2026, 3, 1, 9));
      await pump(tester);

      await tapListTile(tester, 'Export');

      expect(files.sharedFileName, 'triple-r-2026-03-10.json');
      expect(files.sharedContents, contains('"formatVersion": 1'));
      expect(files.sharedContents, contains('s1'));
      await disposeApp(tester);
    });
  });

  group('import', () {
    testWidgets('says exactly what it will destroy before doing it',
        (tester) async {
      // A backup holding one session, imported over a device holding two.
      final source = AppDatabase.memory();
      addTearDown(source.close);
      await source.into(source.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              id: 'from-backup',
              startedAt: DateTime(2026, 2, 1, 9),
              status: 'completed',
              rotationIndex: 0,
              pairRestSeconds: 90,
              tripletRestSeconds: 60,
            ),
          );
      files.fileToPick = await exportBackup(source, now: DateTime(2026, 2, 2));

      await addSession('local-1', DateTime(2026, 3, 1, 9));
      await addSession('local-2', DateTime(2026, 3, 3, 9));
      await pump(tester);

      await tapListTile(tester, 'Import');

      expect(find.text('Replace everything?'), findsOneWidget);
      expect(find.textContaining('deletes the 2 sessions'), findsOneWidget);
      expect(find.textContaining('1 from the backup'), findsOneWidget);

      // Nothing has been touched while the dialog is up.
      expect(await db.select(db.workoutSessions).get(), hasLength(2));

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.id, 'from-backup');
      await disposeApp(tester);
    });

    testWidgets('cancelling the dialog changes nothing', (tester) async {
      final source = AppDatabase.memory();
      addTearDown(source.close);
      files.fileToPick = await exportBackup(source);

      await addSession('local-1', DateTime(2026, 3, 1, 9));
      await pump(tester);

      await tapListTile(tester, 'Import');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      await disposeApp(tester);
    });

    testWidgets('cancelling the file picker never opens the dialog',
        (tester) async {
      files.fileToPick = null;
      await addSession('local-1', DateTime(2026, 3, 1, 9));
      await pump(tester);

      await tapListTile(tester, 'Import');

      expect(find.text('Replace everything?'), findsNothing);
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      await disposeApp(tester);
    });

    testWidgets('a junk file is reported and destroys nothing', (tester) async {
      files.fileToPick = 'this is not a backup';
      await addSession('local-1', DateTime(2026, 3, 1, 9));
      await pump(tester);

      await tapListTile(tester, 'Import');

      expect(find.text('Replace everything?'), findsNothing);
      expect(find.textContaining('not valid JSON'), findsOneWidget);
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      await disposeApp(tester);
    });
  });
}
