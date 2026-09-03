# Implementation Plan: `auto_upgrade` Package (Option A) + Sky Overhead Integration

Companion to `docs/auto-upgrade.md` (the design document). This plan covers
**Option A — notify and open** only: the update check lives in a standalone,
reusable package, and the consuming app opens the GitHub release page in the
browser on user approval. No APK download, no install permission.

## Goal

A standalone, reusable Dart/Flutter package — `auto_upgrade` — that checks a
GitHub repository's Releases for a newer version of the running app and reports
the result. Option A only: the consuming app decides how to notify the user
and, on approval, opens the release page in the browser via `url_launcher`.
**No new app permissions, no `path_provider`/`permission_handler`/`open_filex`,
no `REQUEST_INSTALL_PACKAGES`.**

## Scope

### In scope

1. New standalone repo/package `auto_upgrade` (developed at `~/git/auto_upgrade`,
   published to `etnt/auto_upgrade`).
2. Sky Overhead integration: provider wiring, startup check hook, acknowledgment
   dialog, widget tests.
3. This plan document.

### Out of scope

- **Option B entirely** (`ApkInstaller`, manifest/FileProvider setup) —
  deliberately absent; the design doc's `apk_installer.dart` is not created.
  The package API leaves room for it later.
- **iOS install** — irrelevant for Option A anyway; the check itself is
  platform-neutral.
- Forced updates, background polling, per-ABI selection, "skip this version".

## Deliverable 1: the `auto_upgrade` package

### Package layout

```
auto_upgrade/
  pubspec.yaml               # flutter package; deps: http, shared_preferences
  analysis_options.yaml      # package:flutter_lints, matching Sky Overhead
  lib/
    auto_upgrade.dart        # barrel + public API docs
    src/
      version_compare.dart   # pure function, zero imports beyond dart:core
      release_check.dart     # UpdateInfo, UpdateCheckResult, ReleaseChecker
      update_throttle.dart   # UpdateCheckStore interface + InMemoryUpdateCheckStore
      shared_prefs_store.dart# SharedPrefsUpdateCheckStore (only plugin-touching file)
  test/
    version_compare_test.dart
    release_check_test.dart
    update_throttle_test.dart
  README.md                  # usage for any Flutter app + test recipe
```

**Deviation from the design doc:** the doc's API sketch exposes
`UpdateInfo.apkUrl` (Option B). For Option A, `UpdateInfo` carries
`releasePageUrl` instead (the release's `html_url`, falling back to
`https://github.com/{owner}/{repo}/releases/latest`). No `ApkInstaller`, no
Android manifest requirements. `apkUrl` can be added later without breaking
Option-A consumers (additive change).

### Public API

```dart
class UpdateInfo {
  final String latestVersion;   // tag with leading 'v' stripped, e.g. "1.2.0"
  final String currentVersion;
  final String releasePageUrl;  // opened by the app with url_launcher (Option A)
  final String? releaseNotes;   // release body, if any
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}
class UpdateAvailable extends UpdateCheckResult { final UpdateInfo info; }
class UpToDate extends UpdateCheckResult {}
class CheckSkipped extends UpdateCheckResult {}   // throttle short-circuit or 'dev'
                                                  // build — distinct from UpToDate so
                                                  // tests/UI can tell "checked,
                                                  // nothing" from "didn't check"
class CheckError extends UpdateCheckResult { final Object cause; }

class ReleaseChecker {
  ReleaseChecker({
    required String owner,
    required String repo,
    required String currentVersion,
    http.Client? httpClient,                       // injected; defaults to http.Client()
    UpdateCheckStore? checkStore,                  // null = no throttling
    Duration checkInterval = const Duration(hours: 24),
    DateTime Function()? now,                      // injected clock for tests
  });

  /// Never throws. GETs .../releases/latest with these headers:
  ///   Accept: application/vnd.github+json
  ///   User-Agent: auto_upgrade (<owner>/<repo>)   <-- REQUIRED by the GitHub API
  /// The GitHub REST API rejects requests without a User-Agent with 403; because
  /// this checker swallows errors as CheckError, a missing UA would make updates
  /// silently never appear. Always send it.
  Future<UpdateCheckResult> check();
}

/// compareVersions(a, b) -> int; stripVersionTag('v1.2.0+3') -> '1.2.0'
```

