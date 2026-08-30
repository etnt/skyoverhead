/// Persistence abstraction for saved observer locations.
///
/// A saved location is a named lat/lon (plus elevation) the user can switch
/// back to, e.g. "Home". The store owns the list of entries and persists it;
/// ordering is insertion order. The interface is deliberately storage-agnostic
/// so tests can supply an in-memory fake instead of `shared_preferences`.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_location.dart';

/// Read/write access to the persisted list of saved locations.
abstract interface class SavedLocationStore {
  /// All saved locations, in insertion order (oldest first).
  List<SavedLocation> get all;

  /// Insert [location], or replace the existing entry with the same [id].
  Future<void> upsert(SavedLocation location);

  /// Remove the entry with [id]. No-op when absent.
  Future<void> remove(String id);
}

/// A [SavedLocationStore] backed by a single JSON blob in [SharedPreferences].
///
/// Mirrors the [SharedPrefsSightingStore] pattern: JSON-encoded under a single
/// [storageKey], loaded once on construction and rewritten on every change.
/// A corrupt/unreadable blob starts from an empty list rather than crashing.
class SharedPrefsSavedLocationStore implements SavedLocationStore {
  static const String defaultKey = 'observer.savedLocations';

  final SharedPreferences prefs;
  final String storageKey;

  final List<SavedLocation> _items = [];

  SharedPrefsSavedLocationStore({
    required this.prefs,
    this.storageKey = defaultKey,
  }) {
    _load();
  }

  void _load() {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            _items.add(SavedLocation.fromJson(entry));
          }
        }
      }
    } on FormatException {
      // Corrupt/unreadable blob: start from an empty list rather than crash.
      _items.clear();
    }
  }

  Future<void> _persist() {
    final encoded = jsonEncode(
      _items.map((location) => location.toJson()).toList(),
    );
    return prefs.setString(storageKey, encoded);
  }

  @override
  List<SavedLocation> get all => List.unmodifiable(_items);

  @override
  Future<void> upsert(SavedLocation location) async {
    final index = _items.indexWhere((entry) => entry.id == location.id);
    if (index >= 0) {
      _items[index] = location;
    } else {
      _items.add(location);
    }
    await _persist();
  }

  @override
  Future<void> remove(String id) async {
    final lengthBefore = _items.length;
    _items.removeWhere((entry) => entry.id == id);
    if (_items.length == lengthBefore) return;
    await _persist();
  }
}

/// A non-persistent [SavedLocationStore] used as a safe default when no
/// persisted store has been wired in (e.g. in tests, or before `main()` runs
/// its override). Entries live only in memory.
class InMemorySavedLocationStore implements SavedLocationStore {
  final List<SavedLocation> _items = [];

  @override
  List<SavedLocation> get all => List.unmodifiable(_items);

  @override
  Future<void> upsert(SavedLocation location) async {
    final index = _items.indexWhere((entry) => entry.id == location.id);
    if (index >= 0) {
      _items[index] = location;
    } else {
      _items.add(location);
    }
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((entry) => entry.id == id);
  }
}
