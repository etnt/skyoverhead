---
goal: Implement an installable Sky Overhead PWA without breaking Android
version: 1.0
date_created: 2026-09-30
last_updated: 2026-09-30
owner: Sky Overhead maintainers
status: In progress
tags:
  - feature
  - flutter
  - web
  - pwa
---

# Introduction

![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)

This plan adds a production PWA for Sky Overhead. The app will run on Flutter
Web, support installation from supported browsers, use HTTPS GPS, preserve
browser storage behavior, and route browser API requests through a restricted
Cloudflare Worker. Android will keep its current native code paths and direct
API requests.

## 1. Requirements & Constraints

- **REQ-001**: Build an installable PWA for Chrome and iOS Safari. Serve it over
  HTTPS from GitHub Pages.
- **REQ-002**: Keep the Android app working. Preserve Android GPS settings,
  direct OpenSky and ADSBDB requests, Collector storage, and release APK builds.
- **REQ-003**: Make browser requests to OpenSky and ADSBDB succeed through a
  Cloudflare Worker. Do not use a public, unrestricted CORS proxy.
- **REQ-004**: Keep manual coordinate entry available when browser GPS is
  denied or unavailable. Browser GPS requires HTTPS and user permission.
- **REQ-005**: Keep `shared_preferences` for Collector data. Browser storage can
  be cleared by the user or browser, so document this behavior.
- **SEC-001**: The Worker must allow only the app's configured origin and the
  fixed OpenSky and ADSBDB endpoints. It must not accept arbitrary target URLs.
- **CON-001**: Use GitHub Pages project-site paths. Build Flutter Web with the
  repository path as `--base-href`.
- **CON-002**: Default to `https://etnt.github.io` and the supplied Worker URL.
  Allow GitHub Actions variables to override either value. Store the Cloudflare
  token and account ID as GitHub Actions secrets.
- **CON-003**: Remove web-incompatible `dart:io` imports from shared Flutter
  code. Preserve native TLS, DNS, and connection error classification.
- **GUD-001**: Reuse current packages and architecture. Add no Flutter package
  unless browser compilation proves an existing package cannot work.
- **GUD-002**: Do not add offline data access or service-worker caching. This
  plan covers installation and online app behavior, not offline operation.
- **PAT-001**: Follow the injected `HttpTransport` pattern in
  `lib/src/data/http.dart` and fake transport pattern in
  `test/support/fake_transport.dart`.

## 2. Implementation Steps

### Implementation Phase 1: Make shared app code compile for the web

- **GOAL-001**: Support web compilation without changing Android runtime paths.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Web-safe transport and native error mapping. | ✅ | 2026-09-30 |
| TASK-002 | Use web-safe location platform checks. | ✅ | 2026-09-30 |
| TASK-003 | Build web and Android targets. | ✅ | 2026-09-30 |

TASK-001 details: Move `TransportErrorKind` and `TransportException` into
`lib/src/data/transport_exception.dart`, and re-export them from
`lib/src/data/http.dart` to preserve current imports. Add conditional classifier
files `lib/src/data/transport_error_classifier.dart`,
`lib/src/data/transport_error_classifier_io.dart`, and
`lib/src/data/transport_error_classifier_web.dart`. Update
`DefaultHttpTransport.get` in `lib/src/data/http.dart` to use the classifier.
Keep native TLS, DNS, connection, timeout, and response-size classifications.
Map browser transport failures to the existing stable error kinds.

TASK-002 details: Update `GeolocatorLocationService._locationSettings` in
`lib/src/data/location_service.dart` to use Flutter's `kIsWeb` and
`defaultTargetPlatform`. Use `AndroidSettings` with
`forceLocationManager: true` only when `!kIsWeb` and
`defaultTargetPlatform == TargetPlatform.android`. Use standard
`LocationSettings` on web and other platforms. Do not change the permission
flow or manual coordinate UI in `lib/src/ui/location_bar.dart`.

TASK-003 details: Run `flutter analyze lib test integration_test`,
`flutter test`, `flutter build web --release`, and `flutter build apk --debug`.
Resolve compilation failures in shared imports without changing Android
behavior or replacing existing services.

### Implementation Phase 2: Add a restricted browser API proxy

- **GOAL-002**: Route web API traffic through an owned Worker and keep native
  traffic direct.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Add restricted OpenSky and ADSBDB Worker. | ✅ | 2026-09-30 |
| TASK-005 | Route browser API requests through Worker. | ✅ | 2026-09-30 |
| TASK-006 | Test routes and preserve native requests. | ✅ | 2026-09-30 |

