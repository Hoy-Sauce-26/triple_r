# Triple R

An offline Flutter app for the
[Reddit Recommended Routine](https://www.reddit.com/r/bodyweightfitness/wiki/kb/recommended_routine/):
nine progression paths, run as three pairs plus a core triplet, with rest
timers, progression tracking and history. No account, no network, no backend —
the SQLite file on the device is the whole system of record.

| | |
| --- | --- |
| **Package** | `com.nttech.TripleR` (debug builds install alongside as `com.nttech.TripleR.dev`, with their own database) |
| **Platforms** | Android, iOS |
| **State** | `flutter_riverpod` 3 |
| **Persistence** | `drift` (SQLite), schema v7 |
| **Charts** | `fl_chart` |
| **Platform edges** | `audioplayers`, `wakelock_plus`, `flutter_local_notifications`, `share_plus`, `file_picker`, `path_provider` |

```bash
flutter run                       # dev build -> com.nttech.TripleR.dev
flutter test                      # all tests, host VM, no emulator needed
flutter analyze
dart run build_runner build       # after ANY change under lib/data/
```

`docs/PLAN.md` is the original spec. It is the source of truth for *the
routine* (which exercises, which order, which rep schemes) and is now behind
the code in places — where they disagree about app behaviour, the code and
this file win.

## Layout

| Directory | Holds |
| --- | --- |
| `lib/trees/` | The nine progression paths as typed constants, plus the rules for moving around them |
| `lib/domain/` | Pure logic: rep schemes, advance/regress evaluation, units, countdown math, session planning, analytics, backup serialisation |
| `lib/data/` | drift database, tables, migrations, queries |
| `lib/services/` | Platform edges. Each is an interface with a fake |
| `lib/state/` | Riverpod controllers: the active session and the timers |
| `lib/screens/` | One file per screen |
| `lib/widgets/` | Shared widgets and dialogs |

`lib/domain/` and `lib/trees/` import no Flutter beyond types. That is what
lets the rules be tested exhaustively without a widget tree, and it is worth
preserving — most of the test suite depends on it.

## The progression trees

The hardest part of the codebase to hold in your head. Read
`lib/trees/tree_types.dart` first.

A **`Path`** is one of the nine slots (pull-up, squat, dip, hinge, row,
push-up, and three core). It has a **trunk** — a shared prefix everyone
climbs — and several **`Branch`**es, the routes that diverge from it.

- **`attachesAtLevel`** is 1-based and counts against the **canonical line**,
  which is `trunkIds + defaultBranch.exerciseIds` — *not* the trunk alone.
  The squat path is why: its trunk is two exercises, but the step-up route
  forks at level 5, and levels 3–4 live inside the default `bodyweight`
  branch. `progressionFor(branch)` splices the two together.
- **`BranchKind.alternating`** means two lifts in rotation rather than a
  ladder. Only the barbell hinge uses it. `levelFor` reports such a branch's
  *fork point*, ignoring any stored exercise — see the trap below.
- **`ProgressionMode.load`** is a terminal node: advancement adds weight at
  the same rep target instead of moving on.
- Paths can have an **empty trunk** (Anti-Rotation, Extension). Their routes
  are independent entry points, not a progression, and the detail screen
  renders them as a plain choice.

### Routes are never gated

There is no locking and no greying out. Someone installing the app who can
already do pistol squats picks the pistol route on day one; a rule that made
them walk the current-exercise list upward first was a puzzle, not a
safeguard. A route's fork level is shown as information (`starts at 5`).

One constraint survives, and it is structural rather than aspirational: the
handstand chain cannot fill both vertical-push slots, because the session
builder would program the same movement twice in one workout.
`handstandConflict` reports *which* path conflicts so the caller can offer to
move it — it never refuses the selection.

### Two invariants the detail screen depends on

Both are asserted in `test/tree_integrity_test.dart`, because both were true
by luck before they were true by design:

1. **Every default route is linear.** A pre-fork position is stored against
   the default route; if that route were alternating it would discard the
   exercise silently.
2. **Every route's shared climb lies on the default route's progression.**
   Otherwise a pre-fork rung would be stored somewhere unreadable.

> **Trap.** `levelFor` returns the fork point for alternating branches and
> ignores `exerciseId`. Writing a pre-fork position against the barbell hinge
> therefore *succeeds and is never read back* — the write is silently lost and
> the workout keeps programming the rotation. `_selectShared` exists to avoid
> exactly this.

## Sessions

### Which workout is next

Not "how many rows are in the table". `workout_sessions.session_ordinal`
records which session number a workout *was*, and `nextSessionOrdinal()`
carries on from the last completed one. A user who trains without logging can
pick a different workout on the dashboard; that advances the ordinal past the
row count, and the next session has to continue from there rather than from a
count that never saw the missed day.

`sessionOrdinalForRotation(due, chosen)` turns a picked workout into the
session number it implies — the soonest session at or after `due` that runs
that order. **This drives the alternating hinge as well as the pair order**,
so skipping ahead advances the barbell rotation by one too. Overriding only
the rotation index would hand the user next week's pair order with yesterday's
deadlift variant.

The override lives in `user_profiles.planned_rotation_index` and is
**persisted**, because it is a correction to the app's belief about which
session the user is on, not a preference about the screen in front of them. It
is cleared when a session **completes** (the row it produced now carries the
sequence) and **kept** when one is abandoned (nothing recorded it, so the
correction is still outstanding).

### Lifecycle

The warmup and the workout live behind a single route,
`WorkoutFlowScreen`, which switches on `cursor.warmupComplete`. This is
load-bearing. The warmup used to `pushReplacement` itself with the workout
screen, and replacing a route completes the *replaced* route's popped future —
so the dashboard's `await push(warmup)` returned the instant the user tapped
"Start workout", and the teardown waiting on it ran mid-workout, freezing the
session clock at 0:00 and dropping the wakelock for the rest of the session.
The session clock and wakelock belong to the session, not to a navigation
stack. Read the notes in that file before splitting it apart again.

`ActiveSessionController` writes through to the database *before* updating
state, so a session killed at any point resumes to exactly what the user saw.
`exerciseByPath` is resolved once at start and frozen — recomputing it
mid-session would swap an exercise out from under someone two sets in — and
`_hydrate` reads the stored ordinal back rather than recomputing it.

Set ids are deterministic (`{sessionId}-{pathId}-{setIndex}`), so re-logging
after an edit overwrites rather than duplicating.

### Logging a set

Both entry fields are seeded from history, best source first — this session,
then last session, then the scheme floor. A seed is only ever a guess, though,
and the user overtypes it immediately, which destroys the one piece of context
they were comparing against. So the set list carries a second column: what the
*same set index* came to last session, all three rows of it, read from the
query the seed itself comes from so the two cannot disagree.

Last time sits to the left of this session, and both columns are fixed-width
(`_SetRow.columnWidth`) so they share an edge with their headings. The order
is the direction the comparison runs — what you did, then what you are doing.
Reading the number off the screen is what makes it safe to leave the entry box
loose rather than pinning it to last week's target.

## Timers

**Deadline-based, never decrement-based.** A running countdown stores the
instant it ends and derives what is left. A phone that sleeps or throttles
timers delivers one late tick instead of hundreds on time; a decrementing
counter would come back that much wrong and a rest would silently stretch. A
deadline is simply correct whenever it is next observed.

**Republish a new instance on each tick.** Riverpod compares by identity, so
`state = state` notifies nobody — the timer keeps running while the on-screen
seconds freeze. `Countdown.tick()` exists solely to return a distinct object
holding identical values. Unit tests read `remaining` directly and cannot see
this; only a widget test catches it.

A rest ends with five gentle blips, one a second, and then the chime. The
blips are `Alerts.restCountdown` rather than a quieter `restComplete`: the
countdown is a warning and the end of the rest is an instruction, and someone
with the phone in a pocket has to be able to tell them apart without looking.
They are keyed to the *ceiling* of the remaining time — the second the screen
is showing — so a phone that slept through part of the lead-in blips for the
second it comes back on rather than replaying the ones it missed.

Three separate timers, deliberately: `restTimerProvider` (between sets),
`holdTimerProvider` (warmup holds), and `sessionClockProvider` (elapsed
workout time, derived from `startedAt` so a resume reports the true total).
The active-workout screen also has a count-*up* stopwatch for timed
exercises — a plank is held to failure, so counting down means knowing the
answer in advance.

## Data

`lib/data/database.dart` holds the single `AppDatabase`, opened once in
`main()` and injected through `databaseProvider`, which **throws if not
overridden** so a test can never open the real on-device file.

| Table | Holds |
| --- | --- |
| `user_profiles` | Single row. Units, rest defaults, load increment, rotation toggle, hand-picked workout |
| `progression_configs` | One row per path: selected branch and exercise |
| `exercise_states` | Working load, last increment, consecutive failures, mastery |
| `workout_sessions` | Header, status, rotation index, session ordinal, resume cursor |
| `body_weight_entries` | Weight over time |
| `set_records` | Every set, with reps *or* hold seconds, and its own weight |

Weight is **per set**, not per exercise — each row carries its own
`weight_kg`, and both the logger and the history screen can correct it.

`set_records.weight_kg` is **nullable, and null is not zero.** Null means no
weight was entered; zero means the user said this set carried nothing extra.
Collapsing the two was a real bug: a set logged at 0 lb came back
indistinguishable from an untouched field, so the logger re-seeded the next set
from the working load and overruled the user every set. The logger's helper
text spells the difference out, because an empty box and a box holding `0` look
much more alike than they mean.

The distinction only runs forward. Everything written before v7 went into a
NOT NULL DEFAULT 0 column that no screen could type a zero into, so a zero in
an old row means "nobody filled this in" — which is every set of every
bodyweight exercise ever logged. The v7 migration nulls them out for exactly
that reason; carrying them across as deliberate zeros put "9 @ 0 lb" on every
push-up in the history.

Two rules govern showing a load, and both are needed:

- **The exercise must be `loadable`.** A row can carry a number the exercise
  does not take, and "@ 0 lb" on a push-up is nonsense the user cannot even
  correct, since the edit dialog hides its weight field on the same flag.
- **The weight must be non-null** — but zero still prints. On a weighted dip,
  zero is a choice, and hiding it makes the set look unlogged.

`exercise_states.working_load_kg` is the app's **plan** for next session;
`set_records.weight_kg` is the **record** of what was lifted. When they
disagree at the end of a session the log wins, and the plan is written back to
match — otherwise someone who types their weight into the logger rather than
accepting an add-load prompt never accumulates a working load at all, and the
next prompt offers them the bare increment as a *total*.

| Version | Change |
| --- | --- |
| 2 | Everything past the profile table |
| 3 | `exercise_states.mastered_at` |
| 4 | `workout_sessions.session_ordinal` |
| 5 | Height dropped (table rebuild — SQLite cannot drop a column in place) |
| 6 | `user_profiles.planned_rotation_index` |
| 7 | `user_profiles.load_increment_kg`; `set_records.weight_kg` made nullable and its pre-existing zeros nulled (table rebuild — the first migration that *widens* a column, and the first that reinterprets data rather than moving it) |

Every schema change needs a `schemaVersion` bump **and** a migration step,
even pre-release. Exported backups carry their version and are re-imported
through these same migrations, so a skipped step breaks restore on someone
else's phone rather than failing loudly here.

### How much weight a progression adds

Three tiers, narrowest first — `incrementKgFor` in `lib/domain/units.dart`:

1. `exercise_states.last_increment_kg`, what *this exercise* last moved by.
2. `user_profiles.load_increment_kg`, the step chosen in Settings.
3. `seedIncrementKg`, 2.5 lb or 1 kg.

`docs/PLAN.md` §2.2.1 says the increment is deliberately not a setting, on the
reasoning that the user corrects it once at the prompt and it is remembered per
exercise from then on. That holds for someone whose gym has every plate; it
does not hold for someone whose smallest pair is 5 lb, who then has to correct
the same prompt on nine paths before the app stops suggesting a step they
cannot load. So there is a setting now, offered as fixed choices rather than a
free field — these are plate pairs, and a 3.7 lb step is not a thing anyone can
put on a bar.

The per-exercise memory still wins over it, because a weighted pull-up and a
barbell deadlift do not climb at the same rate. The Settings row says so, since
changing the setting and watching one exercise ignore it otherwise looks
broken.

## Charts

`TrendChart` is shared by body weight and exercise progress. Two things it
does deliberately:

- **The y-range does not start at zero.** An 82 kg body weight plotted from
  zero is a flat line at the top of the frame, which hides exactly the
  variation the chart was opened to see.
- **The axis is labelled, and the label lives on the axis.** Four interval
  gridlines carry values, and the units are named by `axisLabel`, rendered
  rotated against the axis rather than as a caption over the card — as a
  caption it read as a heading for the whole card, and the numbers down the
  side stayed unexplained. The padded extremes of both axes are skipped
  (`minIncluded: false`), because they are padding rather than data and
  labelling them puts a number hard against the frame a hair from the first
  real gridline.

## Services

Each platform edge is an interface with a fake, so the state that drives it is
testable without the plugin: `Clock`/`Ticker`, `Alerts` (audio), `Haptics`,
`ScreenWake`, `BackupFiles`, `WorkoutNotification`.

The ongoing workout notification is driven from `ActiveSessionController`,
not from a screen, so it stays correct when no screen is showing — which is
the point, since the phone is in a pocket between sets. While a rest runs the
notification is *about the rest*: "Next up:" for the coming exercise, the bar
tracking the rest, and the remaining time handed to Android as a
**chronometer** rather than written into the text.

That last part is not cosmetic. Text only changes when Dart runs, and Dart
stops running when the phone is in a pocket — so the shade froze at whatever
second Flutter was last scheduled on, and offered thirty seconds of rest to
someone who had three. `usesChronometer` + `chronometerCountDown` hand the
platform the deadline and let it count down on its own clock, which is correct
whether or not the app is awake. It is the same reasoning as the timers
themselves: store the instant, derive the rest.

Updates are throttled by comparing the fully-composed content, collapsing the
5-per-second ticks into one post per whole second.

## Testing

```bash
flutter test
```

Database tests run on the host VM against real SQLite via
`AppDatabase.memory()` — no emulator, milliseconds per test. Domain and tree
tests need no widget tree at all.

`test/migration_test.dart` is the exception: it hand-writes an old schema with
`NativeDatabase.memory(setup:)` and sets `PRAGMA user_version` before drift
opens the file, so the real `onUpgrade` runs against it. Worth the ceremony
from v7 onward, because that is the first migration that *rebuilds* a table
rather than adding a column — and a rebuild that dropped rows, lost the
indexes that went with the old table, or quietly forgot a `CHECK` would
surface on someone else's phone restoring a backup rather than here.

> **Widget tests must dispose the tree inside the test body.** Riverpod tears
> down `profileProvider` when the ProviderScope unmounts, which cancels drift's
> query stream, which schedules a zero-duration timer. Left to `testWidgets`'
> own teardown that timer is still pending when the fake clock stops and the
> test fails on `!timersPending`. End such tests with `disposeApp(tester)` —
> and note it pumps `Duration.zero` rather than a bare `pump()`, because
> `pump()` with no argument does not advance the fake clock at all.

> **Dispose a test-owned `ProviderContainer` *before* the last pump.** With
> `UncontrolledProviderScope` the test owns the container, so unmounting the
> tree does not dispose it — and disposing it cancels drift's query streams,
> scheduling the same zero-duration timer.

> **Riverpod 3 auto-disposes providers with no listeners.** In a bare
> `ProviderContainer` test, `read(provider.future)` can tear the element down
> before the underlying stream emits, and the future never completes — it
> presents as a 30-second timeout, not an error. Hold a subscription with
> `container.listen(provider, (_, _) {})` first. After a write, pump the event
> queue rather than re-reading `.future`, which completed on the first value
> and hands back the stale one.

> **Never write to a `TextEditingController` during `build`.** The Log-set
> button lives in the bottom bar and listens to the entry controller, so a
> write during build notifies a listener in another subtree — illegal, and it
> throws `setState() called during build`. Seeding is claimed synchronously
> and applied in a post-frame callback (`_afterFrame`).

> **Chips hit-test through their own `InkWell`, not the label.** Tap
> `find.ancestor(of: find.text(name), matching: find.byType(ChoiceChip))`, or
> the tap warns that it missed.

> **Scope finders when a dialog is open.** The screen behind it has its own
> `TextField`s and `ListTile`s; `find.byType(TextField).at(1)` will pick up
> whichever the tree happens to reach first.

> A failing widget test prints a stack trace per failure, which is enough
> output to get the runner killed before it reports. Filter to progress lines
> when a run dies without a summary:
>
> ```bash
> flutter test 2>&1 | grep -aE "^[0-9]{2}:[0-9]{2} |All tests passed|Some tests failed"
> ```

## Known gaps

- **The workout notification has never been verified on a device.** The
  analyzer and widget tests cover the content, the throttling and the deadline
  handed to the chronometer; the permission prompt, channel setup,
  `@mipmap/ic_launcher` reference — and whether the shade actually *renders*
  the countdown chronometer the way the docs say — have not been exercised.
- **iOS gets no rest chronometer.** `usesChronometer` is an Android notion, so
  an iOS user's shade shows the exercise and nothing counting down. The
  in-app timer and the audio cues are unaffected.
- **Release builds are signed with the debug key** (`android/app/build.gradle.kts`).
  A real signing config is required before distribution.
- **Editing a past session does not re-run progression.** Those rules fired at
  the end of that session and the user acted on them; silently re-deciding an
  advancement weeks later would be worse than a stale call.
- **`lib/screens/placeholder_scaffold.dart` is dead** — a leftover from the
  phased build, referenced by nothing.
- **The handstand chain is reachable from two paths** and shares one branch id
  (`hspu`). Cross-path rules live in `tree_rules.dart`; there is no general
  mechanism for them.
