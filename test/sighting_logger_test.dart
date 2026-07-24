import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/domain/models.dart';
import 'package:skyoverhead/src/domain/sighting.dart';
import 'package:skyoverhead/src/state/sighting_logger.dart';

import 'support/fake_collector.dart';

Candidate _candidate({String icao24 = 'abc123'}) {
  return Candidate(
    icao24: icao24,
    callsign: 'BAW123',
    registration: 'G-ABCD',
    altitudeM: 10000,
    altitudeSource: AltitudeSource.geometric,
    distanceKm: 12.3,
    bearingDeg: 45,
    elevationDeg: 30,
    speedMps: 250,
    positionAgeS: 2,
  );
}

IdentifyResult _okResult({
  Candidate? candidate,
  Confidence confidence = Confidence.high,
}) {
  return IdentifyResult.ok(
    confidence: confidence,
    candidate: candidate ?? _candidate(),
    alternatives: const [],
    observedAt: DateTime(2024, 1, 1, 12),
  );
}

SightingLogger _logger(
  FakeSightingStore<Sighting> store, {
  required bool enabled,
  required bool paused,
  DateTime Function()? now,
}) {
  return SightingLogger(
    store: store,
    isEnabled: () => enabled,
    isPaused: () => paused,
    now: now,
  );
}

void main() {
  group('SightingLogger gate', () {
    test('logs nothing when collecting is disabled', () async {
      final store = FakeSightingStore<Sighting>();
      final logger = _logger(store, enabled: false, paused: false);

      await logger.logResult(_okResult());

      expect(store.all, isEmpty);
    });

    test('logs nothing when paused and leaves existing data untouched',
        () async {
      final store = FakeSightingStore<Sighting>();
      // Log one while active, then pause and try again.
      final active = _logger(store, enabled: true, paused: false);
      await active.logResult(_okResult(candidate: _candidate(icao24: 'one')));
      expect(store.all, hasLength(1));

      final paused = _logger(store, enabled: true, paused: true);
      await paused.logResult(_okResult(candidate: _candidate(icao24: 'two')));

      expect(store.all, hasLength(1));
      expect(store.all.single.icao24, 'one');
    });

    test('logs one sighting when enabled and not paused', () async {
      final store = FakeSightingStore<Sighting>();
      final logger = _logger(store, enabled: true, paused: false);

      await logger.logResult(_okResult());

      expect(store.all, hasLength(1));
      expect(store.all.single.icao24, 'abc123');
      expect(store.all.single.confidence, Confidence.high);
    });

    test('logs nothing for a clear-skies result', () async {
      final store = FakeSightingStore<Sighting>();
      final logger = _logger(store, enabled: true, paused: false);

      await logger.logResult(
        IdentifyResult.none(observedAt: DateTime(2024, 1, 1, 12)),
      );

      expect(store.all, isEmpty);
    });

    test('logs nothing for an error result', () async {
      final store = FakeSightingStore<Sighting>();
      final logger = _logger(store, enabled: true, paused: false);

      await logger.logResult(
        IdentifyResult.error(
          errorCode: 'boom',
          message: 'Something broke',
          observedAt: DateTime(2024, 1, 1, 12),
        ),
      );

      expect(store.all, isEmpty);
    });
  });

  group('SightingLogger de-duplication', () {
    test('collapses repeat sightings of the same aircraft within the window',
        () async {
      final store = FakeSightingStore<Sighting>();
      var clock = DateTime(2024, 1, 1, 12, 0, 0);
      final logger = _logger(
        store,
        enabled: true,
        paused: false,
        now: () => clock,
      );

      await logger.logResult(_okResult());
      clock = clock.add(const Duration(seconds: 30));
      await logger.logResult(_okResult());

      expect(store.all, hasLength(1));
    });

    test('logs again once the dedup window has elapsed', () async {
      final store = FakeSightingStore<Sighting>();
      var clock = DateTime(2024, 1, 1, 12, 0, 0);
      final logger = _logger(
        store,
        enabled: true,
        paused: false,
        now: () => clock,
      );

      await logger.logResult(_okResult());
      clock = clock.add(const Duration(seconds: 61));
      await logger.logResult(_okResult());

      expect(store.all, hasLength(2));
    });

    test('different aircraft are logged independently', () async {
      final store = FakeSightingStore<Sighting>();
      final logger = _logger(store, enabled: true, paused: false);

      await logger.logResult(_okResult(candidate: _candidate(icao24: 'aaa')));
      await logger.logResult(_okResult(candidate: _candidate(icao24: 'bbb')));

      expect(store.all, hasLength(2));
    });
  });
}
