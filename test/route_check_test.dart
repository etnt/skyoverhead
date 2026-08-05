import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/route_check.dart';

void main() {
  // Approximate airport coordinates used across the cases below.
  const bournemouth = Airport(
    icao: 'EGHH',
    iata: 'BOH',
    name: 'Bournemouth',
    latitude: 50.78,
    longitude: -1.84,
  );
  const bergerac = Airport(
    icao: 'LFBE',
    iata: 'EGC',
    name: 'Bergerac',
    latitude: 44.82,
    longitude: 0.52,
  );
  const frankfurt = Airport(
    icao: 'EDDF',
    iata: 'FRA',
    name: 'Frankfurt am Main',
    latitude: 50.03,
    longitude: 8.57,
  );
  const arlanda = Airport(
    icao: 'ESSA',
    iata: 'ARN',
    name: 'Stockholm Arlanda',
    latitude: 59.65,
    longitude: 17.92,
  );

  group('evaluateRoute', () {
    test('is unknown when an airport coordinate is missing', () {
      final result = evaluateRoute(
        observerLat: 59.33,
        observerLon: 18.06,
        origin: bournemouth,
        destination: const Airport(icao: 'LFBE', iata: 'EGC', name: 'Bergerac'),
      );
      expect(result, RoutePlausibility.unknown);
    });

    test('is unknown when there is no route at all', () {
      final result = evaluateRoute(
        observerLat: 59.33,
        observerLon: 18.06,
        origin: null,
        destination: null,
      );
      expect(result, RoutePlausibility.unknown);
    });

    test('flags a route seen far from its corridor as implausible', () {
      // A Bournemouth -> Bergerac flight can't be seen over Stockholm.
      final result = evaluateRoute(
        observerLat: 59.33,
        observerLon: 18.06,
        origin: bournemouth,
        destination: bergerac,
      );
      expect(result, RoutePlausibility.implausible);
    });

    test('accepts a route seen near its corridor as plausible', () {
      // A Frankfurt -> Stockholm flight seen near Arlanda is fine.
      final result = evaluateRoute(
        observerLat: 59.33,
        observerLon: 18.06,
        origin: frankfurt,
        destination: arlanda,
      );
      expect(result, RoutePlausibility.plausible);
    });
  });
}
