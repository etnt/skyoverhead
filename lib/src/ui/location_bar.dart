/// The observer-location row: current coordinates, a "use my location"
/// action, and a manual-entry fallback.
///
/// No new buttons: saving and switching between saved locations is layered
/// onto the two existing icon buttons —
///
/// * GPS button: tap = get current location; **long-press** = save the current
///   position under a name.
/// * Edit button: tap = manual entry (with a saved-locations dropdown and an
///   optional name to save the entry as); **long-press** = manage saved
///   locations (apply one by tapping, or delete it).
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
          tooltip: 'Enter location (hold for saved locations)',
          onPressed: () => _editLocation(context, ref, config),
          onLongPress: () => _manageLocations(context, ref),
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

  /// Tap on the edit button: manual entry, optionally saving a named entry.
  Future<void> _editLocation(
    BuildContext context,
    WidgetRef ref,
    IdentifyConfig current,
  ) async {
    final result = await showDialog<_ManualLocationResult>(
      context: context,
      builder: (_) => _ManualLocationDialog(current: current),
    );
    if (result == null) return;
    ref.read(identifyConfigProvider.notifier).state = result.config;
    if (result.saveAsName != null) {
      await ref
          .read(savedLocationsProvider.notifier)
          .save(result.saveAsName!, result.config);
    } else {
      // A plain manual entry matches the active label only when its
      // coordinates exactly equal a saved location (e.g. picked from the
      // dropdown without typing a name).
      ref
          .read(savedLocationsProvider.notifier)
          .syncActiveForConfig(result.config);
    }
  }

  /// Long-press on the edit button: manage saved locations.
  Future<void> _manageLocations(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _SavedLocationsDialog(),
    );
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

class _ManualLocationDialog extends ConsumerStatefulWidget {
  final IdentifyConfig current;
  const _ManualLocationDialog({required this.current});

  @override
  ConsumerState<_ManualLocationDialog> createState() =>
      _ManualLocationDialogState();
}

class _ManualLocationDialogState extends ConsumerState<_ManualLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _name;

  /// Elevation to apply on submit. Seeded from the current config and updated
  /// when a saved location is picked from the dropdown (which has no field).
  late double _elevationM;

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(text: widget.current.latitude.toString());
    _lon = TextEditingController(text: widget.current.longitude.toString());
    _name = TextEditingController();
    _elevationM = widget.current.elevationM;
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final config = widget.current.copyWith(
      latitude: double.parse(_lat.text.trim()),
      longitude: double.parse(_lon.text.trim()),
      elevationM: _elevationM,
    );
    final name = _name.text.trim();
    Navigator.of(
      context,
    ).pop(_ManualLocationResult(config, name.isEmpty ? null : name));
  }

  @override
  Widget build(BuildContext context) {
    const numeric = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    final inputFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
    ];
    final saved = ref.watch(savedLocationsProvider);

    return AlertDialog(
      title: const Text('Enter location'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saved.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Saved locations'),
                hint: const Text('Pick a saved location'),
                items: [
                  for (final entry in saved)
                    DropdownMenuItem(value: entry.id, child: Text(entry.name)),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final entry = saved.firstWhere((e) => e.id == id);
                  setState(() {
                    _lat.text = entry.latitude.toString();
                    _lon.text = entry.longitude.toString();
                    _elevationM = entry.elevationM;
                  });
                },
              ),
            if (saved.isNotEmpty) const SizedBox(height: 8),
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
                helperText: 'Fill in to also save this location',
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

/// Long-press on the edit button: list saved locations; tapping an entry
/// applies it, the trailing icon deletes it.
class _SavedLocationsDialog extends ConsumerWidget {
  const _SavedLocationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedLocationsProvider);

    return AlertDialog(
      title: const Text('Saved locations'),
      content: saved.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Text(
                'No saved locations yet.\n\n'
                'Save one by holding the GPS button, or by filling in a name '
                'when entering a location.',
              ),
            )
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: saved.length,
                itemBuilder: (context, index) {
                  final entry = saved[index];
                  final coords =
                      '${entry.latitude.toStringAsFixed(4)}, '
                      '${entry.longitude.toStringAsFixed(4)}';
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(entry.name),
                    subtitle: Text(coords),
                    onTap: () {
                      ref.read(savedLocationsProvider.notifier).apply(entry);
                      Navigator.of(context).pop();
                    },
                    trailing: IconButton(
                      tooltip: 'Delete ${entry.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(savedLocationsProvider.notifier)
                          .delete(entry.id),
                    ),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