### Behaviour details

- **Skip conditions** (return `CheckSkipped`, no HTTP): `currentVersion == 'dev'`;
  or `checkStore` says the last successful check is less than `checkInterval` ago.
- **Version compare** (pure): strip one leading `v`; ignore `+build`; numeric
  `major.minor.patch`, missing components = 0; an unparseable *tag* → the checker
  maps it to `CheckError` (never silently "older"). An unparseable *current*
  version (anything other than the `dev` sentinel) is likewise treated as
  `CheckError`, never a spurious `UpdateAvailable`.
- **Required GitHub header**: every request sends a `User-Agent` header (the
  GitHub REST API returns 403 without one). Set e.g.
  `User-Agent: auto_upgrade (<owner>/<repo>)` alongside
  `Accept: application/vnd.github+json`.
- **Asset selection is irrelevant for Option A** (we open the release page, not
  an asset), so the `apkAssetName` matching logic from the design doc is deferred
  to the Option-B follow-up. This simplifies v1: no asset parsing at all.
- **Throttle only on success**: the timestamp is recorded only after a successful
  API round-trip that yields `UpdateAvailable` or `UpToDate` — a `CheckError`
  (offline/rate-limited) does **not** push the next check out by a full interval.
  Note the timestamp is stamped at *check* time, not at *prompt* time: a launch
  killed before the post-frame dialog still counts as checked (acceptable).
- **`/releases/latest` excludes drafts and pre-releases**: this is the desired
  behaviour (only promote finished, non-prerelease builds), but it means a
  release marked "pre-release" is invisible to the checker — worth remembering
  when cutting releases.
- **Store interface**: `Future<DateTime?> lastCheckAt(); Future<void> markChecked(DateTime when);`
  — `InMemoryUpdateCheckStore` for tests, `SharedPrefsUpdateCheckStore`
  (key `auto_upgrade.last_check`, millisecondsSinceEpoch) for apps.

### Package tests

- `version_compare`: equal, older/newer per component, `v` prefix, `+build`
  suffix, two-component (`1.2` == `1.2.0`), unparseable.
- `ReleaseChecker` with a fake `http.Client` (hand-rolled,
  `FakeTransport`-style, recording URL/headers): newer tag → `UpdateAvailable`
  with correct `releasePageUrl`; equal tag → `UpToDate`; older tag → `UpToDate`;
  403/500/exception → `CheckError`; malformed `tag_name` → `CheckError`;
  malformed non-`dev` `currentVersion` → `CheckError`; `User-Agent` header sent
  on the request; `dev` currentVersion → `CheckSkipped` with zero HTTP calls;
  throttle: second `check()` within interval → `CheckSkipped`, zero HTTP calls;
  throttle after error → next check still hits the network; injected clock
  honoured.
- `SharedPrefsUpdateCheckStore`: round-trip using
  `SharedPreferences.setMockInitialValues` (the one test file needing
  `TestWidgetsFlutterBinding`).


## Deliverable 2: Sky Overhead integration (thin)

1. **Dependency**: add to `pubspec.yaml` first as a local
   `path: ../auto_upgrade` dependency for development; after the package is
   pushed to `etnt/auto_upgrade`, switch to the `git:` dependency from the
   design doc. (`url_launcher` is already a dependency — nothing else to add.)
2. **`lib/src/data/update_service.dart`** — `releaseCheckerProvider`
   (`Provider<ReleaseChecker>`), defaulting to `checkStore: null`; `main.dart`
   overrides it (mirroring the three existing overrides) with a prefs-backed
   `SharedPrefsUpdateCheckStore` and `owner: 'etnt', repo: 'skyoverhead',
   currentVersion: appVersion`.
