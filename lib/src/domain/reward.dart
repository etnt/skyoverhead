/// Reward detection (Phase 6): pure diffing of the aggregate state before and
/// after a sighting is logged, producing user-facing "you just unlocked
/// something" events.
///
/// The detector is a pure function of the two sighting lists so it is trivially
/// testable. It reports newly-earned medals and brand-new entries in a curated
/// subset of collections (the travel/aircraft ones that feel like an
/// achievement — registrations and origins are intentionally excluded because a
/// fresh registration on almost every flight would be noise).
library;

import 'collections.dart';
import 'medals.dart';
import 'sighting.dart';

/// The category of a reward, used to pick an icon/emphasis in the UI.
enum RewardKind { medal, collection }

/// A single "just unlocked" event surfaced as a snackbar on the Sky tab.
class RewardEvent {
  final RewardKind kind;
  final String message;

  const RewardEvent({required this.kind, required this.message});

  @override
  bool operator ==(Object other) =>
      other is RewardEvent && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'RewardEvent($kind, "$message")';
}

/// Collections that generate reward feedback, in priority order.
const List<CollectionKind> kRewardCollectionKinds = [
  CollectionKind.destinations,
  CollectionKind.countries,
  CollectionKind.airlines,
  CollectionKind.aircraftTypes,
  CollectionKind.manufacturers,
];

/// A short "New X!" prefix for a collection reward.
String rewardCollectionPrefix(CollectionKind kind) => switch (kind) {
      CollectionKind.destinations => 'New destination!',
      CollectionKind.origins => 'New origin!',
      CollectionKind.airlines => 'New airline!',
      CollectionKind.aircraftTypes => 'New aircraft type!',
      CollectionKind.manufacturers => 'New manufacturer!',
      CollectionKind.registrations => 'New registration!',
      CollectionKind.countries => 'New country!',
    };

/// Detect rewards earned by moving from [before] to [after].
///
/// Medals are reported first (most significant), then new collection entries
/// for [kinds] (defaults to [kRewardCollectionKinds]). Each new collection key
/// yields one event annotated with the running total for that collection.
List<RewardEvent> detectRewards({
  required List<Sighting> before,
  required List<Sighting> after,
  List<CollectionKind> kinds = kRewardCollectionKinds,
}) {
  final events = <RewardEvent>[];

  final earnedBefore = {
    for (final m in computeMedals(before))
      if (m.earned) m.id,
  };
  for (final medal in computeMedals(after)) {
    if (medal.earned && !earnedBefore.contains(medal.id)) {
      events.add(RewardEvent(
        kind: RewardKind.medal,
        message: 'New medal: ${medal.title}',
      ));
    }
  }

  for (final kind in kinds) {
    final was = collectionFor(kind, before);
    final now = collectionFor(kind, after);
    if (now.length <= was.length) continue;
    for (final key in now.difference(was)) {
      events.add(RewardEvent(
        kind: RewardKind.collection,
        message: '${rewardCollectionPrefix(kind)} $key (${now.length} total)',
      ));
    }
  }

  return events;
}
