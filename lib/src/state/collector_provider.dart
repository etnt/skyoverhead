/// Riverpod wiring for the collector opt-in flags (Phase 0).
///
/// [collectorPreferencesProvider] must be overridden in `main()` with a
/// concrete [CollectorPreferences] once `SharedPreferences` has loaded; it
/// throws if read without an override so a missing wiring fails loudly.
///
/// [collectorEnabledProvider] and [collectorPausedProvider] expose each flag as
/// a mutable `bool` the UI can watch and toggle; writes are persisted through
/// the underlying [CollectorPreferences].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_store.dart';

/// Supplies the persisted preferences implementation. Override in `main()`
/// (and in tests) with a concrete [CollectorPreferences].
final collectorPreferencesProvider = Provider<CollectorPreferences>((ref) {
  throw UnimplementedError(
    'collectorPreferencesProvider must be overridden with a concrete '
    'CollectorPreferences (see main()).',
  );
});

/// Master collector switch. Default `false` (identify-only).
final collectorEnabledProvider =
    StateNotifierProvider<CollectorFlagNotifier, bool>((ref) {
  final prefs = ref.watch(collectorPreferencesProvider);
  return CollectorFlagNotifier(
    initial: prefs.collectorEnabled,
    persist: prefs.setCollectorEnabled,
  );
});

/// Pause switch (keeps data, stops new logging). Default `false`.
final collectorPausedProvider =
    StateNotifierProvider<CollectorFlagNotifier, bool>((ref) {
  final prefs = ref.watch(collectorPreferencesProvider);
  return CollectorFlagNotifier(
    initial: prefs.collectorPaused,
    persist: prefs.setCollectorPaused,
  );
});

/// A boolean flag whose changes are written back to persistent storage.
class CollectorFlagNotifier extends StateNotifier<bool> {
  final Future<void> Function(bool) persist;

  CollectorFlagNotifier({
    required bool initial,
    required this.persist,
  }) : super(initial);

  /// Update the flag and persist it (no-op if unchanged).
  Future<void> set(bool value) async {
    if (state == value) return;
    state = value;
    await persist(value);
  }

  /// Flip the flag and persist the new value.
  Future<void> toggle() => set(!state);
}
