/// Route sanity-checking: decide whether an enriched origin/destination is
/// geographically consistent with where the aircraft was observed.
///
/// The route from ADSBDB is keyed only by callsign (a scheduled flight-number
/// mapping) and can be stale or simply wrong for the aircraft actually
/// overhead. We flag a route as implausible when the observed position lies
/// far outside the corridor between its origin and destination.
library;

import 'geo.dart' as geo;
import 'models.dart';

/// How far (km) the observed position may sit from the direct
/// origin->destination corridor before the route is considered implausible.
///
/// Generous on purpose: real flights dogleg via airways and fly arrivals/
/// departures off the great circle, so only clearly-wrong routes (hundreds of
/// km off, e.g. a UK->France route seen over Sweden) should trip this.
const double routeCorridorThresholdKm = 300.0;

/// Judge the [origin]->[destination] route against the observer position.
///
/// Returns [RoutePlausibility.unknown] when either airport lacks coordinates
/// (so no honest judgement is possible), otherwise [plausible] or
/// [implausible] based on the corridor distance.
RoutePlausibility evaluateRoute({
  required double observerLat,
  required double observerLon,
  Airport? origin,
  Airport? destination,
}) {
  final oLat = origin?.latitude;
  final oLon = origin?.longitude;
  final dLat = destination?.latitude;
  final dLon = destination?.longitude;
  if (oLat == null || oLon == null || dLat == null || dLon == null) {
    return RoutePlausibility.unknown;
  }

  final corridorKm = geo.corridorDistanceKm(
    oLat,
    oLon,
    dLat,
    dLon,
    observerLat,
    observerLon,
  );
  return corridorKm > routeCorridorThresholdKm
      ? RoutePlausibility.implausible
      : RoutePlausibility.plausible;
}
