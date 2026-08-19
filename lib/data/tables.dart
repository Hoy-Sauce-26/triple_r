import 'package:drift/drift.dart';

/// Singleton row holding everything that is a preference rather than a record.
///
/// Enforced to a single row by [id]'s check constraint — there is exactly one
/// user, so a table with an id column is really just a typed key-value store
/// that drift can migrate.
///
/// Weights are stored in SI regardless of [unitSystem], which
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

  /// A workout the user picked by hand, overriding the rotation, or null to
  /// follow it.
  ///
  /// Persisted, because it is a correction to the app's belief about which
  /// session the user is on — "I trained on Tuesday and did not log it" is
  /// still true after a restart. Held only until a workout completes, at
  /// which point the session row it produced carries the sequence forward and
  /// this goes back to null.
  IntColumn get plannedRotationIndex => integer().nullable()();

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

/// Body weight over time. Only weight is tracked — height was dropped: it
/// does not change
/// for adults, so charting it would draw a flat line.
@DataClassName('BodyWeightEntry')
class BodyWeightEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get weightKg => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Which branch of each of the nine paths the user is on, and where in it.
@DataClassName('ProgressionConfig')
class ProgressionConfigs extends Table {
  TextColumn get pathId => text()();
  TextColumn get selectedBranchId => text()();

  /// Null for alternating branches, where two exercises are current at once
  /// and the session's exercise is resolved from the branch pattern instead.
  /// See `docs/PLAN.md` §2.2.2.
  TextColumn get selectedExerciseId => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {pathId};
}

/// Per-exercise progression state.
///
/// Keyed by exercise rather than by path because the alternating barbell hinge
/// branch has two exercises in flight simultaneously, each carrying its own
/// working weight and its own failure cadence. Keying this way also resets
/// failure counts for free when a user advances to a new exercise.
///
/// Rows are created lazily — an exercise with no row has never been loaded or
/// failed.
@DataClassName('ExerciseState')
class ExerciseStates extends Table {
  TextColumn get exerciseId => text()();

  /// The load prescribed for the *next* set. Past loads live on
  /// [SetRecords.weightKg]; raising this must not rewrite history.
  RealColumn get workingLoadKg => real().withDefault(const Constant(0))();

  /// What the user last chose to add here, remembered so the "add weight?"
  /// prompt can pre-fill it. Null seeds the prompt at 2.5 lb / 1 kg.
  /// Deliberately not a setting — see `docs/PLAN.md` §2.2.1.
  RealColumn get lastIncrementKg => real().nullable()();

  IntColumn get consecutiveFailures => integer().withDefault(const Constant(0))();

  /// When the user topped out a bodyweight branch here — maxed the rep scheme
  /// with no harder exercise to move to and no weight to add.
  ///
  /// Exists so the congratulation fires once instead of every session. Null
  /// means it has not been shown.
  DateTimeColumn get masteredAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {exerciseId};
}

/// One workout, written at *start* rather than on completion so a crash
/// mid-session does not lose the sets already logged.
@DataClassName('WorkoutSession')
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();

  /// Null while in progress.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 'in_progress' | 'completed' | 'abandoned'. Only completed sessions
  /// advance the rotation counter.
  TextColumn get status => text()();

  /// Which pair order this session used. Stored rather than recomputed so
  /// history stays truthful if the completed-session count later changes.
  IntColumn get rotationIndex => integer()();

  /// Which session number this workout was, counting from the first ever.
  ///
  /// Not the same as the number of rows before it. A user who trains without
  /// logging can start the workout they are actually due, which advances this
  /// past the row count — and the next session must carry on from here rather
  /// than from a count that never saw the missed day.
  ///
  /// Nullable only for rows written before the column existed.
  IntColumn get sessionOrdinal => integer().nullable()();

  IntColumn get pairRestSeconds => integer()();
  IntColumn get tripletRestSeconds => integer()();

  /// Resume point for an interrupted workout. Cleared once finished.
  TextColumn get cursorJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One logged set.
///
/// [repsCompleted] and [holdSeconds] are mutually exclusive and both uncapped
/// — they record what the user actually did, not what the target was. The
/// target is deliberately absent: it is recomputed from the tree and rep
/// scheme when needed, so revising the scheme later cannot retroactively
/// rewrite what past sessions appear to have been aiming for.
@DataClassName('SetRecord')
class SetRecords extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get pathId => text()();
  TextColumn get exerciseId => text()();
  IntColumn get setIndex => integer()();

  IntColumn get repsCompleted => integer().nullable()();
  IntColumn get holdSeconds => integer().nullable()();

  /// The load actually used for this set, independent of the exercise's
  /// current working load.
  RealColumn get weightKg => real().withDefault(const Constant(0))();

  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK ((reps_completed IS NULL) != (hold_seconds IS NULL))',
      ];
}
