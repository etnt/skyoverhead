import 'package:skyoverhead/src/data/preferences_store.dart';
import 'package:skyoverhead/src/data/sighting_store.dart';

/// An in-memory [SightingStore] for tests. Aliases the library's
/// [InMemorySightingStore] so tests and the safe provider default share one
/// implementation.
typedef FakeSightingStore<T> = InMemorySightingStore<T>;

/// An in-memory [CollectorPreferences] for tests, seeded with optional
/// initial values.
class FakeCollectorPreferences implements CollectorPreferences {
  bool enabled;
  bool paused;
  Set<String> excluded;

  FakeCollectorPreferences({
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
