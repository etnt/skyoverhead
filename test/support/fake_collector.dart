import 'package:skyoverhead/src/data/preferences_store.dart';
import 'package:skyoverhead/src/data/sighting_store.dart';

/// An in-memory [SightingStore] for tests: no persistence, just records
/// items and notifies listeners on change.
class FakeSightingStore<T> extends SightingStore<T> {
  final List<T> _items = [];

  @override
  List<T> get all => List.unmodifiable(_items);

  @override
  Future<void> add(T item) async {
    _items.add(item);
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}

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
