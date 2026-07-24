/// Auto-logging of successful identifications into the sighting store (Phase 2).
///
/// [SightingLogger.logResult] is the single gate that decides whether an
/// [IdentifyResult] becomes a persisted [Sighting]. It logs only when **all**
/// hold:
///
/// * collecting is enabled ([collectorEnabledProvider]),
/// * collecting is not paused ([collectorPausedProvider]),
/// * the result is a successful pick with a non-null candidate (so the
///   "clear skies" `confidence == none` case and errors are never logged), and
/// * the same `icao24` was not already logged within [dedupWindow] (so holding
///   on one plane across repeated taps doesn't inflate counts).
///
/// When collecting is off the store is never touched at all, preserving the
/// original identify-only behaviour.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sighting_store.dart';
import '../domain/models.dart';
import '../domain/sighting.dart';
import 'collector_provider.dart';

/// The concrete sighting store. Defaults to a non-persistent in-memory store;
/// `main()` overrides it with a `SharedPreferences`-backed implementation.
final sightingStoreProvider = Provider<SightingStore<Sighting>>((ref) {
  return InMemorySightingStore<Sighting>();
});

/// The logger wired to the current store and opt-in flags. Flags are read at
/// log time so runtime toggles take effect without rebuilding the logger.
final sightingLoggerProvider = Provider<SightingLogger>((ref) {
  return SightingLogger(
    store: ref.watch(sightingStoreProvider),
    isEnabled: () => ref.read(collectorEnabledProvider),
    isPaused: () => ref.read(collectorPausedProvider),
  );
});

/// The default window within which a repeat sighting of the same aircraft is
/// treated as a duplicate and skipped.
const Duration kDefaultDedupWindow = Duration(seconds: 60);

class SightingLogger {
  final SightingStore<Sighting> store;
  final bool Function() isEnabled;
  final bool Function() isPaused;
  final DateTime Function() now;
  final Duration dedupWindow;

  final Map<String, DateTime> _lastLoggedAt = {};

  SightingLogger({
    required this.store,
    required this.isEnabled,
    required this.isPaused,
    DateTime Function()? now,
    this.dedupWindow = kDefaultDedupWindow,
  }) : now = now ?? DateTime.now;

  /// Persist [result] as a [Sighting] if the gate allows it; otherwise no-op.
  Future<void> logResult(IdentifyResult result) async {
    if (!isEnabled()) return;
    if (isPaused()) return;
    if (result.status != IdentifyStatus.ok) return;

    final candidate = result.candidate;
    if (candidate == null) return; // "clear skies" — nothing to log.

    final timestamp = now();
    final last = _lastLoggedAt[candidate.icao24];
    if (last != null && timestamp.difference(last) < dedupWindow) {
      return; // Same aircraft seen again within the window.
    }

    await store.add(
      Sighting.fromCandidate(
        candidate,
        confidence: result.confidence,
        capturedAt: timestamp,
      ),
    );
    _lastLoggedAt[candidate.icao24] = timestamp;
    _prune(timestamp);
  }

  /// Drop dedup entries older than the window to keep the map bounded.
  void _prune(DateTime reference) {
    _lastLoggedAt.removeWhere(
      (_, at) => reference.difference(at) >= dedupWindow,
    );
  }
}
