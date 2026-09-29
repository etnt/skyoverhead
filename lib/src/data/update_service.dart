/// Riverpod wiring for the GitHub Releases update check (Option A).
///
/// [releaseCheckerProvider] has no persistent throttle, so each app launch
/// checks GitHub once. In `dev` builds (`appVersion == 'dev'`) the check
/// short-circuits without any HTTP.
library;

import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_version.dart';

/// Supplies the release checker. Override in `main()` with a prefs-backed
/// store; tests override with a checker returning a fake result.
final releaseCheckerProvider = Provider<ReleaseChecker>((ref) {
  return ReleaseChecker(
    owner: 'etnt',
    repo: 'skyoverhead',
    currentVersion: appVersion,
  );
});