TASK-004 details: Add `cloudflare/opensky-proxy/wrangler.toml`,
`cloudflare/opensky-proxy/src/index.js`,
`cloudflare/opensky-proxy/test/index.test.js`, and
`cloudflare/opensky-proxy/package.json` with an `npm test` command. Set the
Worker name to `skyoverhead-api-proxy` and enable `workers_dev`. Map
`/opensky/api/states/all` only to `opensky-network.org`, and
`/adsbdb/v0/aircraft/{icao24}` only to `api.adsbdb.com`. Require six
hexadecimal characters for `{icao24}` and allow only the optional `callsign`
query parameter. Forward the request query and upstream response. Accept `GET`
and CORS preflight `OPTIONS` requests. Return `Access-Control-Allow-Origin`
only when the request origin matches the `PAGES_ORIGIN` Worker variable. Reject
unknown origins, methods, and paths.

TASK-005 details: Add `lib/src/config/web_config.dart` with the
`WEB_API_PROXY_BASE_URL` compile-time value. Add
`lib/src/data/web_proxy_transport.dart` to rewrite only the two known API
hosts to the matching Worker paths while preserving query parameters. Update
`AircraftService.networked` in `lib/src/data/aircraft_service.dart` to wrap
the default transport only when `kIsWeb`. Read the Worker URI from
`web_config.dart` inside the factory. Keep `aircraftServiceProvider` on its
current factory call and keep Android requests on their existing OpenSky and
ADSBDB hosts. If the local Worker URL is empty, keep direct browser requests
for local experiments. The production workflow must reject an empty URL.

TASK-006 details: Add transport tests in
`test/web_proxy_transport_test.dart` for both API routes, query preservation,
and unsupported hosts. Add Worker tests for the allowed routes, origin checks,
preflight responses, and rejection of unsupported paths. Confirm that
`OpenSkyClient.buildUrl` and `AdsbdbClient.buildUrl` still construct their
current upstream URLs. Run the existing client and service tests.

### Implementation Phase 3: Configure PWA branding and GitHub Pages

- **GOAL-003**: Publish the branded Flutter Web app at the correct HTTPS path.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-007 | Set PWA branding and install metadata. | ✅ | 2026-09-30 |
| TASK-008 | Add Worker and Pages deployment workflow. | ✅ | 2026-09-30 |
| TASK-009 | Document web setup and browser behavior. | ✅ | 2026-09-30 |

TASK-007 details: Update `web/index.html` and `web/manifest.json` to replace
Flutter template titles and descriptions with Sky Overhead metadata. Keep
standalone display mode. Replace template icons in `web/icons/` with branded
files based on `assets/icon/app_icon.png` and
`assets/icon/app_icon_foreground.png`.
Include the existing 192px and 512px manifest sizes, maskable icons, and an
Apple touch icon. Keep the manifest start URL and Flutter base URL compatible
with the GitHub Pages project path.

TASK-008 details: Add `.github/workflows/deploy-web.yml` with `push` and
`workflow_dispatch` triggers. Deploy on pushes to the default branch. Use
`cloudflare/wrangler-action@v4` to update the existing Worker from
`cloudflare/opensky-proxy`. Set `apiToken` and `accountId` from GitHub secrets.
Pass `PAGES_ORIGIN` to Wrangler, using `vars.PAGES_ORIGIN` or the default
`https://etnt.github.io`. Build Flutter Web with the repository path as
`--base-href`. Set `WEB_API_PROXY_URL` from the matching repository variable or
the supplied Worker URL. Pass it as
`--dart-define=WEB_API_PROXY_BASE_URL=${WEB_API_PROXY_URL}`. Deploy `build/web`
with GitHub Pages Actions. Do not expose Cloudflare secrets to pull requests.

TASK-009 details: Add `docs/cloudflare-worker-setup.md` with Cloudflare
account, Worker, token, Pages origin, and repository variable setup. Update
`README.md` with a link to the guide, the GitHub Pages URL pattern, PWA
installation steps for Chrome and iOS Safari, HTTPS GPS permission requirements,
manual coordinate fallback, Collector persistence, and the risk of browser data
removal. State that the app requires a network connection and does not provide
offline API access.

### Implementation Phase 4: Verify the web and Android user paths

- **GOAL-004**: Prove the published PWA works and Android release behavior stays
  intact.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-010 | Run analysis, tests, and platform builds. | ✅ | 2026-09-30 |
| TASK-011 | Smoke-test the deployed PWA in Chrome and iOS Safari. | | |
| TASK-012 | Smoke-test Android GPS, APIs, and Collector behavior. | | |

TASK-010 details: Run `flutter analyze lib test integration_test`,
`flutter test`, `flutter build web --release` with the production base href and
Worker URL, and `flutter build apk --debug`. Keep the existing
`.github/workflows/release.yml` Android release build and APK outputs unchanged.

TASK-011 details: Open the HTTPS Pages URL in Chrome. Confirm the page loads at
the repository path, the browser makes successful OpenSky and ADSBDB requests,
GPS permission returns a position, and manual coordinates still work. Enable
Collector mode, save a sighting and location, reload the page, and confirm the
saved data remains. Install the PWA from Chrome and confirm it opens in
standalone mode. On iOS Safari, add the page to the home screen and confirm that
it opens as a standalone web app.

