import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/config/identify_config.dart';
import 'package:skyoverhead/src/domain/saved_location.dart';
import 'package:skyoverhead/src/state/config_provider.dart';
import 'package:skyoverhead/src/state/saved_locations_provider.dart';

void main() {
  group('SavedLocationsController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts empty with no active location', () {
      expect(container.read(savedLocationsProvider), isEmpty);
      expect(container.read(activeSavedLocationProvider), isNull);
    });

    test('save persists an entry and marks it active', () async {
      final controller = container.read(savedLocationsProvider.notifier);
      final entry = await controller.save(
        'Home',
        const IdentifyConfig(latitude: 59.3, longitude: 18.1, elevationM: 30),
      );

      expect(entry.name, 'Home');
      expect(entry.latitude, 59.3);
      expect(entry.longitude, 18.1);
      expect(entry.elevationM, 30.0);
      expect(container.read(savedLocationsProvider), [entry]);
      expect(container.read(activeSavedLocationProvider), entry.id);
      expect(container.read(savedLocationStoreProvider).all, contains(entry));
    });

    test('saving under an existing name overwrites that entry', () async {
      final controller = container.read(savedLocationsProvider.notifier);
      final first = await controller.save(
        'Home',
        const IdentifyConfig(latitude: 1.0, longitude: 2.0),
      );
      final second = await controller.save(
        'home', // same name, different case
        const IdentifyConfig(latitude: 3.0, longitude: 4.0),
      );

      expect(second.id, first.id);
      expect(container.read(savedLocationsProvider), hasLength(1));
      expect(container.read(savedLocationsProvider).first.latitude, 3.0);
      expect(container.read(activeSavedLocationProvider), second.id);
    });

    test(
      'apply writes the entry into the config and marks it active',
      () async {
        const home = SavedLocation(
          id: 'a',
          name: 'Home',
          latitude: 55.0,
          longitude: 12.0,
          elevationM: 10.0,
        );
        final controller = container.read(savedLocationsProvider.notifier);
        controller.apply(home);

        final config = container.read(identifyConfigProvider);
        expect(config.latitude, 55.0);
        expect(config.longitude, 12.0);
        expect(config.elevationM, 10.0);
        expect(container.read(activeSavedLocationProvider), 'a');
      },
    );

    test('apply preserves other observer settings', () async {
      // User has customized search radius / min elevation.
      container.read(identifyConfigProvider.notifier).state =
          const IdentifyConfig(
            latitude: 10.0,
            longitude: 20.0,
            searchRadiusKm: 12.0,
            minElevationDeg: 30.0,
          );
      const home = SavedLocation(
        id: 'a',
        name: 'Home',
        latitude: 55.0,
        longitude: 12.0,
        elevationM: 10.0,
      );
      container.read(savedLocationsProvider.notifier).apply(home);

      final config = container.read(identifyConfigProvider);
      expect(config.latitude, 55.0);
      expect(config.longitude, 12.0);
      expect(config.searchRadiusKm, 12.0);
      expect(config.minElevationDeg, 30.0);
    });

    test('delete removes the entry and clears an active label', () async {
      final controller = container.read(savedLocationsProvider.notifier);
      final entry = await controller.save(
        'Home',
        const IdentifyConfig(latitude: 1.0, longitude: 2.0),
      );
      expect(container.read(activeSavedLocationProvider), entry.id);

      await controller.delete(entry.id);
      expect(container.read(savedLocationsProvider), isEmpty);
      expect(container.read(activeSavedLocationProvider), isNull);
      // The position itself is unchanged.
      final config = container.read(identifyConfigProvider);
      expect(config.latitude, 59.3293);
      expect(config.longitude, 18.0686);
    });
  });
}
