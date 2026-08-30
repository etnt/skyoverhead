import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyoverhead/src/data/saved_location_store.dart';
import 'package:skyoverhead/src/domain/saved_location.dart';

void main() {
  group('SharedPrefsSavedLocationStore', () {
    test('starts empty on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSavedLocationStore(prefs: prefs);
      expect(store.all, isEmpty);
    });

    test('upserts, deletes, and persists across a simulated restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSavedLocationStore(prefs: prefs);

      const home = SavedLocation(
        id: 'loc-a',
        name: 'Home',
        latitude: 59.3293,
        longitude: 18.0686,
        elevationM: 28.0,
      );
      await store.upsert(home);
      expect(store.all, [home]);

      final reloaded = SharedPrefsSavedLocationStore(prefs: prefs);
      expect(reloaded.all, hasLength(1));
      expect(reloaded.all.first.name, 'Home');
      expect(reloaded.all.first.latitude, 59.3293);
      expect(reloaded.all.first.elevationM, 28.0);
    });

    test('upsert with the same id replaces the entry', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSavedLocationStore(prefs: prefs);

      await store.upsert(
        const SavedLocation(
          id: 'loc-a',
          name: 'Home',
          latitude: 1.0,
          longitude: 2.0,
        ),
      );
      await store.upsert(
        const SavedLocation(
          id: 'loc-a',
          name: 'Home',
          latitude: 3.0,
          longitude: 4.0,
        ),
      );

      expect(store.all, hasLength(1));
      expect(store.all.first.latitude, 3.0);

      final reloaded = SharedPrefsSavedLocationStore(prefs: prefs);
      expect(reloaded.all, hasLength(1));
      expect(reloaded.all.first.latitude, 3.0);
    });

    test('remove is a no-op for an unknown id', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSavedLocationStore(prefs: prefs);

      await store.upsert(
        const SavedLocation(
          id: 'loc-a',
          name: 'Home',
          latitude: 1.0,
          longitude: 2.0,
        ),
      );
      await store.remove('missing');
      expect(store.all, hasLength(1));

      await store.remove('loc-a');
      expect(store.all, isEmpty);

      final reloaded = SharedPrefsSavedLocationStore(prefs: prefs);
      expect(reloaded.all, isEmpty);
    });

    test('tolerates a corrupt stored blob', () async {
      SharedPreferences.setMockInitialValues({
        'observer.savedLocations': 'not json at all',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSavedLocationStore(prefs: prefs);

      expect(store.all, isEmpty);
      // And it can recover by saving over the corrupt blob.
      await store.upsert(
        const SavedLocation(
          id: 'loc-a',
          name: 'Home',
          latitude: 1.0,
          longitude: 2.0,
        ),
      );
      expect(store.all, hasLength(1));
    });

    test('round-trips through toJson/fromJson', () {
      const location = SavedLocation(
        id: 'loc-1',
        name: 'Summer house',
        latitude: 57.7,
        longitude: 18.6,
        elevationM: 5.0,
      );
      final restored = SavedLocation.fromJson(
        jsonDecode(jsonEncode(location.toJson())) as Map<String, dynamic>,
      );
      expect(restored.id, 'loc-1');
      expect(restored.name, 'Summer house');
      expect(restored.latitude, 57.7);
      expect(restored.longitude, 18.6);
      expect(restored.elevationM, 5.0);
    });
  });

  group('InMemorySavedLocationStore', () {
    test('upserts and removes without persistence', () async {
      final store = InMemorySavedLocationStore();
      await store.upsert(
        const SavedLocation(
          id: 'a',
          name: 'Home',
          latitude: 1.0,
          longitude: 2.0,
        ),
      );
      expect(store.all, hasLength(1));
      await store.remove('a');
      expect(store.all, isEmpty);
    });
  });
}
