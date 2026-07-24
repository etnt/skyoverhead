/// Personal-best records computed from `List<Sighting>` (Phase 5).
///
/// Each record keeps the winning numeric [value] and the originating
/// [Sighting], so the UI can show both the figure and which aircraft set it.
/// Selection is pure and stable: on ties the earliest sighting in the input
/// wins, and kinds with no eligible data (e.g. "fastest" when no sighting has a
/// speed) are simply absent from the result map.
library;

import 'sighting.dart';

/// The kinds of personal-best record tracked.
enum RecordKind {
  highestAltitude,
  fastest,
  farthest,
  closest,
  highestOverhead,
}

/// A human label for a [RecordKind].
extension RecordKindLabel on RecordKind {
  String get label => switch (this) {
        RecordKind.highestAltitude => 'Highest altitude',
        RecordKind.fastest => 'Fastest',
        RecordKind.farthest => 'Farthest',
        RecordKind.closest => 'Closest',
        RecordKind.highestOverhead => 'Highest overhead',
      };
}

/// A single record: the [value] that won, and the [sighting] that holds it.
class RecordEntry {
  final RecordKind kind;
  final double value;
  final Sighting sighting;

  const RecordEntry({
    required this.kind,
    required this.value,
    required this.sighting,
  });
}

/// Compute all records from [sightings]. Kinds without eligible data are
/// omitted. The `sightings` list order is treated as the tie-break order
/// (earliest wins), so pass it in a stable order.
Map<RecordKind, RecordEntry> computeRecords(List<Sighting> sightings) {
  final records = <RecordKind, RecordEntry>{};

  final highestAltitude = _best(
    sightings,
    metric: (s) => s.altitudeM,
    keepHigher: true,
  );
  if (highestAltitude != null) {
    records[RecordKind.highestAltitude] = RecordEntry(
      kind: RecordKind.highestAltitude,
      value: highestAltitude.value,
      sighting: highestAltitude.sighting,
    );
  }

  final fastest = _best(
    sightings,
    metric: (s) => s.speedMps,
    keepHigher: true,
  );
  if (fastest != null) {
    records[RecordKind.fastest] = RecordEntry(
      kind: RecordKind.fastest,
      value: fastest.value,
      sighting: fastest.sighting,
    );
  }

  final farthest = _best(
    sightings,
    metric: (s) => s.distanceKm,
    keepHigher: true,
  );
  if (farthest != null) {
    records[RecordKind.farthest] = RecordEntry(
      kind: RecordKind.farthest,
      value: farthest.value,
      sighting: farthest.sighting,
    );
  }

  final closest = _best(
    sightings,
    metric: (s) => s.distanceKm,
    keepHigher: false,
  );
  if (closest != null) {
    records[RecordKind.closest] = RecordEntry(
      kind: RecordKind.closest,
      value: closest.value,
      sighting: closest.sighting,
    );
  }

  final highestOverhead = _best(
    sightings,
    metric: (s) => s.elevationDeg,
    keepHigher: true,
  );
  if (highestOverhead != null) {
    records[RecordKind.highestOverhead] = RecordEntry(
      kind: RecordKind.highestOverhead,
      value: highestOverhead.value,
      sighting: highestOverhead.sighting,
    );
  }

  return records;
}

class _Best {
  final double value;
  final Sighting sighting;
  const _Best(this.value, this.sighting);
}

/// Pick the sighting whose [metric] is the highest (or lowest) non-null value.
/// Returns `null` when no sighting has an eligible value. Ties keep the first.
_Best? _best(
  List<Sighting> sightings, {
  required double? Function(Sighting) metric,
  required bool keepHigher,
}) {
  _Best? best;
  for (final s in sightings) {
    final v = metric(s);
    if (v == null) continue;
    if (best == null ||
        (keepHigher ? v > best.value : v < best.value)) {
      best = _Best(v, s);
    }
  }
  return best;
}
