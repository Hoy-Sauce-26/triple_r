import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';

/// Overridden in tests with an in-memory database, and in [main] with the
/// instance opened at startup.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// The settings row. Watched rather than read so a unit-system change
/// repaints every screen showing a weight.
final profileProvider = StreamProvider<UserProfile>((ref) {
  return ref.watch(databaseProvider).watchProfile();
});
