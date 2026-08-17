# Triple R — Implementation Spec (v2)

A free, offline, local-first Flutter app for the
[Reddit Recommended Routine](https://www.reddit.com/r/bodyweightfitness/wiki/kb/recommended_routine/).
No account, no backend, no network calls at runtime.

Shares the design language of **Roamfree** (`../step_counter`): Material 3,
`ColorScheme.fromSeed`, light + dark, minimal chrome, metric/imperial
throughout.

> This supersedes `TripleRImplementationPlan.md`. Changes from v1 are listed in
> [Appendix A](#appendix-a--changes-from-v1).

---

## 1. Decisions

| Axis | Decision |
| --- | --- |
| Persistence | `drift` (SQLite) — relational schema, typed queries, real migrations |
| State | `flutter_riverpod` |
| Charts | `fl_chart` |
| Timers / audio | `audioplayers`, `wakelock_plus`, `flutter_local_notifications` |
| Platform | Android **and** iOS |
| Units | Store SI, display metric or imperial — **imperial is the default** |
| Height | One-time profile setting, not a time series |
| Advancement | Auto-detected, user confirms via prompt |
| Load increment | User-entered at the prompt, remembered per exercise |
| Backup | JSON export + import, in scope for v1 |

### Deviations from Roamfree

Roamfree uses `sqflite` with a hand-written `DatabaseHelper`. Triple R uses
`drift` — the schema here has four related tables and real joins, which is
where drift earns its codegen. Test setup mirrors Roamfree's intent (DB tests
run on the host VM), using drift's `NativeDatabase.memory()` in place of
`sqflite_common_ffi`.

Roamfree is Android-only because of its background step service. Triple R has
no background-service dependency, so iOS is in scope.

---

## 2. The progression model

This is the core of the app. Everything else is UI over it.

### 2.1 Rep schemes

| Slot | Sets | Target | Advance when | Regress when |
| --- | --- | --- | --- | --- |
| Pair exercises | 3 | 5–8 reps | 3×8 with good form | cannot hit 3×5 |
| Core triplet | 3 rounds | 8–12 reps | 3×12 | cannot hit 3×8 |
| Timed holds | 3 | 30–60 s | 3×60 s | cannot hit 3×30 s |

Rest: **90 s** between exercises in a pair, **60 s** between triplet
exercises.

The pair and triplet numbers come from the RR itself. **The timed-hold range is
our own** — the RR does not give one, since holds appear mostly in the warmup
and in branches it treats loosely. 30–60 s is the conventional reading. It
lives in one constant and is easy to revise.

**Targets are targets, not caps.** The logger records what actually happened: a
75-second hold is stored as 75, an 11-rep set against an 8-rep target is stored
as 11, and a 22-second hold is stored as 22. No input is clamped to the range.
The range only decides which *prompt* fires afterwards, and how far past or
short of it the user landed is exactly the signal that makes progression and
regression decisions trustworthy.

### 2.2 Advancement

Evaluated when the last set of an exercise is logged, against **that session
only** (not a rolling window):

- All 3 sets at the top of the range → offer to advance. Next session starts
  at the bottom of the range on the new exercise.
- Any set below the bottom of the range → offer to regress, but only after
  **two consecutive** sessions that fail. One bad day is not a deload.
- Otherwise → stay, target stays at the top of the range.

Both are **prompts, never silent**. Declining is remembered for that session
and re-offered next time the condition holds. A user can always override the
current exercise from the Progression Configuration screen.

**Weighted branches progress differently.** Barbell squats, deadlifts, weighted
pull-ups/dips/rows and Pallof press are terminal nodes: there is no next
exercise, so advancement means *adding load* at a fixed rep target. Hitting the
top of the range prompts "add 2.5 lb?" instead of "move on?". This is the
`ProgressionMode.load` vs `ProgressionMode.exercise` distinction in the data
model.

**Progression state is keyed by exercise, not by path.** Working load and the
consecutive-failure counter live in `exercise_state` (§4), because a single
path can have two exercises in flight at once — see alternating branches below
— each carrying its own weight and its own cadence. Keying by exercise also
makes failure counts reset for free when the user advances to a new node.

### 2.2.1 Load increments and units

There is no configured increment. The "add weight?" prompt presents an
**editable amount, pre-filled with whatever the user entered last time for that
exercise**, and shows the resulting total live:

```
Nice work — 3×8 on Barbell Deadlift.
Add   [ 10 ] lb   →  195 lb
                              [ Not yet ]  [ Add ]
```

Whatever they confirm becomes the new remembered value for that exercise. On
the very first prompt there is nothing to remember, so it seeds at 2.5 lb
(1 kg in metric) — a value the user corrects once and never thinks about
again.

This is deliberately not a setting. Available plates vary by gym and by
exercise, they change when someone travels or switches gyms, and a user
micro-loading weighted pull-ups with 1.25 lb plates while jumping deadlifts by
10 lb is completely normal. A remembered field at the point of use handles all
of that without a settings screen, and self-corrects the moment reality
changes.

**Regression works the same way in reverse.** For load-mode exercises,
regression means reducing weight, not moving to an easier exercise — same
field, same remembered amount, subtracting.

Loads are stored canonically in kg but **arithmetic happens in the user's
display unit**, converted once on write. Doing it the other way — converting
10 lb to 4.536 kg and adding that — accumulates drift that eventually surfaces
as weights like 194.7 lb. Displayed weights round to 0.5 lb / 0.25 kg.

> A user switching unit systems mid-training will see 45 lb become 20.5 kg.
> That is correct and unavoidable with a single canonical unit; it is worth
> knowing it will look odd the first time.

### 2.2.2 Alternating branches

Most branches are linear: one current exercise that advances over time. The
**barbell hinge branch is not**. While on it, the user performs Romanian
deadlifts on days 1 and 3 of the week and barbell deadlifts on day 2, repeating
weekly.

Expressed as a pattern indexed by `completedSessions % 3`:

| Session index | 0 | 1 | 2 |
| --- | --- | --- | --- |
| Exercise | RDL | Barbell Deadlift | RDL |

which yields RDL, DL, RDL, RDL, DL, RDL, … across weeks — days 1 and 3 as
specified, with the week boundary falling between two RDL sessions.

Consequences, all handled below:

- **Both exercises are simultaneously "current."** For an alternating branch
  `selected_exercise_id` is NULL; the exercise is resolved from the pattern at
  session start.
- **Each progresses independently**, on its own load and its own failure
  counter, evaluated only on sessions where it was actually performed. This is
  the concrete reason load moved out of `user_progression_configs`.
- **Analytics must not merge them.** Two separate series under one path.

### 2.3 Static tree shape

Trees are hardcoded Dart constants (not JSON — no reason to pay parse cost or
lose type safety for data that ships with the binary).

```dart
enum Metric { reps, timed }
enum ProgressionMode { exercise, load }
enum BranchKind { linear, alternating }

class Exercise {
  final String id;          // stable slug — see §2.4
  final String name;        // display name, free to change
  final Metric metric;
  final bool perSide;       // orthogonal to metric — see note below
  final bool loadable;      // shows a weight field
  final ProgressionMode mode;
  final String? wikiUrl;
}

class Branch {
  final String id;
  final String name;
  final int attachesAtLevel; // 1-based level on the canonical line
  final bool isDefault;
  final BranchKind kind;
  final List<String> exerciseIds;

  /// Alternating branches only. Indexes into [exerciseIds], cycled by
  /// `completedSessions % pattern.length`. Null for linear branches, where
  /// [exerciseIds] is instead an ordered progression.
  final List<int>? pattern;
}

class Path {
  final String id;
  final String name;
  final Slot slot;             // pair1a, pair1b, ... triplet3
  final List<String> trunkIds; // shared prefix, may be empty
  final List<Branch> branches;
}
```

> **`perSide` is a flag, not a `Metric` value.** The first draft had
> `Metric { reps, repsPerSide, timed }`, which cannot express Copenhagen
> Planks — marked `[S][T]`, timed *and* per side. The two are independent
> axes, so `perSide` is its own bool.

> **`attachesAtLevel` counts along the canonical line**, defined as
> `trunkIds + defaultBranch.exerciseIds` — not the trunk alone, as the first
> draft said. The squat path forced this: its trunk is two exercises, but
> `stepup` and `pistol` fork at level 5, and levels 3–4 (Split Squats,
> Bulgarian Split Squats) live inside the default `bodyweight` branch. A
> branch forking above the trunk is therefore reachable only by having
> travelled the default branch to get there.

A user's progression for a path on a linear branch is:

```
canonicalLine[0 .. branch.attachesAtLevel - 2] ++ branch.exerciseIds
```

For an alternating branch the trunk prefix is identical, but the branch tail is
a rotation rather than a ladder — the exercise for a given session is
`exerciseIds[pattern[completedSessions % pattern.length]]`.

This is the fix for v1's biggest structural problem: v1 sometimes listed the
shared trunk bare (Pull-up) and sometimes folded it into "Option A" (Squat,
Dip, Hinge, Row, Push-up). Those are two different data shapes and no single
schema fits both. Here the trunk is always explicit and every branch declares
where it forks — which also expresses "this branch only unlocks at 3×8
pull-ups" naturally, as `attachesAtLevel: 5`.

### 2.4 Exercise ID stability

`set_records.exercise_id` is a free-text slug with no foreign key to a catalog
table, because the catalog ships in code. **Once released, an ID is permanent.**
Renaming one orphans every historical set that referenced it.

So: IDs are slugs, display names are separate, and the two are never assumed
equal. v1's tree contained typos (`Copenhagne Planks`, `Hamstring Slids`) that
would have become permanent primary keys. Display names are corrected below;
IDs are chosen deliberately.

Retiring an exercise is a display-layer concern — the ID stays resolvable
forever so history renders.

---

## 3. Exercise trees

Nine paths. `[L]` = accepts external load, `[T]` = timed, `[S]` = per side.

### Warmup (dynamic)

5–10 minutes. Items 5–8 are **gated on progression state** — they appear only
once the user reaches the trigger exercise. v1 listed the warmup as a static
checklist, which is wrong and also drops Hinge Activation.

| # | Item | Target | Unlocked by |
| --- | --- | --- | --- |
| 1 | Shoulder Dislocates | 5–10 reps | always |
| 2 | Squat Sky Reaches | 5–10 per side | always |
| 3 | Wrist Prep | 10+ reps | always |
| 4 | Deadbugs | 30 s `[T]` | always |
| 5 | Arch Hangs | 10 reps | reaching Pull-up Eccentrics |
| 6 | Support Hold | 30 s `[T]` | reaching Dip Eccentrics |
| 7 | Squat Activation | 10 reps | reaching Bulgarian Split Squats |
| 8 | Hinge Activation | 10 reps | reaching Banded Nordic Curls |

Warmup completion is not logged historically — it lives in the session cursor
only. Nothing charts it and nothing progresses from it.

> v1 listed "YTWLs" for item 1. The RR specifies band/broomstick shoulder
> dislocates; YTWLs are a common substitute. Offering both as a toggle is a
> reasonable future addition, not a launch requirement.

### Pair 1 — Vertical Pull & Quads

**Path `pullup` — [Pull-up](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/pullup/)**

Trunk: Scapular Pulls → Arch Hangs → Pull-up Eccentrics → Full Pull-ups

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `weighted` (default) | 5 | Weighted Pull-ups `[L]` — load mode |
| `lsit` | 5 | L-sit Pull-ups |
| `arch` | 5 | Arch-body Pull-ups |
| `typewriter` | 5 | Type-writer Pull-ups → Archer Pull-ups |

**Path `squat` — [Squat](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/squat/)**

Trunk: Assisted Squats → Full Squats

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `bodyweight` (default) | 3 | Split Squats `[S]` → Bulgarian Split Squats `[S]` → Beginner Shrimp Squats `[S]` → Intermediate Shrimp Squats `[S]` → Advanced Shrimp Squats `[S]` → Weighted Shrimp Squats `[S][L]` |
| `barbell` | 3 | Barbell Back Squats `[L]` — load mode |
| `stepup` | 5 | Step-ups `[S]` → Deep Step-ups `[S]` |
| `pistol` | 5 | Partial ROM Pistol Squats `[S]` → Pistol Squats `[S]` |

> `stepup` and `pistol` fork at 5, so they require Bulgarian Split Squats
> first — they are only reachable from the `bodyweight` branch. The config
> screen must gate them accordingly.

### Pair 2 — Vertical Push & Hinge

**Path `dip` — [Dip](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/dip/)**

Trunk: Parallel Bar Support Hold `[T]` → Dip Eccentrics → Parallel Bar Dips

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `weighted` (default) | 4 | Weighted Dips `[L]` — load mode |
| `rings` | 4 | Ring Dips → Ring RTO Dips |
| `hspu` | 4 | *shared HSPU chain, see below* |

**Path `hinge` — [Hinge](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/hinge)**

Trunk: Romanian Deadlifts

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `bodyweight` (default) | 2 | Single Legged Deadlifts `[S]` → Banded Nordic Curl Eccentrics → Banded Nordic Curls → Nordic Curls |
| `barbell` | 2 | **Alternating** — Barbell Romanian Deadlift `[L]` / Barbell Deadlift `[L]`, pattern `[0, 1, 0]` — load mode |
| `slide` | 3 | Floor Slide Progressions → Hamstring Slide Eccentrics → Hamstring Slides → Single Leg Sliding Hamstring Slide Eccentrics `[S]` → Single Leg Sliding Hamstring Slides `[S]` |
| `harop` | 3 | Beginner Harop Curls → Advanced Harop Curls |
| `ghr` | 3 | Glute Ham Raises |

> **Resolved from v1:** lines 160–161 gave RDL and Barbell Deadlift both as
> step "2". Neither sequential nor either/or — they **semi-alternate**: RDL on
> days 1 and 3, barbell deadlift on day 2, weekly. This is the only alternating
> branch in the app, and the reason `BranchKind` and `exercise_state` exist
> (§2.2.2). Both carry independent working weights.

### Pair 3 — Horizontal Pull & Push

**Path `row` — [Row](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/row/)**

Trunk: Vertical Rows → Incline Rows → Horizontal Rows → Wide Rows

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `weighted` (default) | 5 | Weighted Rows `[L]` — load mode |
| `frontlever` | 5 | Tuck Front Levers `[T]` → Tuck Front Lever Pulls |
| `onearm` | 5 | Archer Rows `[S]` → One Arm Rows `[S]` |

**Path `pushup` — [Push-up](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/pushup/)**

Trunk: Wall Push-ups → Incline Push-ups → Full Push-ups → Diamond Push-ups

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `pseudoplanche` (default) | 5 | Pseudo Planche Push-ups |
| `rings` | 5 | Ring Push-ups → RTO Push-ups → RTO PPPUs |
| `hspu` | 5 | *shared HSPU chain, see below* |

**Shared HSPU chain** — [wiki](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/hspu/)

Pike Push-ups → Box Push-ups → Wall Headstand Push-up Eccentrics → Wall
Headstand Push-ups → Wall Handstand Push-ups → Freestanding Headstand Push-ups
→ Freestanding Handstand Push-ups

v1 duplicated this list under both Dip Option C and Push-up Option C at
different step numbers. It is **one** set of exercise IDs referenced by two
branches. The config screen must prevent selecting `hspu` for both `dip` and
`pushup` simultaneously — otherwise the same movement fills two slots in one
workout.

### Core Triplet — 3 rounds, 8–12 reps, 60 s rest

**Path `antiextension` — [Anti-Extension](https://www.reddit.com/r/bodyweightfitness/wiki/exercises/core/#wiki_anti-extension)**

Trunk: Planks `[T]`

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `rings` (default) | 2 | Ring Ab Rollouts |
| `abwheel` | 2 | Kneeling Ab Wheel Rollouts → Standing Ab Wheel Rollouts |
| `hanging` | 2 | Tucked Hanging Leg Raises → Pike Hanging Leg Raise Eccentrics → Straight Hanging Leg Raises |
| `compression` | 2 | Pike Compressions |

> **Resolved from v1:** two branches were both labelled "Option C" (lines 252,
> 258). Renamed to `hanging` and `compression`.

**Path `antirotation` — Anti-Rotation / Anti-Lateral Flexion**

No shared trunk — the branches are genuinely independent entry points.

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `ringpallof` (default) | 1 | Ring Pallof Press `[S]` |
| `weightedpallof` | 1 | Pallof Press `[S][L]` — load mode |
| `copenhagen` | 1 | Assisted Knee Copenhagen Planks `[S][T]` → Knee Copenhagen Planks `[S][T]` → Assisted Copenhagen Planks `[S][T]` → Copenhagen Planks `[S][T]` → Copenhagen Planks with Movement `[S][T]` |

> v1's diagram called this slot "Anti-Lateral" (line 45) while the path heading
> said "Anti-Rotation" (line 263). Both are accurate for different branches —
> Pallof is anti-rotation, Copenhagen is anti-lateral-flexion. Display name
> settled as "Anti-Rotation"; ID is `antirotation`.

**Path `extension` — Extension / Rear Chain**

| Branch | Forks at | Exercises |
| --- | --- | --- |
| `arch` (default) | 1 | Arch Raises → Arch Body Holds `[T]` → Arch Body Rocks |
| `reversehyper` | 1 | Reverse Hyperextensions |
| `hyper` | 1 | Hyperextensions |

---

## 4. Database schema

```sql
-- Singleton profile row.
CREATE TABLE user_profile (
    id                           INTEGER PRIMARY KEY CHECK (id = 1),
    height_cm                    REAL,
    unit_system                  TEXT    NOT NULL DEFAULT 'imperial',
    default_pair_rest_seconds    INTEGER NOT NULL DEFAULT 90,
    default_triplet_rest_seconds INTEGER NOT NULL DEFAULT 60,
    rotate_pair_order            INTEGER NOT NULL DEFAULT 1
);

-- Body weight over time. Height lives in user_profile; it does not change.
CREATE TABLE body_weight_entries (
    id          TEXT PRIMARY KEY,
    recorded_at DATETIME NOT NULL,
    weight_kg   REAL     NOT NULL
);
CREATE INDEX idx_bwe_recorded ON body_weight_entries(recorded_at);

-- Which branch of each of the 9 paths the user is on, and where in it.
-- selected_exercise_id is NULL for alternating branches, where the exercise
-- is resolved from the branch pattern at session start (§2.2.2).
CREATE TABLE user_progression_configs (
    path_id              TEXT PRIMARY KEY,
    selected_branch_id   TEXT     NOT NULL,
    selected_exercise_id TEXT,
    updated_at           DATETIME NOT NULL
);

-- Per-exercise progression state. Keyed by exercise rather than path because
-- an alternating branch has two exercises in flight at once, each with its own
-- working weight and its own failure cadence. Rows are created lazily.
CREATE TABLE exercise_state (
    exercise_id          TEXT PRIMARY KEY,
    working_load_kg      REAL     NOT NULL DEFAULT 0.0,
    last_increment_kg    REAL,               -- NULL → seed the prompt at 2.5 lb / 1 kg
    consecutive_failures INTEGER  NOT NULL DEFAULT 0,
    updated_at           DATETIME NOT NULL
);

CREATE TABLE workout_sessions (
    id                   TEXT PRIMARY KEY,
    started_at           DATETIME NOT NULL,
    ended_at             DATETIME,           -- NULL while in progress
    status               TEXT     NOT NULL,  -- in_progress | completed | abandoned
    rotation_index       INTEGER  NOT NULL,  -- 0 | 1 | 2
    pair_rest_seconds    INTEGER  NOT NULL,
    triplet_rest_seconds INTEGER  NOT NULL,
    cursor_json          TEXT                -- resume point; NULL once finished
);
CREATE INDEX idx_sessions_started ON workout_sessions(started_at);

CREATE TABLE set_records (
    id             TEXT     PRIMARY KEY,
    session_id     TEXT     NOT NULL,
    path_id        TEXT     NOT NULL,
    exercise_id    TEXT     NOT NULL,
    set_index      INTEGER  NOT NULL,
    reps_completed INTEGER,                    -- NULL for timed holds
    hold_seconds   INTEGER,                    -- NULL for rep-based
    weight_kg      REAL     NOT NULL DEFAULT 0.0,
    recorded_at    DATETIME NOT NULL,
    FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE,
    CHECK ((reps_completed IS NULL) != (hold_seconds IS NULL))
);
CREATE INDEX idx_sets_session  ON set_records(session_id);
CREATE INDEX idx_sets_exercise ON set_records(exercise_id, recorded_at);
```

### Notes on the schema

**`ended_at` is nullable and `status` exists.** v1 had `end_time NOT NULL`,
which contradicted its own promise to persist active workout state. A session
row is written at *start*; `cursor_json` holds the resume point so a crash or
force-quit mid-workout does not lose logged sets.

**`reps_completed` / `hold_seconds` are mutually exclusive.** v1 had only
`reps_completed INTEGER NOT NULL` yet annotated a dozen exercises as
"Requires Timed Sets". The CHECK constraint enforces exactly one.

**Per-side exercises store one number, meaning "per side."** The exercise's
`perSide` flag tells the UI to label it "× 8 per side" and tells
analytics not to compare it against bilateral volume. Tracking left and right
separately is deliberately out of scope — the RR does not distinguish them, and
two more columns would complicate every read path for a feature nobody asked
for. Revisit if it comes up.

**Set count is not hardcoded to 3.** `set_index` is an integer; the "3" lives
in the rep-scheme config, so a future 5-set variant needs no migration.

**`reps_completed` and `hold_seconds` are uncapped.** They record what the user
did, not what the target was — 11 reps against an 8-rep target stores 11, a
22-second hold stores 22. The target is not in `set_records` at all; it is
recomputed from the tree and the rep scheme when needed, so a later change to
the scheme does not retroactively rewrite history.

**Weight is denormalized onto `set_records`.** `weight_kg` records the load
actually used for that set, independent of `exercise_state.working_load_kg`
(which is only the *next* prescription). Without this, raising a working weight
would silently rewrite every past set's load.

**`completedSessions` is derived**, not stored:
`SELECT COUNT(*) FROM workout_sessions WHERE status = 'completed'`. Abandoned
sessions do not advance the rotation.

---

## 5. Session flow

### 5.1 Rotation

The three pairs rotate by `completedSessions % 3`:

| Index | Order |
| --- | --- |
| 0 | Pair 1 → Pair 2 → Pair 3 → Triplet |
| 1 | Pair 2 → Pair 3 → Pair 1 → Triplet |
| 2 | Pair 3 → Pair 1 → Pair 2 → Triplet |

`rotation_index` is stored on the session, so history stays truthful even if
the count later changes.

> **This is not part of the RR.** The RR prescribes a fixed order. Rotation is
> our addition to spread fatigue bias, and it is a **setting**
> (`rotate_pair_order`, default on) rather than doctrine. Users who want the
> book routine can turn it off.

### 5.2 Execution

1. **Begin Workout** — session row written, `status = in_progress`, wakelock
   acquired, global timer starts.
2. **Warmup** — checklist filtered by progression state (§3). Timed items get
   inline countdowns with an audio cue at zero.
3. **Pairs**, in rotation order. For each pair, alternating A/B:
   `A1 → rest → B1 → rest → A2 → rest → B2 → rest → A3 → rest → B3 → rest`.
   The rest after B3 is real — v1 dropped it and jumped straight to the next
   pair.
4. **Triplet** — 3 rounds of G → H → I, 60 s between every exercise.
5. **Summary** — `status = completed`, `ended_at` set, `cursor_json` cleared,
   volume aggregated, advancement/regression prompts shown (§2.2).

### 5.3 Things the user will actually do

v1 assumed a clean happy path. These are required, not polish:

- **Skip an exercise** — logs nothing, does not count toward advancement.
- **Edit a logged set** — tap any completed set to correct it.
- **End early** — `status = abandoned`. Sets already logged are kept; the
  session does not advance the rotation counter.
- **Resume** — reopening the app with an `in_progress` session offers to
  resume from `cursor_json` or discard.
- **Skip / extend rest** — the countdown is a suggestion, with +30 s and Skip.

### 5.4 Rest timer defaults

Rest times are **profile settings** with a per-session override, not a prompt
before every workout. v1 put timer configuration at step 3 of every session,
which is friction on a value that changes maybe twice a year.

---

## 6. Screens

- **Dashboard** — next session's rotation and exercises, body weight summary,
  Begin Workout, resume banner if a session is in progress.
- **Progression Config** — nine paths, each showing current exercise, branch
  selector (gated per §3), load input for `[L]` exercises, and a manual
  override.
- **Active Workout** — session timer, current exercise with target pre-filled,
  rep/hold logger, rest overlay with audio + haptics, set history for the
  current exercise.
- **Analytics** — body weight over time; **per-exercise** strength charts.
- **History** — session list, drill into any past workout.
- **Settings** — units, rest defaults, load increment, rotation toggle, and
  **Export / Import** (§6.1).

### 6.1 Export and import

Local-only storage means a lost phone is lost training history, so backup is a
v1 requirement rather than polish.

- **Export** writes a single JSON file — every table, plus a `schema_version`
  and an export timestamp — and hands it to the OS share sheet (`share_plus`).
- **Import** takes a file via `file_picker`, validates `schema_version`, and
  **replaces** the local database wholesale after an explicit confirmation that
  names how many sessions are about to be discarded.

Import is replace-only, not merge. The use case is "I got a new phone," where
replace is correct and obvious; merging two divergent histories raises
questions about duplicate sessions and conflicting progression state that
nothing here needs answered.

`schema_version` is what makes an export from an older build still importable
later — imports run through the same drift migrations as an on-device upgrade.

> **Analytics correction.** v1 specified "rep/weight progression charts for each
> selected exercise path." Charting reps across a *path* produces a sawtooth —
> reps reset to 5 every time the user advances. Charts are **per exercise**,
> with advancement events marked on a path-level timeline so the user sees
> progress as "moved from Full Push-ups to Diamond Push-ups on 3 March," not as
> a graph that appears to go backwards.

---

## 7. Roadmap

Each phase ships with tests. v1 deferred all testing to Phase 5; the rotation
engine, advancement rule, and DB layer are pure logic and are exactly what
should be tested first.

**Phase 0 — Skeleton.** Flutter project, deps, Material 3 theme matching
Roamfree, bottom-nav shell, drift wired up with an in-memory test harness.

**Phase 1 — Data engine.** Full schema + migrations. All nine trees as typed
constants. Progression Config screen. *Tests: tree integrity (no duplicate IDs,
every `attachesAtLevel` in range, every branch resolves), DB round-trips.*

**Phase 2 — Progression logic.** Advancement and regression rules, alternating
branch resolution, unit conversion and load increments, the derived warmup
gating, rotation engine. Pure Dart, no UI. *Tests: this is the phase that most
needs them — every rep-scheme boundary, both progression modes,
consecutive-failure counting, the hinge pattern across a multi-week run, and
lb↔kg round-tripping across repeated increments.*

**Phase 3 — Timers & warmup.** Riverpod session stopwatch and rest countdowns,
`audioplayers` cues, `wakelock_plus`, local notifications, iOS audio session.
Warmup screen. *Tests: timer state machine with a fake clock.*

**Phase 4 — Active workout.** Guided pair/triplet flow, set logging with
pre-filled targets, resume, skip, edit, abandon. *Tests: full session
walkthrough against an in-memory DB.*

**Phase 5 — Metrics, analytics & data.** Weight/height logging, `fl_chart`
charts, history viewer, Settings screen, export/import. *Tests: export→import
round-trip preserves every table; import from a prior `schema_version`
migrates.*

**Phase 6 — Polish.** Typography, haptics, empty states, airplane-mode
end-to-end pass.

---

## 8. Resolved questions

All five open questions from the first draft are settled.

1. **Hinge barbell branch** — semi-alternating, not sequential: RDL on days 1
   and 3, barbell deadlift on day 2, weekly. Drove `BranchKind.alternating` and
   the `exercise_state` table (§2.2.2).
2. **Timed-hold scheme** — 30–60 s confirmed, with actual values recorded above
   and below the range rather than clamped (§2.1).
3. **Load increment** — not configured at all. The prompt offers an editable
   amount pre-filled with the last one used for that exercise, seeded at 2.5 lb
   on first use. Imperial is the default unit system (§2.2.1).
4. **Backup** — JSON export/import is in scope, Phase 5, replace-on-import
   (§6.1).
5. **Deload** — out of scope. The per-exercise regression rule is the only
   backward movement the app models; whole-routine deloads are left to the
   user.

Nothing is left assumed.

---

## Appendix A — Changes from v1

**Blocking gaps filled**

- Progression and regression rules specified (absent entirely in v1).
- Rep schemes added: 3×5–8 pairs, 3×8–12 triplet.
- `hold_seconds` column added for the ~12 exercises v1 marked "Requires Timed
  Sets" but had nowhere to store.
- Per-side exercises given an explicit metric and semantics.
- Trunk/branch shape unified — v1 used two incompatible layouts.
- `ended_at` made nullable with `status` + `cursor_json`, resolving v1's
  contradiction between resumable sessions and a `NOT NULL` end time.
- Load-mode progression distinguished from exercise-mode.

**Factual corrections**

- Core triplet is 8–12 reps, not the 5–8 implied by uniform treatment.
- Warmup is progression-gated, not static; Hinge Activation was missing.
- Warmup item 1 is Shoulder Dislocates, not YTWLs.

**Errors fixed**

- Duplicate "Option C" in Anti-Extension.
- Ambiguous double-"2." in Hinge Option B (resolved, flagged).
- Broken markdown link on Dip Progression (double parens).
- Typos that would have become permanent IDs: "Copenhagne", "Hamstring Slids".
- HSPU chain de-duplicated into one shared list, with a mutual-exclusion rule.
- "Anti-Lateral" / "Anti-Rotation" naming settled.

**Additions**

- Skip / edit / abandon / resume flows.
- Rest after the final set of a pair.
- Rest times as settings, not a per-session prompt.
- Per-exercise analytics instead of misleading per-path rep charts.
- Height moved out of the time series.
- Unit system.
- Exercise ID stability policy.
- Rotation made an optional setting and flagged as non-RR.
- Tests in every phase; Phase 0 skeleton added.

**Corrected during Phase 1 implementation**

- `perSide` split out of `Metric` — the three-valued enum could not represent
  Copenhagen Planks, which are timed *and* per side.
- `attachesAtLevel` redefined to index the canonical line (trunk + default
  branch) rather than the trunk, which the squat path's `stepup` and `pistol`
  branches broke.
- Branch gating exempts the default branch and the user's current branch from
  the level check — otherwise squat's default branch, which forks at level 3,
  renders as locked for a beginner sitting at level 1 on it.

**Added after review**

- Alternating branches (`BranchKind`, `pattern`) for the semi-alternating
  barbell hinge.
- `exercise_state` table; load and failure counters moved off
  `user_progression_configs`, which could not hold two simultaneous exercises.
- `selected_exercise_id` made nullable for alternating branches.
- Imperial as the default unit system; load increments entered at the prompt
  and remembered per exercise rather than configured; increment arithmetic
  specified in display units; load-mode regression defined.
- Logged reps and holds explicitly uncapped.
- Export/import promoted from open question to a Phase 5 requirement.
- Deloads confirmed out of scope.
