import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/active_session.dart';
import 'active_workout_screen.dart';
import 'warmup_screen.dart';

/// The whole workout — warmup and sets — behind a single route.
///
/// The warmup used to `pushReplacement` itself with the workout screen, which
/// looked harmless and was not: replacing a route completes the *replaced*
/// route's popped future, so the dashboard's `await push(warmup)` returned the
/// instant the user tapped "Start workout". The teardown waiting on that
/// future then ran mid-workout — stopping the session clock (it froze at
/// 0:00) and releasing the wakelock (the screen slept between sets).
///
/// One route for the whole flow removes the seam rather than papering over it:
/// the dashboard's future now completes exactly when the user leaves the
/// workout, which is the only moment the clock and wakelock should stop.
/// Which half is showing is derived from the session cursor, so it survives a
/// rebuild and a resume without any navigation state of its own.
class WorkoutFlowScreen extends ConsumerWidget {
  const WorkoutFlowScreen({super.key, this.skipWarmup = false});

  /// Set when resuming an interrupted session — the user has already warmed
  /// up, and making them tick the boxes again to get back to their sets is
  /// the app getting in the way.
  final bool skipWarmup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;

    // Null both before the session loads and in the moment after it is
    // finished, while the summary route is being pushed over this one.
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return skipWarmup || session.cursor.warmupComplete
        ? const ActiveWorkoutScreen()
        : const WarmupScreen();
  }
}
