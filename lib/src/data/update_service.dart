/// Riverpod wiring for the GitHub Releases update check (Option A).
///
/// [releaseCheckerProvider] defaults to a checker with no throttling store,
/// so an app that is never overridden checks on every launch. `main()`
/// overrides it — mirroring the other store providers — with a
/// `SharedPrefsUpdateCheckStore`-backed checker so the network call happens at
/// most once per interval. In `dev` builds (`appVersion == 'dev'`) the check
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
