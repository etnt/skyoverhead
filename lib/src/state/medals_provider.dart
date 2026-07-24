/// Providers that derive collections and medals from the logged sightings
/// (Phase 4). All computation is pure and recomputed whenever
/// [sightingsProvider] changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collections.dart';
import '../domain/medals.dart';
import 'sighting_logger.dart';

/// The full medal shelf (ace ladder + themed achievements).
final medalsProvider = Provider<List<Medal>>((ref) {
  final sightings = ref.watch(sightingsProvider);
  return computeMedals(sightings);
});

/// Unique-key counts per collection kind.
final collectionCountsProvider = Provider<Map<CollectionKind, int>>((ref) {
  final sightings = ref.watch(sightingsProvider);
  return collectionCounts(sightings);
});
