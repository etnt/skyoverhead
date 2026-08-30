# Design: In-App Update Check and Auto-Upgrade via GitHub Releases

## Goal

Let Sky Overhead check for newer releases of itself and, with the **user's
explicit acknowledgment**, update the installed app directly from the
repository's **GitHub Releases** — no Google Play store involved. The update
logic lives in a **standalone, reusable package** so the same component can be
dropped into other Flutter apps.

Two variants of "update" are supported, chosen per app:

- **Option A — notify and open:** the app detects a newer release and, on
  approval, opens the release page in the browser for a manual download.
  Requires no new packages beyond `url_launcher` and no special Android
  permissions.
- **Option B — in-app download and install:** the app downloads the new APK
  itself and hands it to Android's package installer. Requires three extra
  packages and the `REQUEST_INSTALL_PACKAGES` permission.

Both variants are gated behind the same acknowledgment dialog: nothing is
downloaded or opened until the user says yes.

## Scope

### In scope

- The reusable package (`auto_upgrade`, its own repository, consumed via a
  `git:` dependency): release checking, version comparison, throttling, and
  both install strategies.
- The thin, app-specific integration in Sky Overhead: provider wiring, the
  acknowledgment dialog, and (for Option B) the Android manifest/FileProvider
  configuration.

### Out of scope (and why)

- **iOS** — same reasoning as `github-release-implementation-plan.md`: apps
  cannot be updated outside the App Store without a paid Apple Developer
  account. The package is Android-only for the install step; the check itself
  is platform-neutral.
- **Play Store publishing** — separate track, documented elsewhere.
- **Forced updates** — the update is always user-approved; there is no silent
  install and no blocking "you must update" wall in this iteration.
- **Automatic background polling** — the check runs on app start only
  (throttled); no push notifications or workmanager scheduling.

## Current state (verified)

- Releases are built by GitHub Actions (`.github/workflows/release.yml`) on
  `v*` tags and published with four APKs attached:
  `app-release.apk` (universal), plus `armeabi-v7a`, `arm64-v8a`, and
  `x86_64` ABI-specific builds.
- Release APKs are signed with a **persistent keystore**, so a new APK
  installs over an existing one without uninstalling.
- Version source of truth: `version: 1.0.0+1` in `pubspec.yaml`.
  The AppBar already displays the build-time-injected `appVersion`
  (`lib/src/config/app_version.dart`, `--dart-define=APP_VERSION`).
- Repository: `etnt/skyoverhead`.

## The `auto_upgrade` package

Standalone repository (e.g. `etnt/auto_upgrade`), consumed as:

```yaml
dependencies:
  auto_upgrade:
    git:
      url: https://github.com/etnt/auto_upgrade.git
```

### Design principles

