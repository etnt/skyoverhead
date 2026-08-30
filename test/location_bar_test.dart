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

  testWidgets('manual entry dialog offers saved locations and applies one', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(savedLocationsProvider.notifier);
    final home = await controller.save(
      'Home',
      const IdentifyConfig(latitude: 55.5, longitude: 12.5),
    );

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(
      find.byTooltip('Enter location (hold for saved locations)'),
    );
    await tester.pumpAndSettle();

    // The dropdown lists the saved entry; picking one fills the fields.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '55.5'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final config = container.read(identifyConfigProvider);
    expect(config.latitude, home.latitude);
    expect(config.longitude, home.longitude);
    expect(container.read(activeSavedLocationProvider), home.id);
  });

  testWidgets('long-press on the edit button opens the manager and applying '
      'a location updates the config', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(savedLocationsProvider.notifier);
    final home = await controller.save(
      'Home',
      const IdentifyConfig(latitude: 55.5, longitude: 12.5),
    );
    await controller.save(
      'Cabin',
      const IdentifyConfig(latitude: 57.5, longitude: 18.5),
    );
    // Move somewhere else first so applying Home is observable.
    container.read(identifyConfigProvider.notifier).state =
        const IdentifyConfig(latitude: 10.0, longitude: 20.0);

    await tester.pumpWidget(_appWithContainer(container));

    await tester.longPress(
      find.byTooltip('Enter location (hold for saved locations)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved locations'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cabin'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    final config = container.read(identifyConfigProvider);
    expect(config.latitude, home.latitude);
    expect(config.longitude, home.longitude);
    expect(container.read(activeSavedLocationProvider), home.id);
  });

  testWidgets('manager can delete a saved location', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(savedLocationsProvider.notifier)
        .save('Home', const IdentifyConfig(latitude: 1.0, longitude: 2.0));

    await tester.pumpWidget(_appWithContainer(container));

    await tester.longPress(
      find.byTooltip('Enter location (hold for saved locations)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
    expect(container.read(savedLocationsProvider), isEmpty);
  });

  testWidgets('manager shows an empty state with no saved locations', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.longPress(
      find.byTooltip('Enter location (hold for saved locations)'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved locations'), findsOneWidget);
    expect(find.textContaining('No saved locations yet'), findsOneWidget);
  });

  testWidgets('manual entry without a name does not create a saved location', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_appWithContainer(container));

    await tester.tap(
      find.byTooltip('Enter location (hold for saved locations)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(container.read(savedLocationsProvider), isEmpty);
  });
}
