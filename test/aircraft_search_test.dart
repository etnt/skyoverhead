import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/ui/aircraft_search.dart';
import 'package:skyoverhead/src/ui/format.dart' as fmt;

Candidate _candidate({String? manufacturer, String? model}) {
  return Candidate(
    icao24: '3c6745',
    manufacturer: manufacturer,
    model: model,
    altitudeM: 10000,
    altitudeSource: AltitudeSource.geometric,
    distanceKm: 5,
    bearingDeg: 45,
    elevationDeg: 80,
    positionAgeS: 2,
  );
}

void main() {
  group('aircraftTypeLabel', () {
    test('combines manufacturer and model', () {
      expect(
        fmt.aircraftTypeLabel(_candidate(manufacturer: 'Airbus', model: 'A320')),
        'Airbus A320',
      );
    });

    test('does not repeat a manufacturer already in the model', () {
      expect(
        fmt.aircraftTypeLabel(
          _candidate(manufacturer: 'Boeing', model: 'Boeing 737'),
        ),
        'Boeing 737',
      );
    });

    test('falls back to model or manufacturer alone', () {
      expect(fmt.aircraftTypeLabel(_candidate(model: 'A320')), 'A320');
      expect(fmt.aircraftTypeLabel(_candidate(manufacturer: 'Airbus')), 'Airbus');
    });

    test('is null when neither is known', () {
      expect(fmt.aircraftTypeLabel(_candidate()), isNull);
    });
  });

  group('aircraftSearchUri', () {
    test('builds a Google search for the aircraft type', () {
      final uri =
          aircraftSearchUri(_candidate(manufacturer: 'Airbus', model: 'A320'));
      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'Airbus A320 aircraft');
    });

    test('is null when the aircraft type is unknown', () {
      expect(aircraftSearchUri(_candidate()), isNull);
    });
  });
}
