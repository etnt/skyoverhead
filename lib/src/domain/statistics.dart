/// Aggregate statistics computed from `List<Sighting>` (Phase 5).
///
/// Unlike collections (which use unique keys), statistics use **raw counts**:
/// every sighting contributes to its destination/airline/type tallies, per-day
/// buckets, confidence mix and bearing distribution. All computation is pure
/// and tolerant of partial data — missing fields simply don't count.
library;

import 'collections.dart';
import 'models.dart';
import 'sighting.dart';

/// A `(key, count)` pair used in top-N and rarity results.
class Tally {
  final String key;
  final int count;
  const Tally(this.key, this.count);

  @override
  bool operator ==(Object other) =>
      other is Tally && other.key == key && other.count == count;

  @override
  int get hashCode => Object.hash(key, count);

  @override
  String toString() => '$key×$count';
}

/// The number of compass bins in the bearing distribution (8-point rose).
const int kBearingBins = 8;

/// Immutable snapshot of aggregate statistics.
class Statistics {
  final int total;
  final List<Tally> topDestinations;
  final List<Tally> topOrigins;
  final List<Tally> topAirlines;
  final List<Tally> topTypes;

  /// The least-frequently seen destination (ties broken alphabetically), or
  /// `null` when no destinations are known.
  final Tally? rarestDestination;

  /// The least-frequently seen origin (ties broken alphabetically), or `null`
  /// when no origins are known.
  final Tally? rarestOrigin;

  /// Count of sightings per calendar day (local midnight → count).
  final Map<DateTime, int> perDay;

  /// Longest run of consecutive calendar days that each have ≥1 sighting.
  final int longestDayStreak;

  /// Count of sightings per [Confidence] level.
  final Map<Confidence, int> confidenceMix;

  /// Sighting counts across [kBearingBins] compass sectors, index 0 = North,
  /// advancing clockwise (NE, E, …).
  final List<int> bearingBins;

  /// Best-known full name for each airport code seen as an origin or
  /// destination (code → name). Codes without a known name are absent.
  final Map<String, String> airportNames;

  const Statistics({
    required this.total,
    required this.topDestinations,
    required this.topOrigins,
    required this.topAirlines,
    required this.topTypes,
    required this.rarestDestination,
    required this.rarestOrigin,
    required this.perDay,
    required this.longestDayStreak,
    required this.confidenceMix,
    required this.bearingBins,
    required this.airportNames,
  });

  /// An empty snapshot for when nothing has been collected.
  factory Statistics.empty() => Statistics(
        total: 0,
        topDestinations: const [],
        topOrigins: const [],
        topAirlines: const [],
        topTypes: const [],
        rarestDestination: null,
        rarestOrigin: null,
        perDay: const {},
        longestDayStreak: 0,
        confidenceMix: const {},
        bearingBins: List<int>.filled(kBearingBins, 0),
        airportNames: const {},
      );
}

/// Compute aggregate [Statistics] over [sightings].
///
/// [excluded] airport codes (IATA/ICAO, matched case-insensitively) are dropped
/// from both the origin and destination tallies — useful for hiding a home
/// airport that would otherwise dominate the lists. Excluded airports still
/// count toward the total and every other statistic.
Statistics computeStatistics(
  List<Sighting> sightings, {
  int topN = 5,
  Set<String> excluded = const {},
}) {
  if (sightings.isEmpty) return Statistics.empty();

  final excludedCodes = {
    for (final c in excluded)
      if (c.trim().isNotEmpty) c.trim().toUpperCase(),
  };

  final destinationCounts = <String, int>{};
  final originCounts = <String, int>{};
  final airlineCounts = <String, int>{};
  final typeCounts = <String, int>{};
  final perDay = <DateTime, int>{};
  final confidenceMix = <Confidence, int>{};
  final bearingBins = List<int>.filled(kBearingBins, 0);
  final airportNames = <String, String>{};

  for (final s in sightings) {
    _recordName(airportNames, s.destination);
    _recordName(airportNames, s.origin);

    final dest = airportCode(s.destination);
    if (dest != null && !excludedCodes.contains(dest)) {
      destinationCounts[dest] = (destinationCounts[dest] ?? 0) + 1;
    }

    final origin = airportCode(s.origin);
    if (origin != null && !excludedCodes.contains(origin)) {
      originCounts[origin] = (originCounts[origin] ?? 0) + 1;
    }

    final airline = (s.airline ?? s.registeredOwnerOperator)?.trim();
    if (airline != null && airline.isNotEmpty) {
      airlineCounts[airline] = (airlineCounts[airline] ?? 0) + 1;
    }

    final type = s.model?.trim();
    if (type != null && type.isNotEmpty) {
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    final day = _dayKey(s.capturedAt);
    perDay[day] = (perDay[day] ?? 0) + 1;

    confidenceMix[s.confidence] = (confidenceMix[s.confidence] ?? 0) + 1;

    bearingBins[_bearingBin(s.bearingDeg)]++;
  }

  return Statistics(
    total: sightings.length,
    topDestinations: _topN(destinationCounts, topN),
    topOrigins: _topN(originCounts, topN),
    topAirlines: _topN(airlineCounts, topN),
    topTypes: _topN(typeCounts, topN),
    rarestDestination: _rarest(destinationCounts),
    rarestOrigin: _rarest(originCounts),
    perDay: perDay,
    longestDayStreak: _longestStreak(perDay.keys),
    confidenceMix: confidenceMix,
    bearingBins: bearingBins,
    airportNames: airportNames,
  );
}

/// Sort by count descending, ties broken by key ascending; take the first [n].
List<Tally> _topN(Map<String, int> counts, int n) {
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [
    for (final e in entries.take(n)) Tally(e.key, e.value),
  ];
}

/// The minimum-count key, ties broken by key ascending; `null` when empty.
Tally? _rarest(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = a.value.compareTo(b.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  final e = entries.first;
  return Tally(e.key, e.value);
}

/// Longest run of consecutive calendar days present in [days].
int _longestStreak(Iterable<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var longest = 1;
  var current = 1;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    if (gap == 1) {
      current++;
      if (current > longest) longest = current;
    } else if (gap > 1) {
      current = 1;
    }
    // gap == 0 can't happen for de-duplicated day keys.
  }
  return longest;
}

DateTime _dayKey(DateTime t) => DateTime(t.year, t.month, t.day);

/// Remember the first non-empty name seen for an airport's code.
void _recordName(Map<String, String> names, Airport? airport) {
  final code = airportCode(airport);
  if (code == null) return;
  final name = airport?.name?.trim();
  if (name != null && name.isNotEmpty) {
    names.putIfAbsent(code, () => name);
  }
}

/// Map a bearing (degrees) to an 8-point compass bin, 0 = North.
int _bearingBin(double bearingDeg) {
  final normalized = bearingDeg % 360.0;
  final positive = normalized < 0 ? normalized + 360.0 : normalized;
  return (((positive + 22.5) ~/ 45)) % kBearingBins;
}
