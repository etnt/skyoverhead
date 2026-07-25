/// Persisted collector opt-in preferences (Phase 0).
///
/// Two independent, persisted flags model the privacy-first collector gate
/// described in `docs/gamification-implementation-plan.md`:
///
/// * [collectorEnabled] — the master switch. Default `false`, so a fresh
///   install collects nothing and behaves as identify-only. Turning it off is
///   what erases stored data (handled by the UI in Phase 3).
/// * [collectorPaused] — a softer stop that suppresses new logging while
///   keeping already-collected data. Only meaningful while enabled.
///
/// The interface is deliberately storage-agnostic so tests can supply an
/// in-memory fake instead of `shared_preferences`.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Read/write access to the persisted collector flags.
abstract interface class CollectorPreferences {
  /// Whether collecting (persisting sightings) is switched on. Default `false`.
  bool get collectorEnabled;

  /// Whether logging is paused while collecting remains enabled. Default
  /// `false`.
  bool get collectorPaused;

  /// Airport codes (IATA/ICAO, upper-cased) hidden from the Stats top lists.
  /// Excluded airports are still logged and still appear in the Logbook and
  /// Collections — this filter only affects statistics presentation. Default
  /// empty.
  Set<String> get excludedAirports;

  /// Persist [value] as the new [collectorEnabled] state.
  Future<void> setCollectorEnabled(bool value);

  /// Persist [value] as the new [collectorPaused] state.
  Future<void> setCollectorPaused(bool value);

  /// Persist [value] as the new [excludedAirports] set.
  Future<void> setExcludedAirports(Set<String> value);
}

/// A [CollectorPreferences] backed by [SharedPreferences].
class SharedPrefsCollectorPreferences implements CollectorPreferences {
  static const String enabledKey = 'collector.enabled';
  static const String pausedKey = 'collector.paused';
  static const String excludedAirportsKey = 'collector.excludedAirports';

  final SharedPreferences _prefs;

  SharedPrefsCollectorPreferences(this._prefs);

  @override
  bool get collectorEnabled => _prefs.getBool(enabledKey) ?? false;

  @override
  bool get collectorPaused => _prefs.getBool(pausedKey) ?? false;

  @override
  Set<String> get excludedAirports =>
      (_prefs.getStringList(excludedAirportsKey) ?? const []).toSet();

  @override
  Future<void> setCollectorEnabled(bool value) =>
      _prefs.setBool(enabledKey, value);

  @override
  Future<void> setCollectorPaused(bool value) =>
      _prefs.setBool(pausedKey, value);

  @override
  Future<void> setExcludedAirports(Set<String> value) =>
      _prefs.setStringList(excludedAirportsKey, value.toList());
}

/// A non-persistent [CollectorPreferences] used as a safe default when no
/// persisted implementation has been wired in (e.g. in tests, or before
/// `main()` runs its override). Collecting is off, so nothing is gathered.
class InMemoryCollectorPreferences implements CollectorPreferences {
  bool enabled;
  bool paused;
  Set<String> excluded;

  InMemoryCollectorPreferences({
    this.enabled = false,
    this.paused = false,
    Set<String>? excluded,
  }) : excluded = excluded ?? <String>{};

  @override
  bool get collectorEnabled => enabled;

  @override
  bool get collectorPaused => paused;

  @override
  Set<String> get excludedAirports => excluded;

  @override
  Future<void> setCollectorEnabled(bool value) async => enabled = value;

  @override
  Future<void> setCollectorPaused(bool value) async => paused = value;

  @override
  Future<void> setExcludedAirports(Set<String> value) async => excluded = value;
}
