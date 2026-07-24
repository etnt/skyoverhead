import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyoverhead/src/data/preferences_store.dart';
import 'package:skyoverhead/src/state/collector_provider.dart';

import 'support/fake_collector.dart';

void main() {
  group('SharedPrefsCollectorPreferences', () {
    test('defaults both flags to false on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsCollectorPreferences(prefs);
      expect(store.collectorEnabled, isFalse);
      expect(store.collectorPaused, isFalse);
    });

    test('persists flags across a simulated restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsCollectorPreferences(prefs);

      await store.setCollectorEnabled(true);
      await store.setCollectorPaused(true);

      final reloaded = SharedPrefsCollectorPreferences(prefs);
      expect(reloaded.collectorEnabled, isTrue);
      expect(reloaded.collectorPaused, isTrue);
    });
  });

  group('collector providers', () {
    ProviderContainer containerWith(CollectorPreferences prefs) {
      final container = ProviderContainer(
        overrides: [collectorPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('seed initial state from the persisted preferences', () {
      final container = containerWith(
        FakeCollectorPreferences(enabled: true, paused: false),
      );
      expect(container.read(collectorEnabledProvider), isTrue);
      expect(container.read(collectorPausedProvider), isFalse);
    });

    test('set() updates state and writes through to preferences', () async {
      final prefs = FakeCollectorPreferences();
      final container = containerWith(prefs);

      await container.read(collectorEnabledProvider.notifier).set(true);
      expect(container.read(collectorEnabledProvider), isTrue);
      expect(prefs.collectorEnabled, isTrue);
    });

    test('toggle() flips and persists the flag', () async {
      final prefs = FakeCollectorPreferences(paused: false);
      final container = containerWith(prefs);

      await container.read(collectorPausedProvider.notifier).toggle();
      expect(container.read(collectorPausedProvider), isTrue);
      expect(prefs.collectorPaused, isTrue);
    });

    test('reading preferences without an override throws', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(collectorPreferencesProvider),
        throwsUnimplementedError,
      );
    });
  });
}
