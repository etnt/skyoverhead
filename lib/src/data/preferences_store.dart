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

  /// Persist [value] as the new [collectorEnabled] state.
  Future<void> setCollectorEnabled(bool value);

  /// Persist [value] as the new [collectorPaused] state.
  Future<void> setCollectorPaused(bool value);
}

/// A [CollectorPreferences] backed by [SharedPreferences].
class SharedPrefsCollectorPreferences implements CollectorPreferences {
  static const String enabledKey = 'collector.enabled';
  static const String pausedKey = 'collector.paused';

  final SharedPreferences _prefs;

  SharedPrefsCollectorPreferences(this._prefs);

  @override
  bool get collectorEnabled => _prefs.getBool(enabledKey) ?? false;

  @override
  bool get collectorPaused => _prefs.getBool(pausedKey) ?? false;

  @override
  Future<void> setCollectorEnabled(bool value) =>
      _prefs.setBool(enabledKey, value);

  @override
  Future<void> setCollectorPaused(bool value) =>
      _prefs.setBool(pausedKey, value);
}
