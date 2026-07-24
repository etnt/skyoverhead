/// Providers deriving personal-best records and aggregate statistics from the
/// logged sightings (Phase 5). Pure computation, recomputed whenever
/// [sightingsProvider] changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/records.dart';
import '../domain/statistics.dart';
import 'sighting_logger.dart';

/// Personal-best records, keyed by [RecordKind] (absent kinds have no data).
final recordsProvider = Provider<Map<RecordKind, RecordEntry>>((ref) {
  final sightings = ref.watch(sightingsProvider);
  return computeRecords(sightings);
});

/// Aggregate statistics snapshot.
final statisticsProvider = Provider<Statistics>((ref) {
  final sightings = ref.watch(sightingsProvider);
  return computeStatistics(sightings);
});
