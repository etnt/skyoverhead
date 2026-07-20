# Implementation Plan: Downloadable Android Build via GitHub Actions

## Goal

Produce a downloadable, installable **Android APK** for Sky Overhead that is
built automatically by **GitHub Actions** and published as an asset on a
**GitHub Release**. Users download the `.apk` from the repo's Releases page and
sideload it onto their Android device — no Google Play account required.

## Scope

### In scope
- Automated release build of a signed-with-debug-key release APK.
- Split-per-ABI APKs (smaller downloads) plus a universal APK (works anywhere).
- Run the existing unit/widget test suite as a gate before building.
- Publish artifacts to a GitHub Release, triggered by pushing a version tag.
- Documentation for end users on how to install the APK.

### Out of scope (and why)
- **iPhone / iOS distribution** — Apple does not allow installing unsigned
  `.ipa` files. Distribution outside the App Store is not possible without a
  paid Apple Developer account and per-device provisioning, so it is explicitly
  excluded from this plan.
- **Google Play publishing** — separate track (needs a Play developer account,
  upload keystore, and an app bundle). Can be added later.
- **Production release signing** — this plan sideloads with the existing debug
  signing config. A dedicated upload/release keystore is a follow-up if/when the
  app goes to a store.

## Current state (verified)

- Standard Flutter app with `android/` and `ios/` already scaffolded.
- Real application ID already set: `com.skyoverhead.skyoverhead`
  (`android/app/build.gradle.kts`) — no `com.example` placeholder to fix.
- Release build currently signs with **debug keys**
  (`signingConfigs.getByName("debug")`) — acceptable for sideload distribution.
- Version source of truth: `version: 1.0.0+1` in `pubspec.yaml`
  (`versionName`/`versionCode` are derived from it via the Flutter Gradle plugin).
- Dart SDK constraint: `^3.12.0`. Tests live under `test/` and
  `integration_test/`.
- No existing workflows under `.github/workflows/`.

## Deliverables

1. `.github/workflows/release.yml` — the CI workflow.
2. A short **Downloads / Install** section added to `README.md`.
3. This plan document.

## Design

### Trigger
- On push of a tag matching `v*` (e.g. `v1.0.0`).
- Optional `workflow_dispatch` for manual runs during testing.

### Runner & tooling
- Runner: `ubuntu-latest` (Android builds do not need macOS).
- Java: Temurin JDK 17 (matches `sourceCompatibility`/`jvmTarget` = 17).
- Flutter: `subosito/flutter-action` on the `stable` channel, with build caching.

### Steps
1. Checkout the repository.
2. Set up JDK 17.
3. Set up Flutter (stable) with pub cache enabled.
4. `flutter pub get`.
5. `flutter analyze` (fail on issues).
6. `flutter test` (unit + widget tests — the gate).
7. `flutter build apk --release --split-per-abi`.
8. `flutter build apk --release` (universal APK).
9. Upload the resulting APKs from
   `build/app/outputs/flutter-apk/` to a GitHub Release using
   `softprops/action-gh-release`, with `GITHUB_TOKEN` and
   `contents: write` permission.

### Artifacts produced
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`
- `app-release.apk` (universal)

## Versioning & release process (for the maintainer)

1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`).
2. Commit the change.
3. Create and push a matching tag:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
4. The workflow builds, tests, and creates the GitHub Release with APKs attached.

## End-user install steps (for the README)

1. Open the repo's **Releases** page and download `app-release.apk`
   (universal) — or the ABI-specific APK matching the device.
2. On the phone, enable **Install unknown apps** for the browser/file manager.
3. Open the downloaded APK and confirm installation.
4. Launch the app and **allow location permission** when prompted.

## Risks & considerations

- **Debug signing key rotation**: the debug keystore is generated per build
  environment, so successive releases may be signed with different debug keys.
  Users may need to uninstall before updating. Acceptable for now; a stable
  release keystore stored as a GitHub secret is the follow-up fix.
- **Unknown-sources friction**: sideloading requires users to allow installs
  from unknown sources — documented in the install steps.
- **API rate limits**: sideloaded builds hit the same anonymous OpenSky/ADSBDB
  limits as any other build; no change from local runs.
- **APK size**: `--split-per-abi` keeps per-device downloads small; the
  universal APK is the safe fallback.

## Acceptance criteria

- Pushing a `v*` tag triggers the workflow and it completes green.
- Tests run and gate the build (a failing test blocks the release).
- A GitHub Release is created for the tag with the four APKs attached.
- The universal APK installs and launches on a physical Android device and can
  request location and identify overhead aircraft.

## Follow-up (future, not this iteration)

- Dedicated release keystore via GitHub secrets for stable update signing.
- Google Play internal-testing track (app bundle + Play signing).
- Optional Windows/Linux desktop artifacts (`flutter create --platforms=...`).
