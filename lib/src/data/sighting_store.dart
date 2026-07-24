/// Persistence abstraction for collected sightings (Phase 0).
///
/// The store owns the raw, append-only list of items and notifies listeners
/// whenever it changes (it is a [ChangeNotifier]). It is generic over the item
/// type [T] so the storage mechanics are built and tested independently of the
/// concrete `Sighting` model, which lands in Phase 1 as `SightingStore<Sighting>`.
///
/// Aggregations (collections, medals, records, stats) are computed on read from
/// [all]; the store itself only handles persistence.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A persisted, append-only collection of [T] items.
abstract class SightingStore<T> extends ChangeNotifier {
  /// All stored items, in insertion order (oldest first).
  List<T> get all;

  /// Append [item] and persist the updated list.
  Future<void> add(T item);

  /// Remove all items and persist the empty list.
  Future<void> clear();
}

/// A [SightingStore] backed by a single JSON blob in [SharedPreferences].
///
/// Serialization is injected via [toJson]/[fromJson] so this class stays
/// decoupled from the concrete item model. The list is JSON-encoded under a
/// single [storageKey]; it is loaded once on construction and rewritten on
/// every [add]/[clear].
class SharedPrefsSightingStore<T> extends SightingStore<T> {
  static const String defaultKey = 'collector.sightings';

  final SharedPreferences prefs;
  final String storageKey;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  final List<T> _items = [];

  SharedPrefsSightingStore({
    required this.prefs,
    required this.toJson,
    required this.fromJson,
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
            _items.add(fromJson(entry));
          }
        }
      }
    } on FormatException {
      // Corrupt/unreadable blob: start from an empty list rather than crash.
      _items.clear();
    }
  }

  Future<void> _persist() {
    final encoded = jsonEncode(_items.map(toJson).toList());
    return prefs.setString(storageKey, encoded);
  }

  @override
  List<T> get all => List.unmodifiable(_items);

  @override
  Future<void> add(T item) async {
    _items.add(item);
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items.clear();
    await prefs.remove(storageKey);
    notifyListeners();
  }
}