3. **`lib/src/ui/update_prompt.dart`** —
   `maybeShowUpdateDialog(context, ref, {required ReleaseChecker checker,
   required Future<void> Function(UpdateInfo) onUpdate})`:
   - calls `checker.check()` once, then **guards `context.mounted`** before
     touching `context` (the check is `await`ed across an async gap and the
     hosting widget may have been disposed; without the guard `flutter analyze`
     flags `use_build_context_synchronously` and a dialog on a dead widget
     throws);
   - `UpdateAvailable` → Material dialog: "**Update available** — Version X is
     available (you have Y)" + release-notes snippet if present +
     **Later** / **Update now**;
   - **Update now** → the injected `onUpdate(info)`. The default app strategy
     (defined at the home-screen call site, *not* in the package) does
     `launchUrl(Uri.parse(info.releasePageUrl), mode: LaunchMode.externalApplication)`
     — note `releasePageUrl` is a `String`, so it must be `Uri.parse`d, and the
     `false`/throw result of `launchUrl` should be handled (silent is fine);
   - `UpToDate` / `CheckSkipped` / `CheckError` → nothing, silently.
   - The injected `onUpdate` callback keeps the UI testable and the strategy
     (browser-open) out of the package.
4. **`lib/src/ui/home_screen.dart`** — fire-and-forget check in `initState` +
   one-frame `addPostFrameCallback` (dialog only after the first frame),
   guarded so it can't run twice, and a `mounted` check before showing the
   dialog (the check is async and the state may be disposed by the time it
   resolves).
5. **AndroidManifest**: the existing `<queries>` already declares an
   `ACTION_VIEW` + `scheme="https"` intent (added for the web-search link), so
   Option A needs **no manifest change** — just confirm it's still present. No
   new permission.

### Sky Overhead tests (existing conventions)

- `test/update_prompt_test.dart` (widget test): pump a harness with an
  overridden `releaseCheckerProvider` / injected fake result —
  `UpdateAvailable` shows the dialog; "Later" pops without launching;
  "Update now" invokes the fake strategy with the right `UpdateInfo`;
  `UpToDate`/`CheckSkipped`/`CheckError` show nothing.
- Reuse a small fake `http.Client` in `test/support/` if the package fake is
  useful at app level too.


## Execution order

1. Write `docs/auto-upgrade-implementation-plan.md` (this document).
2. Scaffold `~/git/auto_upgrade` package (pubspec, lints, README stub).
3. `version_compare.dart` + tests → green (`dart test`).
4. `release_check.dart` + `update_throttle.dart` + tests → green.
5. `shared_prefs_store.dart` + its test; barrel file; README with copy-paste
   usage for other apps.
6. Init git, push to `etnt/auto_upgrade` (needs the GitHub repo created; if
   unavailable at that moment, ship with `path:` temporarily and note it).
7. Sky Overhead: pubspec dep → provider + `main.dart` override →
   `update_prompt.dart` → `home_screen.dart` hook → manifest check.
8. `flutter analyze` + `flutter test` in both repos; manual smoke on an Android
   emulator optional (dialog suppressed for `dev` builds, so verify with
   `--dart-define=APP_VERSION=1.0.0`).

## Risks

- **`git:` dependency on an unpublished repo** — requires the
  `etnt/auto_upgrade` GitHub repo to exist and be **public** (dependency
  resolution happens at build time only, but a private repo needs auth on every
  machine/CI that builds the app).
- **Anonymous API rate limits** — mitigated by the 24 h throttle; errors are
  silent anyway.
- **Dialog UX timing** — showing a dialog on app start could collide with the
  first-frame UI; mitigated by the post-frame callback and the existing dialog
  patterns (`showSettingsDialog`).

## Acceptance criteria

- `auto_upgrade` is a self-contained package: `dart analyze` clean, all tests
  green, zero Flutter-widget dependencies in the core (only
  `shared_prefs_store.dart` touches the plugin world).
- A second Flutter app could consume it by adding the `git:` dependency and
  ~15 lines of wiring (documented in the package README).
- Sky Overhead: dialog at most once per interval, only on a genuinely newer
  release, never on error/offline/`dev`; nothing opens unless the user taps
  **Update now**.
- Full existing test suite still green.

## Follow-up (future, not this iteration)

- Option B (in-app download + install) as an additional class in the package,
  with the manifest/FileProvider setup from the design doc.
- Per-ABI APK selection (match the device's ABI for smaller downloads).
- Optional "skip this version" choice stored in preferences.
- Publishing the package to pub.dev for versioned consumption instead of `git:`.
- Release-notes rendering (Markdown) in the update dialog.
