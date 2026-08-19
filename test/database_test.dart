import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_r/data/database.dart';

/// Proves the in-memory harness every later phase's database tests will use:
/// a real SQLite engine on the host VM, no device and no file system.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('creates exactly one profile row on first open', () async {
    final profile = await db.profile;

    expect(profile.id, 1);
    final all = await db.select(db.userProfiles).get();
    expect(all, hasLength(1));
  });

  test('defaults match the Recommended Routine and the imperial-first choice',
      () async {
    final profile = await db.profile;

    expect(profile.unitSystem, 'imperial');
    expect(profile.defaultPairRestSeconds, 90);
    expect(profile.defaultTripletRestSeconds, 60);
    expect(profile.rotatePairOrder, isTrue);
  });

  test('profile updates persist and reach watchers', () async {
    // The subscription has to be live *and* have delivered its initial value
    // before the write, or the query stream's first emission is already the
    // updated row and the test cannot tell propagation from a plain read.
    final seen = <String>[];
    final sub = db.watchProfile().listen((p) => seen.add(p.unitSystem));
    await pumpEventQueue();

    await db.updateProfile(const UserProfilesCompanion(unitSystem: Value('metric')));
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, ['imperial', 'metric']);
    expect((await db.profile).unitSystem, 'metric');
  });

  test('the single-row constraint is enforced', () async {
    // Matched on the specific SQLite error, not just "something threw" — the
    // constraint is declared with a self-referencing getter, and a laxer
    // matcher would pass just as happily on a StackOverflowError.
    await expectLater(
      db.into(db.userProfiles).insert(const UserProfilesCompanion(id: Value(2))),
      throwsA(
        predicate(
          (e) => e.toString().contains('CHECK constraint failed'),
          'a SQLite CHECK constraint violation',
        ),
      ),
    );
    expect(await db.select(db.userProfiles).get(), hasLength(1));
  });

  test('foreign keys are on, so later cascades will actually fire', () async {
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();

    expect(result.data.values.first, 1);
  });
}