- **Pure-Dart core.** The check and version-comparison layers use only
  `dart:` + `http`, no Flutter plugins. The HTTP client is injected, so any
  consumer app can test the checker with plain fakes (mirroring Sky
  Overhead's `FakeTransport` pattern).
- **No UI in the package.** The package reports *that* an update exists and
  *where*; the consuming app decides how to ask the user. This keeps the
  package testable and unopinionated about design systems.
- **Android-only install step** is isolated in its own class so apps on other
  platforms (or apps preferring Option A) never load it.

### Structure

```
auto_upgrade/
  lib/
    src/
      release_check.dart     # GitHub Releases API client
      version_compare.dart   # tag/version comparison
      update_throttle.dart   # check throttling (pluggable persistence)
      apk_installer.dart     # Android download + install (Option B)
    auto_upgrade.dart        # public API + barrel file
  test/                      # pure-Dart unit tests with a fake http.Client
  README.md                  # usage, plus the Android manifest/FileProvider
                             # setup needed for the install strategy
```

### Public API sketch

```dart
/// Immutable description of an available update.
class UpdateInfo {
  final String latestVersion;   // e.g. "1.2.0" (tag, leading "v" stripped)
  final String currentVersion;  // e.g. "1.0.1"
  final String apkUrl;          // browser_download_url of the chosen APK
  final String? releaseNotes;   // release body, if any
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  final UpdateInfo info;
}

class UpToDate extends UpdateCheckResult {}
class CheckError extends UpdateCheckResult {
  final Object cause;
}

/// Throttled GitHub Releases update checker.
class ReleaseChecker {
  ReleaseChecker({
    required String owner,
    required String repo,
    required String currentVersion,
    http.Client? httpClient,          // defaults to http.Client()
    UpdateCheckStore? checkStore,     // throttling persistence; null = no throttle
    Duration checkInterval = const Duration(hours: 24),
    String apkAssetName = 'app-release.apk', // exact asset name to pick
  });

  /// Returns the latest release info, or a result explaining why there is
  /// nothing to do. Never throws: network/API failures come back as
  /// [CheckError] so callers can stay silent.
  Future<UpdateCheckResult> check();
}

/// Android-only (Option B). Download the APK and open the system installer.
class ApkInstaller {
  const ApkInstaller();
  Future<InstallResult> downloadAndInstall(String apkUrl);
}
```

### Technical details

**Endpoint.** The check hits the GitHub REST API, not the HTML releases page:

```
https://api.github.com/repos/{owner}/{repo}/releases/latest
```

The response's `tag_name` (e.g. `v1.2.0`) and `assets[]` (each with `name`
and `browser_download_url`) are what the checker consumes.

**Asset selection.** Sky Overhead attaches four APKs per release. The checker
picks the asset whose name **exactly matches** `apkAssetName` (default
`app-release.apk`, the universal build) — never "the first `.apk`", which is
arbitrary. Apps that want per-ABI downloads can pass a custom resolver later;
out of scope for v1.

**Version comparison.** A single pure function:

- Strip exactly one leading `v` from the tag (`v1.2.0` → `1.2.0`).
- Ignore anything after `+` (build numbers) — `1.0.1+3` compares as `1.0.1`.
- Compare `major.minor.patch` numerically, component by component; treat
  missing components as 0 (`1.2` == `1.2.0`).
- Unparseable tags are reported as an error, not silently treated as older.

**Throttling.** The GitHub API allows 60 unauthenticated requests per hour
per IP. The checker therefore records the last successful check timestamp
via a pluggable `UpdateCheckStore` (a `SharedPreferences` implementation
ships with the package) and short-circuits without a network call until the
interval (default 24 h) has elapsed. Apps pass `null` to check on every
launch. Checks are also skipped entirely when the injected `currentVersion`
is `dev` (local/debug builds).

**Failure behaviour.** Any network or API problem returns `CheckError` and is
otherwise silent — a user offline or rate-limited must never see an error
dialog about updates.

### Android setup for the install strategy (Option B)

Documented once in the package README; consuming apps copy it in:

1. New packages: `path_provider`, `permission_handler`, `open_filex`.
2. `android/app/src/main/AndroidManifest.xml`, outside `<application>`:

   ```xml
   <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
   ```

   (`INTERNET` is already required by essentially every app.)
3. A `FileProvider` inside `<application>` so `open_filex` can share the
   downloaded APK with the system installer:

   ```xml
   <provider
       android:name="androidx.core.content.FileProvider"
       android:authorities="${applicationId}.fileprovider"
       android:exported="false"
       android:grantUriPermissions="true">
       <meta-data
           android:name="android.support.FILE_PROVIDER_PATHS"
           android:resource="@xml/file_paths" />
   </provider>
   ```

