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

class _MatchService implements AircraftService {
  final Candidate candidate;
  _MatchService(this.candidate);

  @override
  Future<IdentifyResult> identify(IdentifyConfig config) async =>
      IdentifyResult.ok(
        confidence: Confidence.high,
        candidate: candidate,
        alternatives: const [],
        observedAt: DateTime.utc(2026, 7, 18),
      );
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
  AircraftService? service,
}) async {
  final store = InMemorySightingStore<Sighting>();
  for (final s in seed) {
    await store.add(s);
  }
  final container = ProviderContainer(
    overrides: [
      aircraftServiceProvider.overrideWithValue(service ?? _FakeService()),
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

  group('Medals tab', () {
    testWidgets('appears when Collector mode is on', (tester) async {
      await _pumpApp(tester, enabled: true);
      expect(find.text('Medals'), findsOneWidget);
    });

    testWidgets('reflects seeded sightings in tiers and collections',
        (tester) async {
      await _pumpApp(
        tester,
        enabled: true,
        seed: [
          _sighting(
            icao24: 'aa0001',
            destination: const Airport(icao: 'ESSA', iata: 'ARN'),
          ),
        ],
      );

      await tester.tap(find.text('Medals'));
      await tester.pumpAndSettle();

      // Ace ladder first tier is earned with a single destination.
      expect(find.text('Cadet'), findsOneWidget);
      expect(find.text('Earned'), findsWidgets);
      // Collections summary chip is present.
      expect(find.text('Destinations'), findsOneWidget);
      // A locked tier shows numeric progress toward its target.
      expect(find.textContaining('/ 5'), findsWidgets);
    });
  });

  group('Stats tab', () {
    testWidgets('appears when Collector mode is on', (tester) async {
      await _pumpApp(tester, enabled: true);
      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('shows records and totals for seeded sightings',
        (tester) async {
      await _pumpApp(
        tester,
        enabled: true,
        seed: [
          _sighting(destination: const Airport(icao: 'ESSA', iata: 'ARN')),
        ],
      );

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Highest altitude'), findsOneWidget);
      expect(find.text('Closest'), findsOneWidget);
    });

    testWidgets('shows the empty state with no sightings', (tester) async {
      await _pumpApp(tester, enabled: true);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('No stats yet'), findsOneWidget);
    });
  });

  group('Reward feedback', () {
    testWidgets('logging a new sighting surfaces reward snackbars',
        (tester) async {
      await _pumpApp(
        tester,
        enabled: true,
        service: _MatchService(
          _candidate(destination: const Airport(icao: 'ESSA', iata: 'ARN')),
        ),
      );

      await tester.tap(find.text("What's overhead?"));
      await tester.pump(); // start the async identify
      await tester.pump(const Duration(milliseconds: 300)); // settle + emit

      // Snackbars are presented one at a time; the medal (highest priority)
      // shows first. The full event set is covered by reward_test.dart.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('New medal: Cadet'), findsOneWidget);
    });

    testWidgets('no reward snackbar when Collector mode is off',
        (tester) async {
      await _pumpApp(
        tester,
        enabled: false,
        service: _MatchService(
          _candidate(destination: const Airport(icao: 'ESSA', iata: 'ARN')),
        ),
      );

      await tester.tap(find.text("What's overhead?"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Logbook pagination', () {
    testWidgets('caps rows at a page and reveals more on demand',
        (tester) async {
      final store = InMemorySightingStore<Sighting>();
      for (var i = 0; i < 60; i++) {
        await store.add(_sighting(icao24: 'ac$i'));
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sightingStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(home: LogbookScreen()),
        ),
      );

      // The footer sits below the first page of rows; scroll to reach it.
      await tester.scrollUntilVisible(
        find.textContaining('Show more'),
        400,
      );
      expect(find.textContaining('Show more'), findsOneWidget);

      await tester.tap(find.textContaining('Show more'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Show more'), findsNothing);
    });
  });
}
