import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/sighting.dart';

Candidate _fullCandidate() => const Candidate(
      icao24: '3c6745',
      callsign: 'DLH804',
      registration: 'D-AIZE',
      manufacturer: 'Airbus',
      model: 'A320',
      airline: 'Lufthansa',
      registeredOwnerOperator: 'Lufthansa',
      origin: Airport(
        icao: 'EDDF',
        iata: 'FRA',
        name: 'Frankfurt am Main',
        latitude: 50.03,
        longitude: 8.57,
      ),
      destination: Airport(
        icao: 'ESSA',
        iata: 'ARN',
        name: 'Stockholm Arlanda',
        latitude: 59.65,
        longitude: 17.92,
      ),
      altitudeM: 10500.0,
      altitudeSource: AltitudeSource.geometric,
      distanceKm: 12.34,
      bearingDeg: 45.6,
      elevationDeg: 62.1,
      trackDeg: 30.0,
      speedMps: 250.5,
      positionAgeS: 4,
      photoUrl: 'https://example.com/photo.jpg',
      enrichmentStatus: EnrichmentStatus.ok,
      routePlausibility: RoutePlausibility.plausible,
    );

/// A positional-only candidate: enrichment failed, so route/airline are absent.
Candidate _partialCandidate() => const Candidate(
      icao24: '400abc',
      callsign: null,
      altitudeM: 8000.0,
      altitudeSource: AltitudeSource.barometric,
      distanceKm: 20.0,
      bearingDeg: 190.0,
      elevationDeg: 25.0,
      positionAgeS: 8,
      enrichmentStatus: EnrichmentStatus.unavailable,
    );

void main() {
  final capturedAt = DateTime.utc(2026, 7, 24, 12, 30, 15);

  group('Sighting.fromCandidate', () {
    test('maps every candidate field plus confidence and timestamp', () {
      final s = Sighting.fromCandidate(
        _fullCandidate(),
        confidence: Confidence.high,
        capturedAt: capturedAt,
      );

      expect(s.capturedAt, capturedAt);
      expect(s.icao24, '3c6745');
      expect(s.callsign, 'DLH804');
      expect(s.registration, 'D-AIZE');
      expect(s.manufacturer, 'Airbus');
      expect(s.model, 'A320');
      expect(s.airline, 'Lufthansa');
      expect(s.registeredOwnerOperator, 'Lufthansa');
      expect(s.origin?.iata, 'FRA');
      expect(s.destination?.icao, 'ESSA');
      expect(s.altitudeM, 10500.0);
      expect(s.speedMps, 250.5);
      expect(s.distanceKm, 12.34);
      expect(s.bearingDeg, 45.6);
      expect(s.elevationDeg, 62.1);
      expect(s.confidence, Confidence.high);
      expect(s.photoUrl, 'https://example.com/photo.jpg');
      expect(s.enrichmentStatus, EnrichmentStatus.ok);
    });
  });

  group('Sighting JSON round-trip', () {
    test('a fully-enriched sighting survives encode/decode', () {
      final original = Sighting.fromCandidate(
        _fullCandidate(),
        confidence: Confidence.high,
        capturedAt: capturedAt,
      );

      final restored = Sighting.fromJson(original.toJson());

      expect(restored.toJson(), original.toJson());
      expect(restored.capturedAt, original.capturedAt);
      expect(restored.origin?.name, 'Frankfurt am Main');
      expect(restored.origin?.latitude, 50.03);
      expect(restored.origin?.longitude, 8.57);
      expect(restored.destination?.iata, 'ARN');
      expect(restored.destination?.latitude, 59.65);
      expect(restored.confidence, Confidence.high);
      expect(restored.enrichmentStatus, EnrichmentStatus.ok);
      expect(restored.routePlausibility, RoutePlausibility.plausible);
    });

    test('a partial (unavailable-enrichment) sighting round-trips', () {
      final original = Sighting.fromCandidate(
        _partialCandidate(),
        confidence: Confidence.medium,
        capturedAt: capturedAt,
      );

      final json = original.toJson();
      // Absent enrichment fields should simply be omitted, not null-filled.
      expect(json.containsKey('airline'), isFalse);
      expect(json.containsKey('origin'), isFalse);
      expect(json.containsKey('destination'), isFalse);
      expect(json.containsKey('speedMps'), isFalse);

      final restored = Sighting.fromJson(json);
      expect(restored.icao24, '400abc');
      expect(restored.callsign, isNull);
      expect(restored.airline, isNull);
      expect(restored.origin, isNull);
      expect(restored.destination, isNull);
      expect(restored.speedMps, isNull);
      expect(restored.confidence, Confidence.medium);
      expect(restored.enrichmentStatus, EnrichmentStatus.unavailable);
    });
  });

  group('Sighting.fromJson tolerance', () {
    test('missing fields fall back without throwing', () {
      final restored = Sighting.fromJson({'icao24': 'abc123'});
      expect(restored.icao24, 'abc123');
      expect(restored.callsign, isNull);
      expect(restored.altitudeM, 0.0);
      expect(restored.distanceKm, 0.0);
      expect(restored.speedMps, isNull);
      expect(restored.confidence, Confidence.none);
      expect(restored.enrichmentStatus, isNull);
      expect(restored.capturedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('an unknown confidence name falls back to none', () {
      final restored = Sighting.fromJson({
        'icao24': 'abc123',
        'confidence': 'not-a-real-level',
      });
      expect(restored.confidence, Confidence.none);
    });
  });
}
