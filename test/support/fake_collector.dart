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

  FakeCollectorPreferences({this.enabled = false, this.paused = false});

  @override
  bool get collectorEnabled => enabled;

  @override
  bool get collectorPaused => paused;

  @override
  Future<void> setCollectorEnabled(bool value) async => enabled = value;

  @override
  Future<void> setCollectorPaused(bool value) async => paused = value;
}
