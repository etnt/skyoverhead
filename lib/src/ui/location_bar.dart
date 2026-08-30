/// The observer-location row: current coordinates, a "use my location"
/// action, and a location picker.
///
/// * GPS button: tap = get current location; **long-press** = save the current
///   position under a name.
/// * Edit button: open the location picker — a single dialog with two parts:
///   pick a saved location (tap to load, trash to delete) or enter a new one
///   (with an optional name to save it).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/identify_config.dart';
import '../domain/saved_location.dart';
import '../state/config_provider.dart';
import '../state/location_controller.dart';
import '../state/saved_locations_provider.dart';

class LocationBar extends ConsumerWidget {
  const LocationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(identifyConfigProvider);
    final locationState = ref.watch(locationControllerProvider);
    final locating = locationState is LocationLocating;
    final activeLocation = _findEntry(
      ref,
      ref.watch(activeSavedLocationProvider),
    );

    // Surface location failures as a SnackBar, then reset the controller.
    ref.listen<LocationUiState>(locationControllerProvider, (previous, next) {
      if (next is LocationFailed) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.message)));
        ref.read(locationControllerProvider.notifier).clearError();
      }
    });

    final coords =
        '${config.latitude.toStringAsFixed(4)}, ${config.longitude.toStringAsFixed(4)}';
    final chipLabel = activeLocation == null
        ? 'Observing from $coords'
        : 'Observing from ${activeLocation.name} ($coords)';

    return Row(
      children: [
        Expanded(
          child: Chip(
            avatar: const Icon(Icons.my_location, size: 18),
            label: Text(chipLabel),
          ),
        ),
        IconButton(
          tooltip: 'Use my location (hold to save)',
          onPressed: locating
              ? null
              : () => ref
                    .read(locationControllerProvider.notifier)
                    .useCurrentLocation(),
          onLongPress: () => _saveCurrentLocation(context, ref, config),
          icon: locating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.gps_fixed),
        ),
        IconButton(
          tooltip: 'Pick or enter a location',
          onPressed: () => _editLocation(context, ref, config),
          icon: const Icon(Icons.edit_location_alt_outlined),
        ),
      ],
    );
  }

  SavedLocation? _findEntry(WidgetRef ref, String? id) {
    if (id == null) return null;
    for (final entry in ref.watch(savedLocationsProvider)) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Long-press on the GPS button: save the current position under a name.
  Future<void> _saveCurrentLocation(
    BuildContext context,
    WidgetRef ref,
    IdentifyConfig current,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveLocationNameDialog(current: current),
    );
    if (name == null || name.trim().isEmpty) return;
    final entry = await ref
        .read(savedLocationsProvider.notifier)
        .save(name, current);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Location "${entry.name}" saved.'),
            duration: const Duration(milliseconds: 2500),
          ),
        );
    }
  }

  /// Tap the edit button: pick a saved location or enter a new one.
  Future<void> _editLocation(
    BuildContext context,
    WidgetRef ref,
    IdentifyConfig current,
  ) async {
    final result = await showDialog<_ManualLocationResult>(
      context: context,
      builder: (_) => _LocationDialog(current: current),
    );
    if (result == null) return;
    ref.read(identifyConfigProvider.notifier).state = result.config;
    if (result.saveAsName != null) {
      await ref
          .read(savedLocationsProvider.notifier)
          .save(result.saveAsName!, result.config);
    } else {
      // A plain manual entry matches the active label only when its
      // coordinates exactly equal a saved location.
      ref
          .read(savedLocationsProvider.notifier)
          .syncActiveForConfig(result.config);
    }
  }
}

/// The outcome of the manual-entry dialog: the config to apply and, when the
/// user filled in the name field, the name to save it under.
class _ManualLocationResult {
  final IdentifyConfig config;

  /// Non-null when the entered location should also be saved under this name.
  final String? saveAsName;
  const _ManualLocationResult(this.config, this.saveAsName);
}

/// The location picker: two clear parts — pick a saved location (tap to load,
/// trash to delete) or enter a new one (with an optional name to save it).
class _LocationDialog extends ConsumerStatefulWidget {
  final IdentifyConfig current;
  const _LocationDialog({required this.current});

  @override
  ConsumerState<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends ConsumerState<_LocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(text: widget.current.latitude.toString());
    _lon = TextEditingController(text: widget.current.longitude.toString());
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validate(String? value, double min, double max) {
    final text = value?.trim() ?? '';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a number';
    if (parsed < min || parsed > max) return 'Must be between $min and $max';
    return null;
  }

  /// Load a saved location as the observing position and close the dialog.
  void _load(SavedLocation entry) {
    ref.read(savedLocationsProvider.notifier).apply(entry);
    Navigator.of(context).pop();
  }

  /// Apply the manually entered coordinates, saving under a name when given.
  void _submitNew() {
    if (!_formKey.currentState!.validate()) return;
    final config = widget.current.copyWith(
      latitude: double.parse(_lat.text.trim()),
      longitude: double.parse(_lon.text.trim()),
    );
    final name = _name.text.trim();
    Navigator.of(
      context,
    ).pop(_ManualLocationResult(config, name.isEmpty ? null : name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const numeric = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    final inputFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
    ];
    final saved = ref.watch(savedLocationsProvider);

    return AlertDialog(
      title: const Text('Location'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Saved locations', style: theme.textTheme.titleSmall),
                if (saved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'None yet. Enter a location below and give it a name to '
                      'save it here.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  for (final entry in saved)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(entry.name),
                      subtitle: Text(
                        '${entry.latitude.toStringAsFixed(4)}, '
                        '${entry.longitude.toStringAsFixed(4)}',
                      ),
                      onTap: () => _load(entry),
                      trailing: IconButton(
                        tooltip: 'Delete ${entry.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(savedLocationsProvider.notifier)
                            .delete(entry.id),
                      ),
                    ),
                const Divider(height: 24),
                Text('Enter a new location', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lat,
                  keyboardType: numeric,
                  inputFormatters: inputFormatters,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  validator: (v) => _validate(v, -90.0, 90.0),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lon,
                  keyboardType: numeric,
                  inputFormatters: inputFormatters,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  validator: (v) => _validate(v, -180.0, 180.0),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    helperText: 'Give it a name to save it above',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submitNew, child: const Text('Set location')),
      ],
    );
  }
}

/// Long-press on the GPS button: a single name field for the current position.
class _SaveLocationNameDialog extends StatefulWidget {
  final IdentifyConfig current;
  const _SaveLocationNameDialog({required this.current});

  @override
  State<_SaveLocationNameDialog> createState() =>
      _SaveLocationNameDialogState();
}

class _SaveLocationNameDialogState extends State<_SaveLocationNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final coords =
        '${widget.current.latitude.toStringAsFixed(4)}, '
        '${widget.current.longitude.toStringAsFixed(4)}';
    return AlertDialog(
      title: const Text('Save location'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(coords),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              onFieldSubmitted: (_) => _submit(),
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