TASK-012 details: Install the debug APK on an Android device or emulator.
Confirm GPS still uses the Android location manager, identification requests go
directly to OpenSky and ADSBDB, manual coordinates work, and Collector data
remains after an app restart. Run the existing Android release workflow before
merging the production deployment.

## 3. Alternatives

- **ALT-001**: Use a public `cors-anywhere` proxy. Rejected because the research
  notes rate limits and outages, and the app would depend on a shared service.
- **ALT-002**: Send browser requests directly to OpenSky. Rejected because the
  research records that OpenSky blocks the app's browser origin.
- **ALT-003**: Use Netlify Functions instead of Cloudflare Workers. Rejected
  because the project already uses GitHub and the research identifies Workers
  as the preferred owned proxy option.

## 4. Dependencies

- **DEP-001**: Flutter stable SDK and current dependencies in `pubspec.yaml`.
- **DEP-002**: Existing Worker at
  `https://skyoverhead-api-proxy.kruskakli.workers.dev`. Add a per-Worker
  `Workers Editor` API token and `CLOUDFLARE_ACCOUNT_ID` as GitHub secrets.
- **DEP-003**: GitHub Pages configured for GitHub Actions. Repository variables
  `PAGES_ORIGIN` and `WEB_API_PROXY_URL` are optional overrides.
- **DEP-004**: HTTPS from GitHub Pages for browser GPS and PWA installation.

## 5. Files

- **FILE-001**: `lib/src/data/http.dart` and new transport error classifier
  files. Keep web compilation and stable native error classification.
- **FILE-002**: `lib/src/data/location_service.dart`. Keep Android GPS settings
  and use a web-safe platform check.
- **FILE-003**: `lib/src/config/web_config.dart`,
  `lib/src/data/web_proxy_transport.dart`, and
  `lib/src/data/aircraft_service.dart`. Configure the web-only proxy path.
- **FILE-004**: `cloudflare/opensky-proxy/wrangler.toml`,
  `cloudflare/opensky-proxy/src/index.js`,
  `cloudflare/opensky-proxy/test/index.test.js`, and its `package.json`.
- **FILE-005**: `web/index.html`, `web/manifest.json`, and `web/icons/`. Set
  branded PWA and Apple installation metadata.
- **FILE-006**: `.github/workflows/deploy-web.yml`. Deploy the Worker and Pages
  app without changing Android release workflow behavior.
- **FILE-007**: `README.md`. Document PWA use and browser limitations.
- **FILE-008**: `test/web_proxy_transport_test.dart`,
  `test/transport_error_classifier_test.dart`, and
  `integration_test/app_test.dart`. Test proxy routing and airport data.
- **FILE-009**: `docs/cloudflare-worker-setup.md`. Describe Worker setup,
  token scope, GitHub variables, deployment, and CORS checks.

## 6. Testing

- **TEST-001**: `flutter analyze lib test integration_test` passes.
- **TEST-002**: `flutter test` passes, including proxy and classifier tests.
- **TEST-003**: Worker `npm test` passes for route and origin cases.
- **TEST-004**: `flutter build web --release` succeeds with the project base
  href and a non-empty Worker URL. The Pages workflow publishes `build/web`.
- **TEST-005**: `flutter build apk --debug` succeeds. The current tagged Android
  release workflow still creates its existing APK artifacts.
- **TEST-006**: Browser smoke checks pass for API responses, HTTPS GPS, manual
  coordinates, browser persistence after reload, and PWA standalone launch.
- **TEST-007**: Android smoke checks pass for GPS, direct API requests, manual
  coordinates, and Collector persistence after restart.

## 7. Risks & Assumptions

- **RISK-001**: A Worker does not remove OpenSky rate limits or upstream
  outages. It adds another service that can fail.
- **RISK-002**: Browsers can remove local `shared_preferences` data. The PWA
  has no cloud backup in this plan.
- **RISK-003**: Incorrect origin or Worker overrides cause browser CORS errors.
  The workflow defaults to the repository's current Pages and Worker origins.
- **ASSUMPTION-001**: GitHub Pages project hosting is the production target,
  and its site uses HTTPS.
- **ASSUMPTION-002**: Current `geolocator`, `shared_preferences`,
  `flutter_riverpod`, and `url_launcher` versions include web implementations.
  The web build and browser smoke tests will verify this assumption.

## 8. Related Specifications / Further Reading

- [Web app research](../docs/web-app-research.md)
- [Project README](../README.md)
- [Cloudflare Worker setup guide](../docs/cloudflare-worker-setup.md)
- [Flutter Web deployment](https://docs.flutter.dev/deployment/web)
- [Cloudflare Workers documentation](https://developers.cloudflare.com/workers/)
