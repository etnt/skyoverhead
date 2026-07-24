import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/collections.dart';
import 'package:skyoverhead/src/domain/countries.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/sighting.dart';

/// Build a sighting with only the fields the collection extractors care about.
Sighting _s({
  String icao24 = 'abc123',
  String? registration,
  String? manufacturer,
  String? model,
  String? airline,
  String? registeredOwnerOperator,
  Airport? origin,
  Airport? destination,
}) {
  return Sighting(
    capturedAt: DateTime.utc(2026, 1, 1),
    icao24: icao24,
    registration: registration,
    manufacturer: manufacturer,
    model: model,
    airline: airline,
    registeredOwnerOperator: registeredOwnerOperator,
    origin: origin,
    destination: destination,
    altitudeM: 10000,
    distanceKm: 10,
    bearingDeg: 0,
    elevationDeg: 30,
    confidence: Confidence.high,
  );
}

void main() {
  group('airport-code collections', () {
    test('destinations prefer IATA then ICAO, upper-cased and de-duped', () {
      final sightings = [
        _s(destination: const Airport(icao: 'ESSA', iata: 'arn')),
        _s(destination: const Airport(icao: 'ESSA', iata: 'ARN')),
        _s(destination: const Airport(icao: 'eddf')), // no IATA -> ICAO
        _s(destination: null), // skipped
      ];

      expect(uniqueDestinations(sightings), {'ARN', 'EDDF'});
    });

    test('origins use the same rules independently of destinations', () {
      final sightings = [
        _s(origin: const Airport(iata: 'FRA')),
        _s(origin: const Airport(icao: 'EGLL', iata: 'LHR')),
      ];

      expect(uniqueOrigins(sightings), {'FRA', 'LHR'});
    });

    test('blank codes contribute nothing', () {
      final sightings = [
        _s(destination: const Airport(icao: '   ', iata: '')),
      ];
      expect(uniqueDestinations(sightings), isEmpty);
    });
  });

  group('string collections', () {
    test('airlines fall back to registered owner/operator', () {
      final sightings = [
        _s(airline: 'Lufthansa'),
        _s(registeredOwnerOperator: 'Ryanair'),
        _s(airline: ' Lufthansa '), // trimmed dupe
        _s(), // nothing
      ];
      expect(uniqueAirlines(sightings), {'Lufthansa', 'Ryanair'});
    });

    test('aircraft types and manufacturers are distinct sets', () {
      final sightings = [
        _s(manufacturer: 'Airbus', model: 'A320'),
        _s(manufacturer: 'Airbus', model: 'A321'),
        _s(manufacturer: 'Boeing', model: 'B738'),
      ];
      expect(uniqueManufacturers(sightings), {'Airbus', 'Boeing'});
      expect(uniqueAircraftTypes(sightings), {'A320', 'A321', 'B738'});
    });

    test('registrations are upper-cased', () {
      final sightings = [
        _s(registration: 'd-aize'),
        _s(registration: 'D-AIZE'),
        _s(registration: 'G-EZBA'),
      ];
      expect(uniqueRegistrations(sightings), {'D-AIZE', 'G-EZBA'});
    });
  });

  group('countryForIcao', () {
    test('resolves two-letter prefixes', () {
      expect(countryForIcao('EDDF'), 'Germany');
      expect(countryForIcao('ESSA'), 'Sweden');
      expect(countryForIcao('EGLL'), 'United Kingdom');
      expect(countryForIcao('LFPG'), 'France');
    });

    test('falls back to single-letter prefixes', () {
      expect(countryForIcao('KJFK'), 'United States');
      expect(countryForIcao('CYYZ'), 'Canada');
      expect(countryForIcao('YSSY'), 'Australia');
    });

    test('is null-safe and tolerant of junk', () {
      expect(countryForIcao(null), isNull);
      expect(countryForIcao(''), isNull);
      expect(countryForIcao('X'), isNull);
      expect(countryForIcao('QZZZ'), isNull);
      expect(countryForIcao(' essa '), 'Sweden');
    });
  });

  group('uniqueCountries', () {
    test('derives from both origin and destination ICAO codes', () {
      final sightings = [
        _s(
          origin: const Airport(icao: 'EDDF'),
          destination: const Airport(icao: 'ESSA'),
        ),
        _s(
          origin: const Airport(icao: 'EGLL'),
          destination: const Airport(icao: 'KJFK'),
        ),
      ];
      expect(
        uniqueCountries(sightings),
        {'Germany', 'Sweden', 'United Kingdom', 'United States'},
      );
    });

    test('partial sightings without ICAO do not crash or contribute', () {
      final sightings = [
        _s(destination: const Airport(iata: 'ARN')), // IATA only, no ICAO
        _s(), // nothing
      ];
      expect(uniqueCountries(sightings), isEmpty);
    });
  });

  test('collectionFor dispatches to the matching extractor', () {
    final sightings = [_s(model: 'A320')];
    expect(
      collectionFor(CollectionKind.aircraftTypes, sightings),
      {'A320'},
    );
  });
}
