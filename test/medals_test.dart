import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/collections.dart';
import 'package:skyoverhead/src/domain/medals.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/sighting.dart';

Sighting _s({
  String icao24 = 'abc123',
  double altitudeM = 10000,
  double? speedMps,
  double elevationDeg = 30,
  Airport? origin,
  Airport? destination,
}) {
  return Sighting(
    capturedAt: DateTime.utc(2026, 1, 1),
    icao24: icao24,
    altitudeM: altitudeM,
    speedMps: speedMps,
    distanceKm: 10,
    bearingDeg: 0,
    elevationDeg: elevationDeg,
    confidence: Confidence.high,
    origin: origin,
    destination: destination,
  );
}

/// A sighting collecting [n] distinct destinations (`D0`..`D{n-1}` as IATA).
List<Sighting> _withDestinations(int n) => [
      for (var i = 0; i < n; i++)
        _s(destination: Airport(iata: 'D$i')),
    ];

Medal _find(List<Medal> medals, String id) =>
    medals.firstWhere((m) => m.id == id);

void main() {
  group('ace ladder', () {
    test('produces one medal per tier in ascending order', () {
      final medals = aceLadder(const []);
      expect(medals.map((m) => m.id).toList(),
          kAceTiers.map((t) => t.id).toList());
    });

    test('nothing collected earns no tier', () {
      final medals = aceLadder(const []);
      expect(medals.every((m) => !m.earned), isTrue);
      expect(_find(medals, 'ace.cadet').progress, 0);
    });

    test('tier boundaries are inclusive (off-by-one guard)', () {
      // Exactly 5 destinations -> Pilot Officer earned, Flying Officer not.
      final medals = aceLadder(_withDestinations(5));
      final pilot = _find(medals, 'ace.pilotOfficer'); // threshold 5
      final flying = _find(medals, 'ace.flyingOfficer'); // threshold 10

      expect(pilot.earned, isTrue);
      expect(pilot.progress, 5);
      expect(flying.earned, isFalse);
      expect(flying.progress, 5); // clamped to its own target for the bar
      expect(flying.target, 10);
    });

    test('one below a threshold does not earn it', () {
      final medals = aceLadder(_withDestinations(4));
      expect(_find(medals, 'ace.pilotOfficer').earned, isFalse);
      expect(_find(medals, 'ace.cadet').earned, isTrue);
    });

    test('progress clamps and ratio saturates at 1.0 when earned', () {
      final medals = aceLadder(_withDestinations(200));
      final marshal = _find(medals, 'ace.airMarshal');
      expect(marshal.earned, isTrue);
      expect(marshal.progress, marshal.target);
      expect(marshal.ratio, 1.0);
    });
  });

  group('themed achievements', () {
    test('High Roller needs a cruise-altitude sighting', () {
      expect(
        _find(themedAchievements([_s(altitudeM: kHighRollerAltitudeM - 1)]),
                'themed.highRoller')
            .earned,
        isFalse,
      );
      expect(
        _find(themedAchievements([_s(altitudeM: kHighRollerAltitudeM)]),
                'themed.highRoller')
            .earned,
        isTrue,
      );
    });

    test('Speed Demon needs a fast sighting', () {
      expect(
        _find(themedAchievements([_s(speedMps: kSpeedDemonSpeedMps)]),
                'themed.speedDemon')
            .earned,
        isTrue,
      );
      // Null speed must not crash and must not earn it.
      expect(
        _find(themedAchievements([_s()]), 'themed.speedDemon').earned,
        isFalse,
      );
    });

    test('Right Overhead needs a near-vertical elevation', () {
      expect(
        _find(themedAchievements([_s(elevationDeg: kRightOverheadElevationDeg)]),
                'themed.rightOverhead')
            .earned,
        isTrue,
      );
      expect(
        _find(themedAchievements([_s(elevationDeg: 84)]), 'themed.rightOverhead')
            .earned,
        isFalse,
      );
    });

    test('Globe Trotter needs enough distinct countries', () {
      final icaoByCountry = ['ED', 'ES', 'EG', 'LF', 'KJ'];
      final sightings = [
        for (final p in icaoByCountry)
          _s(destination: Airport(icao: '${p}XX')),
      ];
      expect(uniqueCountries(sightings).length, kGlobeTrotterCountries);
      final medal =
          _find(themedAchievements(sightings), 'themed.globeTrotter');
      expect(medal.earned, isTrue);
      expect(medal.progress, kGlobeTrotterCountries);
    });

    test('themed medals are safe on empty input', () {
      final medals = themedAchievements(const []);
      expect(medals.every((m) => !m.earned), isTrue);
      expect(medals.every((m) => m.progress == 0), isTrue);
    });
  });

  group('computeMedals & collectionCounts', () {
    test('computeMedals concatenates ladder then themed', () {
      final medals = computeMedals(const []);
      expect(medals.length, kAceTiers.length + 4);
      expect(medals.first.id, kAceTiers.first.id);
      expect(medals.last.id, 'themed.globeTrotter');
    });

    test('collectionCounts covers every kind', () {
      final counts = collectionCounts([
        _s(destination: const Airport(iata: 'ARN')),
      ]);
      expect(counts.keys.toSet(), CollectionKind.values.toSet());
      expect(counts[CollectionKind.destinations], 1);
    });
  });
}
