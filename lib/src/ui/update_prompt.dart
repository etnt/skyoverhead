/// The startup update-check dialog (Option A: notify and open).
///
/// Runs one [ReleaseChecker.check] and, when a genuinely newer release
/// exists, shows a Material dialog. Nothing else in the app needs to know
/// about the check: `UpToDate`, `CheckSkipped`, and `CheckError` are all
/// silent. The **Update now** action delegates to the injected [onUpdate]
/// strategy — defined at the call site, not here — which keeps this function
/// testable and the browser-open behaviour out of the package.
library;

import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter/material.dart';

/// How much of the release-notes body to show in the dialog before
/// truncating.
const int kMaxReleaseNotesLength = 300;

/// Checks [checker] and shows the update dialog if a newer release exists.
///
/// The check is awaited across an async gap, so the hosting widget may have
/// been disposed by the time it resolves; [context.mounted] is guarded
/// before any dialog is shown. Fire-and-forget safe: this function never
/// throws.
Future<void> maybeShowUpdateDialog(
  BuildContext context, {
  required ReleaseChecker checker,
  required Future<void> Function(UpdateInfo info) onUpdate,
}) async {
  final result = await checker.check();
  if (!context.mounted) return;

  switch (result) {
    case UpdateAvailable(:final info):
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version ${info.latestVersion} is available '
                '(you have ${info.currentVersion}).',
              ),
              if (info.releaseNotes != null &&
                  info.releaseNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _truncate(info.releaseNotes!),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onUpdate(info);
              },
              child: const Text('Update now'),
            ),
          ],
        ),
      );
    case UpToDate():
    case CheckSkipped():
    case CheckError():
      break;
  }
}

/// Truncates release notes to [kMaxReleaseNotesLength] characters on a word
/// boundary, appending an ellipsis when cut.
String _truncate(String notes) {
  final trimmed = notes.trim();
  if (trimmed.length <= kMaxReleaseNotesLength) return trimmed;
  return '${trimmed.substring(0, kMaxReleaseNotesLength).trimRight()}…';
}
