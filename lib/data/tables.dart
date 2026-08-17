import 'package:drift/drift.dart';

/// Singleton row holding everything that is a preference rather than a record.
///
/// Enforced to a single row by [id]'s check constraint — there is exactly one
/// user, so a table with an id column is really just a typed key-value store
/// that drift can migrate.
///
/// Weights and heights are stored in SI regardless of [unitSystem], which
/// controls display only. See `docs/PLAN.md` §2.2.1 for why arithmetic on
/// loads happens in the display unit rather than in kg.
@DataClassName('UserProfile')
class UserProfiles extends Table {
  // Drift's own idiom for a check constraint: `id` inside the body refers to
  // the generated table's column, not to this getter. Only the generator ever
  // reads this class — at runtime the app uses $UserProfilesTable — so it
  // never actually recurses. The lint cannot see that.
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1)).withDefault(const Constant(1))();

  /// Null until the user personalizes. Height does not change for adults, so
  /// it lives here rather than in a time series.
  RealColumn get heightCm => real().nullable()();

  /// 'imperial' | 'metric'. Imperial is the default.
  TextColumn get unitSystem =>
      text().withLength(min: 6, max: 8).withDefault(const Constant('imperial'))();

  IntColumn get defaultPairRestSeconds => integer().withDefault(const Constant(90))();

  IntColumn get defaultTripletRestSeconds => integer().withDefault(const Constant(60))();

  /// Whether to rotate which pair comes first each session. Not part of the
  /// Recommended Routine — see `docs/PLAN.md` §5.1.
  BoolColumn get rotatePairOrder => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
