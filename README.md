# Triple R

A free, offline companion for the
[Reddit Recommended Routine](https://www.reddit.com/r/bodyweightfitness/wiki/kb/recommended_routine/).
No account, no ads, no backend — everything lives on the device.

- **Package:** `com.nttech.triple_r`
- **Platforms:** Android and iOS
- **Sibling project:** [Roamfree](../step_counter), whose design language this
  shares (same Material 3 seed, same flat-surface style)

## Status

**Phase 0 — skeleton.** Project scaffold, theme, navigation shell, and the
drift database wired up with a host-VM test harness. The nine progression
paths, the workout engine, and the charts are not built yet; tabs that are
still empty say which phase fills them in.

See [`docs/PLAN.md`](docs/PLAN.md) for the full spec and phase roadmap.

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
