/// Holds the queue of pending [RewardEvent]s so the Sky tab can surface them as
/// snackbars and then clear them (Phase 6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reward.dart';

/// The pending reward events waiting to be shown. The Sky tab watches this and
/// drains it after presenting the snackbars.
final rewardControllerProvider =
    StateNotifierProvider<RewardController, List<RewardEvent>>(
  (ref) => RewardController(),
);

class RewardController extends StateNotifier<List<RewardEvent>> {
  RewardController() : super(const []);

  /// Queue newly-earned [events] for presentation.
  void emit(List<RewardEvent> events) {
    if (events.isEmpty) return;
    state = [...state, ...events];
  }

  /// Clear the queue once the events have been shown.
  void clear() {
    if (state.isEmpty) return;
    state = const [];
  }
}
