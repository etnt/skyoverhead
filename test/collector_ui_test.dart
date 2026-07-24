import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/config/identify_config.dart';
import 'package:skyoverhead/src/data/aircraft_service.dart';
import 'package:skyoverhead/src/data/sighting_store.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/sighting.dart';
import 'package:skyoverhead/src/state/collector_provider.dart';
import 'package:skyoverhead/src/state/identify_controller.dart';
import 'package:skyoverhead/src/state/sighting_logger.dart';
import 'package:skyoverhead/src/ui/app_shell.dart';
import 'package:skyoverhead/src/ui/logbook_screen.dart';

import 'support/fake_collector.dart';

class _FakeService implements AircraftService {
  @override
  Future<IdentifyResult> identify(IdentifyConfig config) async =>
      IdentifyResult.none(observedAt: DateTime.utc(2026, 7, 18));
}

Candidate _candidate({
  String icao24 = '3c6745',
  String callsign = 'DLH804',
  Airport? origin,
  Airport? destination,
}) {
  return Candidate(
    icao24: icao24,
    callsign: callsign,
    registration: 'D-AIZE',
    manufacturer: 'Airbus',
    model: 'A320',
    airline: 'Lufthansa',
    origin: origin,
    destination: destination,
    altitudeM: 10000,
    altitudeSource: AltitudeSource.geometric,
    distanceKm: 5,
    bearingDeg: 45,
    elevationDeg: 80,
    speedMps: 230,
    positionAgeS: 2,
    enrichmentStatus: EnrichmentStatus.ok,
  );
}

Sighting _sighting({
  String icao24 = '3c6745',
  String callsign = 'DLH804',
  Airport? origin,
  Airport? destination,
  DateTime? capturedAt,
}) {
  return Sighting.fromCandidate(
    _candidate(
      icao24: icao24,
      callsign: callsign,
      origin: origin,
      destination: destination,
    ),
    confidence: Confidence.high,
    capturedAt: capturedAt ?? DateTime(2026, 7, 24, 14, 30),
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required bool enabled,
  bool paused = false,
  List<Sighting> seed = const [],
}) async {
  final store = InMemorySightingStore<Sighting>();
  for (final s in seed) {
    await store.add(s);
  }
  final container = ProviderContainer(
    overrides: [
      aircraftServiceProvider.overrideWithValue(_FakeService()),
      collectorPreferencesProvider.overrideWithValue(
        FakeCollectorPreferences(enabled: enabled, paused: paused),
      ),
      sightingStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ),
  );
  return container;
}

void main() {
  group('AppShell tab gating', () {
    testWidgets('hides collector tabs when Collector mode is off',
        (tester) async {
      await _pumpApp(tester, enabled: false);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text("What's overhead?"), findsOneWidget);
    });

    testWidgets('shows Sky and Logbook tabs when Collector mode is on',
        (tester) async {
      await _pumpApp(tester, enabled: true);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Sky'), findsOneWidget);
      expect(find.text('Logbook'), findsOneWidget);
    });

    testWidgets('keeps tabs visible while paused', (tester) async {
      await _pumpApp(tester, enabled: true, paused: true);

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('tapping the Logbook tab shows the logbook', (tester) async {
      await _pumpApp(
        tester,
        enabled: true,
        seed: [_sighting()],
      );

      await tester.tap(find.text('Logbook'));
      await tester.pumpAndSettle();

      // Nav label + the LogbookScreen app bar title.
      expect(find.text('Logbook'), findsNWidgets(2));
      expect(find.text('DLH804'), findsOneWidget);
    });
  });

  group('Logbook contents', () {
    testWidgets('renders one row per sighting, newest first', (tester) async {
      await _pumpApp(
        tester,
        enabled: true,
        seed: [
          _sighting(callsign: 'OLDEST', capturedAt: DateTime(2026, 7, 1)),
          _sighting(callsign: 'NEWEST', capturedAt: DateTime(2026, 7, 20)),
        ],
      );

      await tester.tap(find.text('Logbook'));
      await tester.pumpAndSettle();

      expect(find.text('OLDEST'), findsOneWidget);
      expect(find.text('NEWEST'), findsOneWidget);

      // Newest should sit above oldest in the list.
      final newestY = tester.getTopLeft(find.text('NEWEST')).dy;
      final oldestY = tester.getTopLeft(find.text('OLDEST')).dy;
      expect(newestY, lessThan(oldestY));
    });

    testWidgets('shows the empty state when nothing collected',
        (tester) async {
      await _pumpApp(tester, enabled: true);

      await tester.tap(find.text('Logbook'));
      await tester.pumpAndSettle();

      expect(find.text('No sightings yet'), findsOneWidget);
    });

    testWidgets('tapping a row opens the sighting detail', (tester) async {
      await _pumpApp(
        tester,
        enabled: true,
        seed: [
          _sighting(
            destination: const Airport(icao: 'ESSA', iata: 'ARN'),
          ),
        ],
      );

      await tester.tap(find.text('Logbook'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Seen '), findsOneWidget);
      expect(find.text('Lufthansa'), findsOneWidget);
    });
  });

  group('Disabling Collector mode', () {
    testWidgets('confirms, then wipes stored sightings and hides tabs',
        (tester) async {
      final container = await _pumpApp(
        tester,
        enabled: true,
        seed: [_sighting()],
      );
      expect(container.read(sightingsProvider), hasLength(1));

      // Open settings from the Sky tab.
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Toggle Collector mode off.
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Collector mode'),
      );
      await tester.pumpAndSettle();

      // Confirmation dialog appears; confirm the destructive wipe.
      expect(find.text('Turn off Collector mode?'), findsOneWidget);
      await tester.tap(find.text('Turn off & delete'));
      await tester.pumpAndSettle();

      expect(container.read(collectorEnabledProvider), isFalse);
      expect(container.read(sightingsProvider), isEmpty);

      // Close the settings dialog; the collector tabs should be gone.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('cancelling the confirmation keeps data and mode on',
        (tester) async {
      final container = await _pumpApp(
        tester,
        enabled: true,
        seed: [_sighting()],
      );

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Collector mode'),
      );
      await tester.pumpAndSettle();

      // The confirmation dialog is on top; its Cancel is the last in the tree.
      expect(find.text('Turn off Collector mode?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      expect(container.read(collectorEnabledProvider), isTrue);
      expect(container.read(sightingsProvider), hasLength(1));
    });
  });

  group('LogbookScreen in isolation', () {
    testWidgets('empty store shows the point-at-the-sky hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sightingStoreProvider
                .overrideWithValue(InMemorySightingStore<Sighting>()),
          ],
          child: const MaterialApp(home: LogbookScreen()),
        ),
      );

      expect(
        find.textContaining('Point at the sky'),
        findsOneWidget,
      );
    });
  });
}
