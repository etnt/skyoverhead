/// The app's single screen: a location chip, a big "what's overhead?"
/// button, and a result area that reflects the [IdentifyController] state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_version.dart';
import '../domain/reward.dart';
import '../state/collector_provider.dart';
import '../state/config_provider.dart';
import '../state/identify_controller.dart';
import '../state/medals_provider.dart';
import '../state/reward_provider.dart';
import 'location_bar.dart';
import 'rank_badge.dart';
import 'result_card.dart';
import 'settings_dialog.dart';

/// The most reward snackbars to surface from a single log, to avoid flooding
/// the Sky tab when a notable first sighting unlocks several things at once.
const int kMaxRewardSnackbars = 3;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Whether the large area shows the rank medal (true) or the identify result
  /// (false). Defaults to the medal; a scan reveals the result, and the medal
  /// button brings it back.
  bool _showMedal = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identifyControllerProvider);
    final config = ref.watch(identifyConfigProvider);
    final isLoading = state is IdentifyLoading;
    final collectorEnabled = ref.watch(collectorEnabledProvider);

    ref.listen<List<RewardEvent>>(rewardControllerProvider, (_, next) {
      if (next.isEmpty) return;
      final messenger = ScaffoldMessenger.of(context);
      for (final event in next.take(kMaxRewardSnackbars)) {
        messenger.showSnackBar(_rewardSnackBar(event));
      }
      ref.read(rewardControllerProvider.notifier).clear();
    });

    // A new scan (loading → result) reveals the result area over the medal.
    ref.listen<IdentifyUiState>(identifyControllerProvider, (_, next) {
      if (next is! IdentifyIdle && _showMedal) {
        setState(() => _showMedal = false);
      }
    });

    final showMedalView = collectorEnabled && _showMedal;

    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            text: 'Sky Overhead',
            children: [
              TextSpan(
                text: '  $appVersion',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => showSettingsDialog(context, ref),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocationBar(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(identifyControllerProvider.notifier)
                              .identify(config),
                      icon: const Icon(Icons.flight),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text("What's overhead?"),
                      ),
                    ),
                  ),
                  if (collectorEnabled) ...[
                    const SizedBox(width: 12),
                    _MedalToggleButton(
                      active: showMedalView,
                      onPressed: () =>
                          setState(() => _showMedal = !_showMedal),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: showMedalView
                      ? const _RankView(key: ValueKey('medal'))
                      : _ResultArea(
                          key: ValueKey(state.runtimeType),
                          state: state,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small button beside "What's overhead?" that toggles the large rank
/// medal in and out of view.
class _MedalToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;

  const _MedalToggleButton({required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(active ? Icons.flight_takeoff : Icons.military_tech);
    return SizedBox(
      height: 52,
      width: 52,
      child: active
          ? IconButton.filled(
              tooltip: 'Show last result',
              onPressed: onPressed,
              icon: icon,
            )
          : IconButton.filledTonal(
              tooltip: 'Show rank medal',
              onPressed: onPressed,
              icon: icon,
            ),
    );
  }
}

/// The large rank medal shown in the result area: a gold laurel medallion, the
/// current rank name, and progress toward the next rank. A shortcut opens the
/// Medals tab for the full shelf.
class _RankView extends ConsumerWidget {
  const _RankView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final standing = ref.watch(aceStandingProvider);

    final String title;
    final String subtitle;
    if (!standing.hasRank) {
      title = 'Unranked';
      subtitle = 'Spot an aircraft with a destination to earn Cadet.';
    } else {
      title = standing.current!.name;
      final next = standing.next;
      subtitle = next == null
          ? 'Top rank — Air Marshal achieved!'
          : '${standing.toNext} more '
              '${standing.toNext == 1 ? 'destination' : 'destinations'} '
              'to ${next.name}';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RankBadge(standing: standing, size: 176),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (standing.hasRank) ...[
              const SizedBox(height: 2),
              Text(
                'Rank ${standing.level} of ${standing.maxLevel}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: standing.progressToNext,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  ref.read(selectedTabProvider.notifier).state = 2,
              icon: const Icon(Icons.military_tech),
              label: const Text('View all medals'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultArea extends ConsumerWidget {
  final IdentifyUiState state;
  const _ResultArea({super.key, required this.state});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state) {
      case IdentifyIdle():
        return const _Centered(
          icon: Icons.travel_explore,
          title: 'Point at the sky',
          message: 'Tap the button to identify the aircraft overhead.',
        );
      case IdentifyLoading():
        return const _Centered(
          icon: null,
          title: 'Scanning the sky…',
          message: 'Looking up live traffic near you.',
          showSpinner: true,
        );
      case IdentifySuccess(:final result):
        if (result.hasCandidate) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResultCard(
                  candidate: result.candidate!,
                  confidence: result.confidence,
                ),
              ],
            ),
          );
        }
        return _Centered(
          icon: Icons.cloud_queue,
          title: 'Clear skies',
          message: result.message ?? 'No aircraft overhead right now.',
        );
      case IdentifyFailure(:final message):
        return _Centered(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: message,
          action: FilledButton.tonal(
            onPressed: () {
              final config = ref.read(identifyConfigProvider);
              ref.read(identifyControllerProvider.notifier).identify(config);
            },
            child: const Text('Try again'),
          ),
        );
    }
  }
}

class _Centered extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final bool showSpinner;
  final Widget? action;

  const _Centered({
    required this.icon,
    required this.title,
    required this.message,
    this.showSpinner = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const CircularProgressIndicator()
          else if (icon != null)
            Icon(icon, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Build a compact snackbar for a reward, with an icon reflecting its kind.
SnackBar _rewardSnackBar(RewardEvent event) {
  final icon = switch (event.kind) {
    RewardKind.medal => Icons.military_tech,
    RewardKind.collection => Icons.auto_awesome,
  };
  return SnackBar(
    duration: const Duration(milliseconds: 2500),
    behavior: SnackBarBehavior.floating,
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(event.message)),
      ],
    ),
  );
}
