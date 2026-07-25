/// Riverpod wiring for the collector opt-in flags (Phase 0).
///
/// [collectorPreferencesProvider] defaults to a non-persistent, disabled
/// implementation so that, if it is never overridden, collecting is simply off
/// (privacy-first) rather than erroring. `main()` overrides it with a
/// `SharedPreferences`-backed implementation once storage has loaded.
///
/// [collectorEnabledProvider] and [collectorPausedProvider] expose each flag as
/// a mutable `bool` the UI can watch and toggle; writes are persisted through
/// the underlying [CollectorPreferences].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_store.dart';

/// Supplies the persisted preferences implementation. Defaults to a disabled
/// in-memory implementation; override in `main()` with a concrete persisted
/// [CollectorPreferences].
final collectorPreferencesProvider = Provider<CollectorPreferences>((ref) {
  return InMemoryCollectorPreferences();
});

/// The selected bottom-navigation tab index in the collector app shell. Exposed
/// as shared state so screens (e.g. the Sky tab's rank badge) can navigate to
/// another tab. `0` = Sky, `1` = Logbook, `2` = Medals, `3` = Stats.
final selectedTabProvider = StateProvider<int>((ref) => 0);

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

/// Airport codes hidden from the Stats top lists (persisted). Empty by default.
final excludedAirportsProvider =
    StateNotifierProvider<ExcludedAirportsNotifier, Set<String>>((ref) {
  final prefs = ref.watch(collectorPreferencesProvider);
  return ExcludedAirportsNotifier(
    initial: prefs.excludedAirports,
    persist: prefs.setExcludedAirports,
  );
});

/// A persisted set of excluded airport codes, normalised to upper-case.
class ExcludedAirportsNotifier extends StateNotifier<Set<String>> {
  final Future<void> Function(Set<String>) persist;

  ExcludedAirportsNotifier({
    required Set<String> initial,
    required this.persist,
  }) : super(Set.unmodifiable({
          for (final c in initial)
            if (_norm(c).isNotEmpty) _norm(c),
        }));

  static String _norm(String code) => code.trim().toUpperCase();

  /// Hide [code] from the stats top lists (no-op if already hidden or blank).
  Future<void> add(String code) async {
    final n = _norm(code);
    if (n.isEmpty || state.contains(n)) return;
    state = Set.unmodifiable({...state, n});
    await persist(state);
  }

  /// Restore [code] to the stats top lists (no-op if not currently hidden).
  Future<void> remove(String code) async {
    final n = _norm(code);
    if (!state.contains(n)) return;
    state = Set.unmodifiable(state.where((c) => c != n).toSet());
    await persist(state);
  }

  /// Whether [code] is currently hidden.
  bool contains(String code) => state.contains(_norm(code));

  /// Hide [code] if visible, or restore it if hidden.
  Future<void> toggle(String code) =>
      contains(code) ? remove(code) : add(code);
}

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
