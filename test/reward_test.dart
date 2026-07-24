import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/data/sighting_store.dart';
import 'package:skyoverhead/src/domain/collections.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/reward.dart';
import 'package:skyoverhead/src/domain/sighting.dart';
import 'package:skyoverhead/src/state/sighting_logger.dart';

import 'support/fake_collector.dart';

Sighting _s({
  String icao24 = 'abc123',
  String? airline,
  String? model,
  Airport? destination,
}) {
  return Sighting(
    capturedAt: DateTime.utc(2026, 1, 1),
    icao24: icao24,
    airline: airline,
    model: model,
    destination: destination,
    altitudeM: 10000,
    distanceKm: 10,
    bearingDeg: 0,
    elevationDeg: 30,
    confidence: Confidence.high,
  );
}

Candidate _candidate({
  String icao24 = 'abc123',
  Airport? destination,
}) {
  return Candidate(
    icao24: icao24,
    callsign: 'DLH1',
    model: 'A320',
    airline: 'Lufthansa',
    destination: destination,
    altitudeM: 10000,
    altitudeSource: AltitudeSource.geometric,
    distanceKm: 10,
    bearingDeg: 0,
    elevationDeg: 30,
    positionAgeS: 1,
    enrichmentStatus: EnrichmentStatus.ok,
  );
}

void main() {
  group('detectRewards (pure)', () {
    test('first destination yields both a medal and a collection reward', () {
      final events = detectRewards(
        before: const [],
        after: [_s(destination: const Airport(iata: 'ARN'))],
      );

      // Medals come first, then collections.
      expect(events.first.kind, RewardKind.medal);
      expect(events.first.message, 'New medal: Cadet');
      expect(
        events.any((e) =>
            e.kind == RewardKind.collection &&
            e.message == 'New destination! ARN (1 total)'),
        isTrue,
      );
    });

    test('no rewards when nothing new is added', () {
      final existing = [_s(destination: const Airport(iata: 'ARN'))];
      final events = detectRewards(before: existing, after: existing);
      expect(events, isEmpty);
    });

    test('a repeat destination produces no collection reward', () {
      final before = [_s(icao24: 'a', destination: const Airport(iata: 'ARN'))];
      final after = [
        ...before,
        _s(icao24: 'b', destination: const Airport(iata: 'ARN')),
      ];
      final events = detectRewards(before: before, after: after);
      expect(
        events.where((e) => e.kind == RewardKind.collection),
        isEmpty,
      );
    });

    test('collection total reflects the new count', () {
      final before = [_s(icao24: 'a', destination: const Airport(iata: 'ARN'))];
      final after = [
        ...before,
        _s(icao24: 'b', destination: const Airport(iata: 'FRA')),
      ];
      final events = detectRewards(before: before, after: after);
      expect(
        events.any((e) => e.message == 'New destination! FRA (2 total)'),
        isTrue,
      );
    });

    test('registrations and origins are excluded by default', () {
      final before = const <Sighting>[];
      final after = [
        _s(destination: const Airport(iata: 'ARN')),
      ];
      // Default curated kinds -> no "New origin!"/"New registration!" here.
      expect(
        detectRewards(before: before, after: after)
            .every((e) => !e.message.contains('origin')),
        isTrue,
      );

      // But opting into all kinds does surface them.
      final all = detectRewards(
        before: before,
        after: [
          _s(destination: const Airport(iata: 'ARN', icao: 'ESSA')),
        ],
        kinds: CollectionKind.values,
      );
      expect(all.any((e) => e.message.startsWith('New country!')), isTrue);
    });
  });

  group('SightingLogger reward wiring', () {
    test('emits reward events through onReward on a fresh log', () async {
      final captured = <RewardEvent>[];
      final logger = SightingLogger(
        store: InMemorySightingStore<Sighting>(),
        isEnabled: () => true,
        isPaused: () => false,
        onReward: captured.addAll,
      );

      await logger.logResult(
        IdentifyResult.ok(
          confidence: Confidence.high,
          candidate: _candidate(destination: const Airport(iata: 'ARN')),
          alternatives: const [],
          observedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(captured, isNotEmpty);
      expect(captured.first.message, 'New medal: Cadet');
    });

    test('does not emit when collecting is disabled', () async {
      final captured = <RewardEvent>[];
      final logger = SightingLogger(
        store: FakeSightingStore<Sighting>(),
        isEnabled: () => false,
        isPaused: () => false,
        onReward: captured.addAll,
      );

      await logger.logResult(
        IdentifyResult.ok(
          confidence: Confidence.high,
          candidate: _candidate(),
          alternatives: const [],
          observedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(captured, isEmpty);
    });
  });
}
