/// A settings dialog for the identification tuning knobs (search radius and
/// minimum elevation) plus the collector opt-in controls.
///
/// The tuning knobs are applied on **Save** (written back into
/// [identifyConfigProvider]). The collector controls apply **immediately** and
/// persist through their own providers:
///
/// * **Collector mode** ([collectorEnabledProvider]) — the master privacy
///   switch. Turning it off prompts a confirmation and, on confirm, wipes all
///   stored sightings.
/// * **Pause collecting** ([collectorPausedProvider]) — shown only while
///   Collector mode is on; stops new logging but keeps existing data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/identify_config.dart';
import '../state/collector_provider.dart';
import '../state/config_provider.dart';
import '../state/sighting_logger.dart';

/// Opens the settings dialog and, on save, writes the updated radius and
/// minimum elevation back into [identifyConfigProvider].
Future<void> showSettingsDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(identifyConfigProvider);
  // Capture the notifier before awaiting: the calling widget may be disposed
  // while the dialog is open, which would make `ref` unusable afterwards. The
  // provider's notifier outlives the widget, so it stays safe to use.
  final configNotifier = ref.read(identifyConfigProvider.notifier);
  final result = await showDialog<IdentifyConfig>(
    context: context,
    builder: (_) => _SettingsDialog(current: current),
  );
  if (result != null) {
    configNotifier.state = result;
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  final IdentifyConfig current;
  const _SettingsDialog({required this.current});

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  // OpenSky-friendly radius range, matching IdentifyConfig.effectiveRadiusKm.
  static const double _minRadiusKm = 1.0;
  static const double _maxRadiusKm = 50.0;
  // Elevation angle above the horizon, 0 (horizon) .. 90 (straight up).
  static const double _minElevation = 0.0;
  static const double _maxElevation = 90.0;

  late double _radiusKm;
  late double _minElevationDeg;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.current.searchRadiusKm.clamp(_minRadiusKm, _maxRadiusKm);
    _minElevationDeg =
        widget.current.minElevationDeg.clamp(_minElevation, _maxElevation);
  }

  void _submit() {
    final config = widget.current.copyWith(
      searchRadiusKm: _radiusKm,
      minElevationDeg: _minElevationDeg,
    );
    Navigator.of(context).pop(config);
  }

  /// Handle a change to the Collector mode switch. Enabling is immediate;
  /// disabling asks for confirmation and, on confirm, wipes stored sightings.
  Future<void> _onCollectorEnabledChanged(bool value) async {
    final enabled = ref.read(collectorEnabledProvider.notifier);
    if (value) {
      await enabled.set(true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off Collector mode?'),
        content: const Text(
          'This deletes every sighting saved on this device. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Turn off & delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await enabled.set(false);
      await ref.read(collectorPausedProvider.notifier).set(false);
      await ref.read(sightingStoreProvider).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectorEnabled = ref.watch(collectorEnabledProvider);
    final collectorPaused = ref.watch(collectorPausedProvider);

    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Search radius', style: theme.textTheme.titleSmall),
            Text(
              '${_radiusKm.toStringAsFixed(0)} km',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _radiusKm,
              min: _minRadiusKm,
              max: _maxRadiusKm,
              divisions: (_maxRadiusKm - _minRadiusKm).round(),
              label: '${_radiusKm.toStringAsFixed(0)} km',
              onChanged: (v) => setState(() => _radiusKm = v),
            ),
            const SizedBox(height: 16),
            Text('Minimum elevation', style: theme.textTheme.titleSmall),
            Text(
              '${_minElevationDeg.toStringAsFixed(0)}° above the horizon',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _minElevationDeg,
              min: _minElevation,
              max: _maxElevation,
              divisions: (_maxElevation - _minElevation).round(),
              label: '${_minElevationDeg.toStringAsFixed(0)}°',
              onChanged: (v) => setState(() => _minElevationDeg = v),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: collectorEnabled,
              onChanged: _onCollectorEnabledChanged,
              title: const Text('Collector mode'),
              subtitle: const Text(
                'Save the aircraft you identify to a logbook on this device. '
                'Off by default; turning it off deletes everything saved.',
              ),
            ),
            if (collectorEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: collectorPaused,
                onChanged: (v) =>
                    ref.read(collectorPausedProvider.notifier).set(v),
                title: const Text('Pause collecting'),
                subtitle: const Text(
                  'Stop saving new sightings but keep everything already '
                  'collected.',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
