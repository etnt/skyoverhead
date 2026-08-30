/// State for the user's saved observer locations.
///
/// [savedLocationsProvider] mirrors the persisted [SavedLocationStore] into a
/// [List<SavedLocation>] the UI can watch. [activeSavedLocationProvider] tracks
/// which saved entry (if any) currently backs [identifyConfigProvider], so the
/// location chip can label the position by name.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/identify_config.dart';
import '../data/saved_location_store.dart';
import '../domain/saved_location.dart';
import 'config_provider.dart';

/// The concrete saved-location store; override in tests and `main()`.
final savedLocationStoreProvider = Provider<SavedLocationStore>(
  (ref) => InMemorySavedLocationStore(),
);

class SavedLocationsController extends StateNotifier<List<SavedLocation>> {
  final Ref _ref;
  final SavedLocationStore _store;

  SavedLocationsController(this._ref, this._store) : super(List.of(_store.all));

  /// Save [config] under [name]. Saving under an existing name (case-
  /// insensitive) overwrites that entry's coordinates. Marks the entry active.
  Future<SavedLocation> save(String name, IdentifyConfig config) async {
    final trimmed = name.trim();
    final existingId = _activeIdForName(trimmed);
    final entry = SavedLocation(
      id: existingId ?? _newId(),
      name: trimmed,
      latitude: config.latitude,
      longitude: config.longitude,
      elevationM: config.elevationM,
    );
    await _store.upsert(entry);
    state = List.of(_store.all);
    _syncActive(entry);
    return entry;
  }

  /// Apply [location] as the current observing position, preserving the
  /// other observer settings (search radius, min elevation, ...).
  void apply(SavedLocation location) {
    _ref.read(identifyConfigProvider.notifier).state = _ref
        .read(identifyConfigProvider)
        .copyWith(
          latitude: location.latitude,
          longitude: location.longitude,
          elevationM: location.elevationM,
        );
    _syncActive(location);
  }

  /// Delete the entry with [id]. If it was the active one, the chip falls
  /// back to showing bare coordinates (the position itself is unchanged).
  Future<void> delete(String id) async {
    await _store.remove(id);
    state = List.of(_store.all);
    if (_ref.read(activeSavedLocationProvider) == id) {
      _ref.read(activeSavedLocationProvider.notifier).state = null;
    }
  }

  /// Mark [entry] as active without changing the config (used when the config
  /// was just written to match the entry).
  void _syncActive(SavedLocation entry) {
    _ref.read(activeSavedLocationProvider.notifier).state = entry.id;
  }

  /// Set the active label to the saved entry matching [config] exactly, or
  /// clear it when the config corresponds to no saved location. Called after
  /// the config was written from some other source (GPS fix or manual entry).
  void syncActiveForConfig(IdentifyConfig config) {
    for (final entry in _store.all) {
      if (entry.latitude == config.latitude &&
          entry.longitude == config.longitude &&
          entry.elevationM == config.elevationM) {
        _syncActive(entry);
        return;
      }
    }
    _ref.read(activeSavedLocationProvider.notifier).state = null;
  }

  String? _activeIdForName(String name) {
    for (final entry in _store.all) {
      if (entry.name.toLowerCase() == name.toLowerCase()) return entry.id;
    }
    return null;
  }

  String _newId() =>
      'loc-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}

/// The id of the saved location currently backing the config, or `null`.
final activeSavedLocationProvider = StateProvider<String?>((ref) => null);

final savedLocationsProvider =
    StateNotifierProvider<SavedLocationsController, List<SavedLocation>>((ref) {
      return SavedLocationsController(
        ref,
        ref.watch(savedLocationStoreProvider),
      );
    });
