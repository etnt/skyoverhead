import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/config/identify_config.dart';
import 'package:skyoverhead/src/state/config_provider.dart';
import 'package:skyoverhead/src/state/saved_locations_provider.dart';
import 'package:skyoverhead/src/ui/location_bar.dart';

Widget _app({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: Scaffold(body: LocationBar())),
  );
}

/// A [LocationBar] driven by a shared [container] so tests can inspect and
/// mutate provider state directly.
Widget _appWithContainer(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: LocationBar())),
  );
}

void main() {
  testWidgets('long-press on the GPS button saves the current position', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_appWithContainer(container));

    await tester.longPress(find.byTooltip('Use my location (hold to save)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Home');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Location "Home" saved.'), findsOneWidget);
    expect(container.read(savedLocationsProvider), hasLength(1));
    expect(find.text('Observing from Home (59.3293, 18.0686)'), findsOneWidget);
  });

  testWidgets('chip falls back to bare coordinates for an unnamed position', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Observing from 59.3293, 18.0686'), findsOneWidget);
  });

  testWidgets('location dialog lists saved locations and loads one on tap', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(savedLocationsProvider.notifier);
    final home = await controller.save(
      'Home',
      const IdentifyConfig(latitude: 55.5, longitude: 12.5),
    );
    // Move somewhere else first so loading Home is observable.
    container.read(identifyConfigProvider.notifier).state =
        const IdentifyConfig(latitude: 10.0, longitude: 20.0);

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(find.byTooltip('Pick or enter a location'));
    await tester.pumpAndSettle();

    // Tapping the saved entry loads it and closes the dialog.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    final config = container.read(identifyConfigProvider);
    expect(config.latitude, home.latitude);
    expect(config.longitude, home.longitude);
    expect(container.read(activeSavedLocationProvider), home.id);
  });

  testWidgets('location dialog shows both parts with saved entries', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(savedLocationsProvider.notifier);
    await controller.save(
      'Home',
      const IdentifyConfig(latitude: 55.5, longitude: 12.5),
    );
    await controller.save(
      'Cabin',
      const IdentifyConfig(latitude: 57.5, longitude: 18.5),
    );

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(find.byTooltip('Pick or enter a location'));
    await tester.pumpAndSettle();

    // Part one: the saved locations. Part two: the manual-entry form.
    expect(find.text('Saved locations'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cabin'), findsOneWidget);
    expect(find.text('Enter a new location'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Latitude'), findsOneWidget);
  });

  testWidgets('location dialog can delete a saved location', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(savedLocationsProvider.notifier)
        .save('Home', const IdentifyConfig(latitude: 1.0, longitude: 2.0));

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(find.byTooltip('Pick or enter a location'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
    expect(container.read(savedLocationsProvider), isEmpty);
  });

  testWidgets('location dialog shows an empty state with no saved locations', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byTooltip('Pick or enter a location'));
    await tester.pumpAndSettle();

    expect(find.text('Saved locations'), findsOneWidget);
    expect(find.textContaining('None yet'), findsOneWidget);
  });

  testWidgets('entering a location without a name does not save it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(find.byTooltip('Pick or enter a location'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Set location'));
    await tester.pumpAndSettle();

    expect(container.read(savedLocationsProvider), isEmpty);
  });

  testWidgets('entering a location with a name saves it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(find.byTooltip('Pick or enter a location'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '40.0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '-3.0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name (optional)'),
      'Madrid',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Set location'));
    await tester.pumpAndSettle();

    final saved = container.read(savedLocationsProvider);
    expect(saved, hasLength(1));
    expect(saved.first.name, 'Madrid');
    expect(saved.first.latitude, 40.0);
    final config = container.read(identifyConfigProvider);
    expect(config.latitude, 40.0);
    expect(config.longitude, -3.0);
  });
}
