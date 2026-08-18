# Triple R

A free, offline companion for the
[Reddit Recommended Routine](https://www.reddit.com/r/bodyweightfitness/wiki/kb/recommended_routine/).
No account, no ads, no backend — everything lives on the device.

- **Package:** `com.nttech.TripleR` (local dev builds install alongside as
  `com.nttech.TripleR.dev`, with their own database)
- **Platforms:** Android and iOS
- **Sibling project:** [Roamfree](../step_counter), whose design language this
  shares (same Material 3 seed, same flat-surface style)

## Status

**Phase 6 complete.** All six phases are in: the progression trees, the
database, the timers and warmup, the guided pair/triplet workout, the charts
and history, and backup/restore.

The warmup and the workout live behind a single route,
[`WorkoutFlowScreen`](lib/screens/workout_flow_screen.dart), so the session
clock and the wakelock belong to the session rather than to a navigation
stack — see the notes there before splitting them apart again.

See [`docs/PLAN.md`](docs/PLAN.md) for the full spec and phase roadmap.

## Layout

| Directory | Holds |
| --- | --- |
| `lib/trees/` | The nine progression trees as typed constants, plus branch-gating rules |
| `lib/domain/` | Pure logic: rep schemes, advance/regress evaluation, units, countdown math, session planning |
| `lib/data/` | drift database, tables, migrations |
| `lib/services/` | Platform edges — clock, audio, haptics, wakelock, notifications. Each is an interface with a fake |
| `lib/state/` | Riverpod controllers that drive services from domain state |
| `lib/screens/` | UI |

`lib/domain/` and `lib/trees/` have no Flutter dependency beyond types, which
is why the rules can be tested exhaustively without a widget tree.

## Architecture

| Layer | Choice |
| --- | --- |
| State | `flutter_riverpod` |
| Persistence | `drift` (SQLite) |
| Charts | `fl_chart` *(Phase 5)* |
| Timers & audio | `audioplayers`, `wakelock_plus` *(Phase 3)* |

Dependencies are added in the phase that first uses them, so the manifest
stays an honest description of what the app actually does.

### The database is the app

There is no server and no sync. `lib/data/database.dart` holds the single
`AppDatabase`, opened once in `main()` and injected through `databaseProvider`
— which throws if it is not overridden, so a test can never accidentally open
the real on-device file.

Every schema change needs a `schemaVersion` bump *and* a migration step, even
pre-release. Exported backups carry their `schemaVersion` and are re-imported
through these same migrations, so a skipped step breaks restore on someone
else's phone rather than failing loudly here.

### Testing

Database tests run on the host VM against real SQLite via
`AppDatabase.memory()` — no emulator, no device, milliseconds per test:

```bash
flutter test
```

> **Widget tests must dispose the tree inside the test body.** Riverpod tears
> down `profileProvider` when the ProviderScope unmounts, which cancels drift's
> query stream, which schedules a zero-duration timer. Left to `testWidgets`'
> own teardown that timer is still pending when the fake clock stops and the
> test fails on `!timersPending`. End such tests with `disposeApp(tester)` —
> and note it pumps `Duration.zero` rather than a bare `pump()`, because
> `pump()` with no argument does not advance the fake clock at all.

> **Timers are deadline-based, never decrement-based.** A running countdown
> stores the instant it ends and derives what is left. A phone that sleeps or
> throttles timers delivers one late tick instead of hundreds on time, and a
> decrementing counter would come back that much wrong. Tests drive `FakeClock`
> and `FakeTicker` directly, so a 90-second rest costs no wall time.

> **Republish a new instance on each tick.** Riverpod compares by identity, so
> `state = state` notifies nobody — the timer keeps running while the on-screen
> seconds freeze. `Countdown.tick()` exists solely to return a distinct object.
> Unit tests read `remaining` directly and cannot see this; only a widget test
> catches it.

> **Dispose a test-owned `ProviderContainer` *before* the last pump.** With
> `UncontrolledProviderScope` the test owns the container, so unmounting the
> tree does not dispose it — and disposing it cancels drift's query streams,
> scheduling the same zero-duration timer described above. Dispose, then pump.

> **Riverpod 3 auto-disposes providers with no listeners.** In a bare
> `ProviderContainer` test, `read(provider.future)` can tear the element down
> before the underlying stream emits, and the future never completes — it
> presents as a 30-second timeout, not an error. Hold a subscription with
> `container.listen(provider, (_, _) {})` first. After a write, pump the event
> queue rather than re-reading `.future`, which completed on the first value
> and hands back the stale one.

> A failing widget test prints a stack trace per failure, which is enough
> output to get the runner killed before it reports. Filter to progress lines
> when a run dies without a summary:
>
> ```bash
> flutter test 2>&1 | grep -aE "^[0-9]{2}:[0-9]{2} |All tests passed|Some tests failed"
> ```

## Code generation

drift generates `lib/data/database.g.dart`. After changing anything under
`lib/data/`:

```bash
dart run build_runner build
```