4. `android/app/src/main/res/xml/file_paths.xml`:

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <paths xmlns:android="http://schemas.android.com">
       <cache-path name="cache" path="." />
       <external-cache-path name="external_cache" path="." />
   </paths>
   ```

At install time the installer requests the "install unknown apps" system
setting via `permission_handler` (`Permission.requestInstallPackages`),
downloads the APK to the temporary directory, and calls `OpenFilex.open` to
launch Android's installer. The user then confirms (or cancels) in the system
UI — the app itself never installs anything silently.

## Integration in Sky Overhead

Thin by design; only this section is app-specific.

### Wiring

```dart
// lib/src/data/update_service.dart
final releaseCheckerProvider = Provider<ReleaseChecker>((ref) {
  return ReleaseChecker(
    owner: 'etnt',
    repo: 'skyoverhead',
    currentVersion: appVersion, // 'dev' in debug builds -> checks skipped
    checkStore: SharedPrefsUpdateCheckStore(prefs),
  );
});
```

### Acknowledgment flow (the only UI)

On app start, the home screen fires the check; when the result is
`UpdateAvailable`, it shows a dialog:

> **Update available** — Version 1.2.0 is available (you have 1.0.1).
> [Later]  [Update now]

- **Update now** → runs the configured strategy (Option A: `url_launcher`
  opens `https://github.com/etnt/skyoverhead/releases/latest`; Option B:
  `ApkInstaller.downloadAndInstall`).
- **Later** → dismisses; the throttle means the user is not asked again for
  the configured interval.
- Any other result (`UpToDate`, `CheckError`) shows nothing.

### Package dependency

```yaml
dependencies:
  auto_upgrade:
    git:
      url: https://github.com/etnt/auto_upgrade.git
```

Option A needs nothing else. Option B additionally adds `path_provider`,
`permission_handler`, and `open_filex` to the app. Keeping them in the app
(declared in the package README as required-for-Option-B) keeps the package's
own dependency footprint small for Option-A-only consumers.

## Test plan

- **Package, pure Dart** (`auto_upgrade/test/`):
  - Version comparison: equal versions, older/newer per component, `v`-prefix,
    `+build` suffixes, two-component tags, unparseable tags.
  - `ReleaseChecker` against a fake `http.Client`: newer tag →
    `UpdateAvailable` with the exact `app-release.apk` asset URL; equal tag →
    `UpToDate`; API error/non-200 → `CheckError`; missing APK asset →
    `CheckError`; throttle: second `check()` inside the interval performs no
    HTTP call; `dev` version performs no HTTP call.
  - `ApkInstaller` is a thin plugin wrapper; covered minimally or by
    integration testing on a device.
- **Sky Overhead** (existing suite conventions):
  - Widget test: `UpdateAvailable` result shows the dialog; "Later" dismisses
    without any install call; "Update now" invokes the chosen strategy
    (faked); `UpToDate`/`CheckError` show nothing.

## Risks & considerations

- **API rate limits** — mitigated by throttling (one request per install per
  day by default). Even a large number of installs stays far below the
  anonymous limit.
- **Unknown-sources friction** (Option B) — sideloaded installs already
  require "install unknown apps" for the browser; the system installer will
  additionally prompt for the app itself on first update. This is Android's
  normal flow for self-updating sideloaded apps.
- **Signing** — safe today because releases use a persistent keystore. If the
  signing key ever changes, in-place updates stop working (Android refuses
  the install); users would need to reinstall manually.
- **Releases without APKs** — a tag pushed before the workflow completes
  leaves a release with no assets; the checker treats this as `CheckError`
  (silently) rather than offering a dead link.
- **Dropped or changed asset names** — the exact-name match means renaming
  `app-release.apk` in the workflow would break the updater; the workflow and
  package default must stay in sync.

## Acceptance criteria

- The `auto_upgrade` package builds standalone, its pure-Dart tests pass, and
  it is consumable from any app via a `git:` dependency.
- Sky Overhead shows the update dialog at most once per throttle interval,
  only when a genuinely newer release exists, and never when offline, when
  rate-limited, or in `dev` builds.
- Nothing is downloaded or opened unless the user taps **Update now**.
- (Option B) On a physical Android device, approving the dialog downloads the
  universal APK and presents Android's installer; the new version installs
  over the old one thanks to the persistent release keystore.

## Follow-up (future, not this iteration)

- Per-ABI APK selection (match the device's ABI for smaller downloads).
- Optional "skip this version" choice stored in preferences.
- Publishing the package to pub.dev for versioned consumption instead of
  `git:`.
- Release-notes rendering (Markdown) in the update dialog.
