import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/records.dart';
import 'package:skyoverhead/src/domain/sighting.dart';

Sighting _s({
  String icao24 = 'abc123',
  double altitudeM = 10000,
  double? speedMps,
  double distanceKm = 10,
  double elevationDeg = 30,
  int day = 1,
}) {
  return Sighting(
    capturedAt: DateTime.utc(2026, 1, day),
    icao24: icao24,
    altitudeM: altitudeM,
    speedMps: speedMps,
    distanceKm: distanceKm,
    bearingDeg: 0,
    elevationDeg: elevationDeg,
    confidence: Confidence.high,
  );
}

void main() {
  test('empty input yields no records', () {
    expect(computeRecords(const []), isEmpty);
  });

  test('selects highest/farthest/closest/highest-overhead correctly', () {
    final low = _s(icao24: 'low', altitudeM: 5000, distanceKm: 30, elevationDeg: 20);
    final high = _s(icao24: 'high', altitudeM: 12000, distanceKm: 3, elevationDeg: 88);
    final records = computeRecords([low, high]);

    expect(records[RecordKind.highestAltitude]!.sighting.icao24, 'high');
    expect(records[RecordKind.highestAltitude]!.value, 12000);
    expect(records[RecordKind.farthest]!.sighting.icao24, 'low');
    expect(records[RecordKind.farthest]!.value, 30);
    expect(records[RecordKind.closest]!.sighting.icao24, 'high');
    expect(records[RecordKind.closest]!.value, 3);
    expect(records[RecordKind.highestOverhead]!.sighting.icao24, 'high');
  });

  test('fastest ignores null speeds and is absent when none have speed', () {
    final noSpeed = computeRecords([_s(), _s()]);
    expect(noSpeed.containsKey(RecordKind.fastest), isFalse);

    final withSpeed = computeRecords([
      _s(icao24: 'slow', speedMps: 100),
      _s(icao24: 'fast', speedMps: 260),
      _s(icao24: 'nullspeed'),
    ]);
    expect(withSpeed[RecordKind.fastest]!.sighting.icao24, 'fast');
    expect(withSpeed[RecordKind.fastest]!.value, 260);
  });

  test('ties keep the earliest sighting in input order', () {
    final first = _s(icao24: 'first', altitudeM: 9000);
    final second = _s(icao24: 'second', altitudeM: 9000);
    final records = computeRecords([first, second]);
    expect(records[RecordKind.highestAltitude]!.sighting.icao24, 'first');
  });
}
