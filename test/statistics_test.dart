import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/sighting.dart';
import 'package:skyoverhead/src/domain/statistics.dart';

Sighting _s({
  String icao24 = 'abc123',
  String? model,
  String? airline,
  String? registeredOwnerOperator,
  Airport? destination,
  Airport? origin,
  double bearingDeg = 0,
  Confidence confidence = Confidence.high,
  DateTime? capturedAt,
}) {
  return Sighting(
    capturedAt: capturedAt ?? DateTime(2026, 1, 1),
    icao24: icao24,
    model: model,
    airline: airline,
    registeredOwnerOperator: registeredOwnerOperator,
    destination: destination,
    origin: origin,
    altitudeM: 10000,
    distanceKm: 10,
    bearingDeg: bearingDeg,
    elevationDeg: 30,
    confidence: confidence,
  );
}

Airport _dest(String iata, {String? name}) => Airport(iata: iata, name: name);

void main() {
  test('empty input returns the empty snapshot', () {
    final s = computeStatistics(const []);
    expect(s.total, 0);
    expect(s.topDestinations, isEmpty);
    expect(s.rarestDestination, isNull);
    expect(s.longestDayStreak, 0);
    expect(s.bearingBins, List<int>.filled(kBearingBins, 0));
  });

  test('top-N counts occurrences and orders by count then key', () {
    final s = computeStatistics([
      _s(destination: _dest('ARN')),
      _s(destination: _dest('ARN')),
      _s(destination: _dest('FRA')),
      _s(destination: _dest('BER')),
      _s(destination: _dest('BER')),
    ]);
    expect(s.topDestinations.first, const Tally('ARN', 2));
    // ARN(2) and BER(2) tie -> alphabetical, so ARN before BER.
    expect(s.topDestinations[1], const Tally('BER', 2));
    expect(s.topDestinations[2], const Tally('FRA', 1));
  });

  test('top-N is capped at five entries', () {
    final s = computeStatistics([
      for (var i = 0; i < 8; i++) _s(destination: _dest('D$i')),
    ]);
    expect(s.topDestinations, hasLength(5));
  });

  test('rarest destination picks the lowest count, ties alphabetical', () {
    final s = computeStatistics([
      _s(destination: _dest('ARN')),
      _s(destination: _dest('ARN')),
      _s(destination: _dest('ZRH')),
      _s(destination: _dest('BER')),
    ]);
    // ZRH(1) and BER(1) tie -> alphabetical BER wins.
    expect(s.rarestDestination, const Tally('BER', 1));
  });

  test('single-occurrence destination is its own rarest', () {
    final s = computeStatistics([_s(destination: _dest('ARN'))]);
    expect(s.rarestDestination, const Tally('ARN', 1));
  });

  test('airlines fall back to registered owner/operator', () {
    final s = computeStatistics([
      _s(airline: 'Lufthansa'),
      _s(registeredOwnerOperator: 'Ryanair'),
      _s(airline: 'Lufthansa'),
    ]);
    expect(s.topAirlines.first, const Tally('Lufthansa', 2));
  });

  test('longest day streak counts consecutive days and breaks on gaps', () {
    final s = computeStatistics([
      _s(capturedAt: DateTime(2026, 3, 1)),
      _s(capturedAt: DateTime(2026, 3, 2)),
      _s(capturedAt: DateTime(2026, 3, 3)),
      // gap
      _s(capturedAt: DateTime(2026, 3, 6)),
      _s(capturedAt: DateTime(2026, 3, 7)),
    ]);
    expect(s.longestDayStreak, 3);
    expect(s.perDay.length, 5);
  });

  test('multiple sightings on the same day count once for the streak', () {
    final s = computeStatistics([
      _s(capturedAt: DateTime(2026, 3, 1, 9)),
      _s(capturedAt: DateTime(2026, 3, 1, 18)),
      _s(capturedAt: DateTime(2026, 3, 2, 12)),
    ]);
    expect(s.longestDayStreak, 2);
    expect(s.perDay[DateTime(2026, 3, 1)], 2);
  });

  test('confidence mix and total tally every sighting', () {
    final s = computeStatistics([
      _s(confidence: Confidence.high),
      _s(confidence: Confidence.high),
      _s(confidence: Confidence.medium),
    ]);
    expect(s.total, 3);
    expect(s.confidenceMix[Confidence.high], 2);
    expect(s.confidenceMix[Confidence.medium], 1);
  });

  test('bearing bins map degrees to the nearest 8-point sector', () {
    final s = computeStatistics([
      _s(bearingDeg: 0), // N -> 0
      _s(bearingDeg: 359), // wraps to N -> 0
      _s(bearingDeg: 90), // E -> 2
      _s(bearingDeg: 200), // S/SW boundary -> 4 (S is 157.5..202.5)
    ]);
    expect(s.bearingBins[0], 2);
    expect(s.bearingBins[2], 1);
    expect(s.bearingBins[4], 1);
    expect(s.bearingBins.reduce((a, b) => a + b), 4);
  });

  test('partial sightings without destination/model do not crash or count', () {
    final s = computeStatistics([_s(), _s()]);
    expect(s.total, 2);
    expect(s.topDestinations, isEmpty);
    expect(s.topTypes, isEmpty);
    expect(s.rarestDestination, isNull);
  });

  test('origins are tallied independently of destinations', () {
    final s = computeStatistics([
      _s(origin: _dest('LHR'), destination: _dest('ARN')),
      _s(origin: _dest('LHR'), destination: _dest('ARN')),
      _s(origin: _dest('CDG'), destination: _dest('ARN')),
    ]);
    expect(s.topOrigins.first, const Tally('LHR', 2));
    expect(s.topOrigins[1], const Tally('CDG', 1));
    expect(s.rarestOrigin, const Tally('CDG', 1));
    // Destinations are unaffected.
    expect(s.topDestinations.first, const Tally('ARN', 3));
  });

  test('excluded airports drop from both origin and destination tallies', () {
    final s = computeStatistics(
      [
        _s(origin: _dest('ARN'), destination: _dest('LHR')),
        _s(origin: _dest('CDG'), destination: _dest('ARN')),
        _s(origin: _dest('CDG'), destination: _dest('FRA')),
      ],
      excluded: {'ARN'},
    );
    // ARN removed as both an origin and a destination.
    expect(s.topOrigins.map((t) => t.key), isNot(contains('ARN')));
    expect(s.topDestinations.map((t) => t.key), isNot(contains('ARN')));
    expect(s.topOrigins.first, const Tally('CDG', 2));
    expect(s.topDestinations.map((t) => t.key),
        containsAll(<String>['LHR', 'FRA']));
    // The excluded sightings still count toward the total.
    expect(s.total, 3);
  });

  test('exclusion matching is case-insensitive', () {
    final s = computeStatistics(
      [_s(destination: _dest('ARN')), _s(destination: _dest('FRA'))],
      excluded: {'arn'},
    );
    expect(s.topDestinations.map((t) => t.key), isNot(contains('ARN')));
    expect(s.topDestinations.first, const Tally('FRA', 1));
  });

  test('airport names are captured for origins and destinations', () {
    final s = computeStatistics([
      _s(
        origin: _dest('LHR', name: 'London Heathrow'),
        destination: _dest('ARN', name: 'Stockholm Arlanda'),
      ),
      // A later sighting with no name must not clobber the known one.
      _s(destination: _dest('ARN')),
    ]);
    expect(s.airportNames['ARN'], 'Stockholm Arlanda');
    expect(s.airportNames['LHR'], 'London Heathrow');
    // Codes without any known name are simply absent.
    final noName = computeStatistics([_s(destination: _dest('BER'))]);
    expect(noName.airportNames.containsKey('BER'), isFalse);
  });
}
