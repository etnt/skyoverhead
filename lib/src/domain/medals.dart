/// Medals & achievements computed from `List<Sighting>` (Phase 4).
///
/// Two flavours of reward are produced, both as the same [Medal] value type so
/// the UI can render them uniformly on a shelf:
///
/// * a **tiered ace ladder** (Cadet → Air Marshal) keyed on the number of
///   unique destinations collected, and
/// * a handful of **themed one-off achievements** (High Roller, Speed Demon,
///   Right Overhead, Globe Trotter) driven by predicates over the sightings.
///
/// All thresholds are tunable constants. This library is pure (no Flutter
/// imports) so the logic is trivially unit-testable; the UI maps medal ids to
/// icons separately.
library;

import 'collections.dart';
import 'sighting.dart';

/// A single medal/achievement surfaced to the UI.
class Medal {
  /// Stable identifier (e.g. `ace.cadet`, `themed.highRoller`).
  final String id;
  final String title;
  final String description;
  final bool earned;

  /// Current metric value, clamped to [target] for progress rendering.
  final int progress;

  /// The metric value required to earn the medal.
  final int target;

  const Medal({
    required this.id,
    required this.title,
    required this.description,
    required this.earned,
    required this.progress,
    required this.target,
  });

  /// Progress toward earning, in `[0, 1]`.
  double get ratio {
    if (target <= 0) return 1.0;
    return (progress / target).clamp(0.0, 1.0);
  }
}

/// One rung of the ace ladder: a rank name and the unique-destination count
/// required to reach it.
class AceTier {
  final String id;
  final String name;
  final int threshold;

  const AceTier({
    required this.id,
    required this.name,
    required this.threshold,
  });
}

/// The tiered ace ladder, ascending. Thresholds are unique destinations.
const List<AceTier> kAceTiers = [
  AceTier(id: 'ace.cadet', name: 'Cadet', threshold: 1),
  AceTier(id: 'ace.pilotOfficer', name: 'Pilot Officer', threshold: 5),
  AceTier(id: 'ace.flyingOfficer', name: 'Flying Officer', threshold: 10),
  AceTier(id: 'ace.squadronLeader', name: 'Squadron Leader', threshold: 25),
  AceTier(id: 'ace.wingCommander', name: 'Wing Commander', threshold: 50),
  AceTier(id: 'ace.airMarshal', name: 'Air Marshal', threshold: 100),
];

// Themed achievement thresholds (tunable).
const double kHighRollerAltitudeM = 12000; // ~39,000 ft cruise
const double kSpeedDemonSpeedMps = 280; // ~1,008 km/h
const double kRightOverheadElevationDeg = 85; // nearly straight up
const int kGlobeTrotterCountries = 5;

/// Compute the full medal shelf for [sightings]: the ace ladder followed by the
/// themed achievements. Order is stable and independent of input order.
List<Medal> computeMedals(List<Sighting> sightings) {
  return [
    ...aceLadder(sightings),
    ...themedAchievements(sightings),
  ];
}

/// The ace ladder medals, one per tier.
List<Medal> aceLadder(List<Sighting> sightings) {
  final destinations = uniqueDestinations(sightings).length;
  return [
    for (final tier in kAceTiers)
      Medal(
        id: tier.id,
        title: tier.name,
        description: 'Collect ${tier.threshold} '
            '${tier.threshold == 1 ? 'destination' : 'destinations'}.',
        earned: destinations >= tier.threshold,
        progress: destinations.clamp(0, tier.threshold),
        target: tier.threshold,
      ),
  ];
}

/// The themed one-off achievements.
List<Medal> themedAchievements(List<Sighting> sightings) {
  final maxAltitude = _maxDouble(sightings, (s) => s.altitudeM);
  final maxSpeed = _maxDouble(sightings, (s) => s.speedMps ?? 0);
  final maxElevation = _maxDouble(sightings, (s) => s.elevationDeg);
  final countries = uniqueCountries(sightings).length;

  return [
    Medal(
      id: 'themed.highRoller',
      title: 'High Roller',
      description: 'Spot an aircraft cruising above '
          '${kHighRollerAltitudeM ~/ 1000} km up.',
      earned: maxAltitude >= kHighRollerAltitudeM,
      progress: maxAltitude.clamp(0, kHighRollerAltitudeM).round(),
      target: kHighRollerAltitudeM.round(),
    ),
    Medal(
      id: 'themed.speedDemon',
      title: 'Speed Demon',
      description: 'Catch an aircraft doing over '
          '${(kSpeedDemonSpeedMps * 3.6) ~/ 1} km/h.',
      earned: maxSpeed >= kSpeedDemonSpeedMps,
      progress: maxSpeed.clamp(0, kSpeedDemonSpeedMps).round(),
      target: kSpeedDemonSpeedMps.round(),
    ),
    Medal(
      id: 'themed.rightOverhead',
      title: 'Right Overhead',
      description: 'Identify an aircraft almost straight up '
          '(≥ ${kRightOverheadElevationDeg.round()}°).',
      earned: maxElevation >= kRightOverheadElevationDeg,
      progress: maxElevation.clamp(0, kRightOverheadElevationDeg).round(),
      target: kRightOverheadElevationDeg.round(),
    ),
    Medal(
      id: 'themed.globeTrotter',
      title: 'Globe Trotter',
      description: 'Reach $kGlobeTrotterCountries countries across all routes.',
      earned: countries >= kGlobeTrotterCountries,
      progress: countries.clamp(0, kGlobeTrotterCountries),
      target: kGlobeTrotterCountries,
    ),
  ];
}

/// Unique-key counts for every [CollectionKind], for a collections summary.
Map<CollectionKind, int> collectionCounts(List<Sighting> sightings) {
  return {
    for (final kind in CollectionKind.values)
      kind: collectionFor(kind, sightings).length,
  };
}

double _maxDouble(List<Sighting> sightings, double Function(Sighting) pick) {
  var best = 0.0;
  for (final s in sightings) {
    final v = pick(s);
    if (v > best) best = v;
  }
  return best;
}
