/// A debug-only [AircraftService] that returns a fixed, fully-enriched
/// sighting instead of hitting OpenSky/ADSBDB. Enabled by building with
/// `--dart-define=MOCK_IDENTIFY=true`, which is handy for testing UI flows
/// (e.g. the tap-to-search link) on an emulator where the live lookup is
/// slow or rate-limited.
library;

import '../config/identify_config.dart';
import '../domain/models.dart';
import 'aircraft_service.dart';

class MockAircraftService implements AircraftService {
  MockAircraftService();

  @override
  Future<IdentifyResult> identify(IdentifyConfig config) async {
    // Simulate a short round-trip so the loading state is visible.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return IdentifyResult.ok(
      confidence: Confidence.medium,
      candidate: _sas46m,
      alternatives: const [],
      observedAt: DateTime.now(),
    );
  }
}

/// A real sighting captured on-device (SAS46M, Copenhagen → Arlanda), used so
/// the mock renders a realistic result card.
final _sas46m = Candidate(
  icao24: '4ac9e5',
  callsign: 'SAS46M',
  registration: 'LN-RGN',
  manufacturer: 'Airbus',
  model: 'A320 251NSL',
  airline: 'Scandinavian Airlines System',
  origin: const Airport(
    icao: 'EKCH',
    iata: 'CPH',
    name: 'Copenhagen Kastrup Airport',
  ),
  destination: const Airport(
    icao: 'ESSA',
    iata: 'ARN',
    name: 'Stockholm-Arlanda Airport',
  ),
  altitudeM: 3780,
  altitudeSource: AltitudeSource.geometric,
  baroAltitudeM: 3673,
  distanceKm: 2.2,
  bearingDeg: 348,
  elevationDeg: 60,
  speedMps: 180,
  positionAgeS: 2,
  enrichmentStatus: EnrichmentStatus.ok,
);
