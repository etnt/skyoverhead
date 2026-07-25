import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyoverhead/src/data/sighting_store.dart';

import 'support/fake_collector.dart';

/// A minimal serializable item used to exercise the generic store mechanics
/// without depending on the concrete Sighting model (which arrives in Phase 1).
class _Item {
  final String id;
  final int value;
  const _Item(this.id, this.value);

  Map<String, dynamic> toJson() => {'id': id, 'value': value};
  static _Item fromJson(Map<String, dynamic> json) =>
      _Item(json['id'] as String, json['value'] as int);
}

SharedPrefsSightingStore<_Item> _store(SharedPreferences prefs) =>
    SharedPrefsSightingStore<_Item>(
      prefs: prefs,
      toJson: (i) => i.toJson(),
      fromJson: _Item.fromJson,
    );

void main() {
  group('SharedPrefsSightingStore', () {
    test('starts empty on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);
      expect(store.all, isEmpty);
    });

    test('appends items in insertion order and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.add(const _Item('a', 1));
      await store.add(const _Item('b', 2));

      expect(store.all.map((i) => i.id), ['a', 'b']);
      expect(notifications, 2);
    });

    test('round-trips across a simulated restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);
      await store.add(const _Item('a', 1));
      await store.add(const _Item('b', 2));

      // New store instance over the same backing prefs = app restart.
      final reloaded = _store(prefs);
      expect(reloaded.all.map((i) => i.id), ['a', 'b']);
      expect(reloaded.all.map((i) => i.value), [1, 2]);
    });

    test('clear empties the store and persists the removal', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);
      await store.add(const _Item('a', 1));

      await store.clear();
      expect(store.all, isEmpty);

      final reloaded = _store(prefs);
      expect(reloaded.all, isEmpty);
    });

    test('remove deletes one item and persists the result', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);
      final a = const _Item('a', 1);
      final b = const _Item('b', 2);
      await store.add(a);
      await store.add(b);

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.remove(a);
      expect(store.all.map((i) => i.id), ['b']);
      expect(notifications, 1);

      // Removal survives a restart.
      final reloaded = _store(prefs);
      expect(reloaded.all.map((i) => i.id), ['b']);
    });

    test('remove is a no-op for an absent item', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);
      await store.add(const _Item('a', 1));

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.remove(const _Item('z', 9));
      expect(store.all.map((i) => i.id), ['a']);
      expect(notifications, 0);
    });

    test('tolerates a corrupt stored blob by starting empty', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsSightingStore.defaultKey: 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = _store(prefs);
      expect(store.all, isEmpty);
    });
  });

  group('FakeSightingStore', () {
    test('records items and clears without persistence', () async {
      final store = FakeSightingStore<_Item>();
      await store.add(const _Item('a', 1));
      expect(store.all.single.id, 'a');
      await store.clear();
      expect(store.all, isEmpty);
    });
  });
}
