# Implementation Plan: Gamification & Collector Features

## Goal

Turn each successful aircraft identification into a persistent, collectible
**Sighting**, and build the collector loop on top of it: a **Logbook**,
**collections** (destinations, airlines, aircraft types…), **medals**, personal
**records**, and **statistics** — **strictly as an opt-in feature**. The app's
original "identify only, remember nothing" behaviour stays the **default**; no
sighting is ever stored until the user explicitly turns collecting on. See the
exploratory [gamification brainstorm](gamification-brainstorm.md) for the idea
catalogue this plan draws from.

## Scope

### In scope
- An **opt-in toggle** ("Collector mode", default **off**) that gates all data
  gathering; the persisted preference survives restarts.
- A **Pause** setting that stops new logging while **keeping** already-collected
  data (distinct from turning Collector mode off).
- Local, on-device persistence of every successful identification **while
  collecting is enabled and not paused**.
- A `Sighting` domain model (snapshot of a `Candidate` at capture time).
- Automatic logging hooked into the existing identify success path, **gated on
  the opt-in flag**.
- Logbook UI (reverse-chronological list + sighting detail).
- Collections, medals, records, and statistics computed from stored sightings.
- Reward feedback (post-identify toast/snackbar) when a new entry or medal lands.
- Unit test coverage for the store, aggregations, and medal logic.

### Out of scope (and why)
- **Collecting-on-by-default** — explicitly rejected. The identification-only
  experience must remain untouched unless the user opts in.
- **Cloud sync / accounts** — everything stays device-local for privacy and
  simplicity. Cross-device sync is a possible later track.
- **Social / leaderboards vs. other users** — records are personal-best only.
- **New external data sources** — we only persist and aggregate data the app
  already fetches from OpenSky/ADSBDB. (Country derivation uses a static
  ICAO-prefix map, no new API.)
- **Backfilling history** — logging starts from first launch of the feature;
  there is no prior data to import.

## Current state (verified)

- **No persistence today** — no `shared_preferences`, DB, or file storage in the
  app; all state is ephemeral (`lib/src/state/`).
- State management is **Riverpod** (`flutter_riverpod: ^2.5.0`).
- The identify success path is centralized: `IdentifyController.identify` sets
  `IdentifySuccess(IdentifyResult)` in
  [lib/src/state/identify_controller.dart](../lib/src/state/identify_controller.dart).
  This is the single hook point for auto-logging.
- The collectible payload already exists: `Candidate` in
  [lib/src/domain/models.dart](../lib/src/domain/models.dart) carries
  `destination`/`origin` (`Airport`), `airline`, `manufacturer`, `model`,
  `registration`, `altitudeM`, `speedMps`, `distanceKm`, `bearingDeg`,
  `elevationDeg`, `enrichmentStatus`, etc.
- Many sightings will have `enrichmentStatus == unavailable` (no route/airline);
  the plan must handle partial data gracefully.
- UI is a single `HomeScreen`; layer under `lib/src/ui/`. A `Settings` dialog
  already exists ([lib/src/ui/settings_dialog.dart](../lib/src/ui/settings_dialog.dart))
  and writes back into `identifyConfigProvider` — a natural home for the opt-in
  checkbox.
- `IdentifyConfig` / `identifyConfigProvider` are **in-memory only** (reset to
  defaults on restart), so the opt-in flag needs its **own persisted**
  preference rather than riding on the config.
- Tests live under `test/` and use `mocktail`.
- Dart SDK constraint: `^3.12.0`.

## Deliverables

1. A **persisted opt-in preference** ("Collector mode", default off) + a
   **Pause** setting, with settings controls, gating all data gathering.
2. New domain models: `Sighting`, `Medal`/achievement definitions, records &
   stats aggregates.
3. A persistence layer (`SightingStore`) with a JSON-backed implementation.
4. Riverpod providers exposing the opt-in flag, sightings, and derived
   aggregates.
5. Auto-logging wired into the identify success path (gated on the flag).
6. Logbook, Medals, and Stats UI surfaces (bottom navigation), shown only when
   collecting is enabled.
7. Reward feedback on new unlocks.
8. Tests for the gate, store, aggregations, and medal unlock rules.
9. This plan document.

## Design overview

```
Identify success ─▶ [Collector ON & not paused?] ─▶ SightingLogger ─▶ SightingStore (persisted JSON)
                          │  no                          │
                          ▼                              │
                    (do nothing —                ┌───────┼──────────────────┐
                 identify-only / paused)          ▼       ▼                   ▼
                                     Collections  Records          Statistics
                                     + Medals   (personal bests) (top 5, rarity…)
                                          │       │                   │
                                          └────── Riverpod providers ─┘
                                                     │
                                        Logbook / Medals / Stats UI
                                        (visible when Collector mode ON)
```

- **Collector mode is the master switch.** When off, the app behaves exactly as
  today: identify, display, forget. No store reads or writes occur, and turning
  it off erases any prior data.
- **Pause** is a softer stop: keeps data and tabs, suppresses new logging only.
- **Store** owns the raw list of `Sighting`s and persistence.
- **Aggregates are computed on read** from that list (no separately maintained
  counters at first), keeping logic simple and testable.
- **Providers** expose the flag, the raw list, and the derived views to the UI.

### Opt-in gating (privacy-first)

- Default is **off** — a fresh install collects nothing.
- The preferences are **persisted** (their own keys) so the choices stick across
  restarts, unlike the in-memory `IdentifyConfig`.
- **Two independent controls** give a clean mental model:
  - **Collector mode (off ⇢ on):** the master privacy switch. Turning it **off
    wipes all stored sightings** (behind a confirmation) so "off" truly means
    "nothing retained", and hides the collector tabs.
  - **Pause (while on):** stops new logging but **keeps** existing data and the
    collector tabs/stats visible. This is the non-destructive "take a break"
    option.
- Logging happens only when **Collector mode is on AND not paused**.
- A short explanatory line accompanies the controls (what gets stored, that it
  stays on-device, and that turning Collector mode off erases it).

---

## Phase 0 — Foundations: opt-in preference, persistence dependency & storage abstraction

Establish the master opt-in switch and where/how sightings are stored, isolated
behind interfaces so backends can change later.

**Work items**
- WI-0.1 Add a persistence dependency (`shared_preferences`) to `pubspec.yaml`
  and run `flutter pub get`. Rationale: lightest option; JSON blob is adequate
  for the expected volume. (Swap to Hive/Drift later if query needs grow.)
- WI-0.2 Define a `SightingStore` interface (add/all/clear + change
  notification) in `lib/src/data/`.
- WI-0.3 Implement `SharedPrefsSightingStore` (JSON-encode the list under a
  single key; load on init; append on add).
- WI-0.4 Provide an in-memory `FakeSightingStore` under `test/support/` for
  unit tests.
- WI-0.5 Add a **persisted opt-in preference** (`collectorEnabled`, default
  `false`) and a **persisted `collectorPaused`** flag (default `false`) behind a
  small `PreferencesStore` (or a thin wrapper over `shared_preferences`), plus
  `collectorEnabledProvider` / `collectorPausedProvider` (Riverpod) that read
  the stored values and write changes back. `collectorEnabled` must default off
  on a fresh install.
- WI-0.6 Provide a fake/in-memory preferences implementation for tests.

**Exit criteria:** store can round-trip a list of sightings across app restarts;
the opt-in and pause flags persist across restarts and default to off; fakes
available to tests.

---

## Phase 1 — `Sighting` model & serialization

Define the collectible record and its (de)serialization.

**Work items**
- WI-1.1 Add a `Sighting` model in `lib/src/domain/models.dart` (or a new
  `sighting.dart`) capturing: `timestamp`, `icao24`, `callsign`,
  `registration`, `manufacturer`, `model`, `airline`/operator,
  origin/destination airport codes+name, `altitudeM`, `speedMps`, `distanceKm`,
  `bearingDeg`, `elevationDeg`, `confidence`, `photoUrl`, `enrichmentStatus`.
- WI-1.2 Add `Sighting.fromCandidate(Candidate, {required Confidence, required
  DateTime capturedAt})` factory.
- WI-1.3 Add `toJson`/`fromJson` (stable field names; tolerant of missing
  fields for forward/backward compatibility).
- WI-1.4 Unit tests: candidate→sighting mapping, JSON round-trip, and partial
  (`enrichmentStatus == unavailable`) sightings.

**Exit criteria:** a `Candidate` + `Confidence` converts to a `Sighting` and
survives a JSON round-trip losslessly.

---

## Phase 2 — Auto-logging on identify success (gated on opt-in)

Persist every successful identification **only while collecting is enabled**,
including "clear skies" handling.

**Work items**
- WI-2.1 Add a `SightingLogger` (or extend the controller) that, on
  `IdentifySuccess` with a non-null `candidate`, builds a `Sighting` and calls
  `store.add`.
- WI-2.2 **Gate first**: read `collectorEnabledProvider` and
  `collectorPausedProvider`; log only when enabled **and not paused** (otherwise
  do nothing, no store access at all). Wire the logger into
  `IdentifyController.identify` (single hook point) via a Riverpod provider for
  the store; do **not** log the `confidence == none` clear-skies case.
- WI-2.3 De-duplication guard: collapse repeated captures of the same `icao24`
  within a short window (e.g. 60 s) so holding on one plane doesn't inflate
  counts. Make the window a constant for now.
- WI-2.4 Tests: with opt-in **off**, success logs nothing (identify-only
  behaviour preserved); with opt-in on but **paused**, success logs nothing but
  existing data is untouched; with opt-in **on and not paused**, success logs
  exactly one sighting; clear-skies logs none; duplicate within window is
  collapsed; failure logs none.

**Exit criteria:** with collecting off, behaviour is identical to today (zero
sightings written); with collecting on, tapping "What's overhead?" reliably
appends one de-duplicated sighting on a real result and nothing on empty/error
results.

---

## Phase 3 — Logbook UI

Make the collected data visible; introduce navigation.

**Work items**
- WI-3.0 Add the collector controls to the existing settings dialog:
  - a **Collector mode** checkbox ("save the aircraft you identify") bound to
    `collectorEnabledProvider`, with a one-line privacy note; turning it **off
    prompts a confirmation** and, on confirm, **wipes the store** (calls
    `store.clear`).
  - a **Pause collecting** toggle bound to `collectorPausedProvider`, shown only
    when Collector mode is on (keeps data, stops new logging).
- WI-3.1 Introduce bottom navigation (`Sky` / `Logbook` / `Medals` / `Stats`)
  wrapping the existing `HomeScreen` as the `Sky` tab. **Collector tabs appear
  only when Collector mode is on** (regardless of pause); when off, the app
  stays a single `Sky` screen (unchanged experience).
- WI-3.2 `sightingsProvider` exposing the reverse-chronological list from the
  store.
- WI-3.3 Logbook list screen: one row per sighting (headline callsign/reg,
  route, timestamp, thumbnail if `photoUrl`).
- WI-3.4 Sighting detail: reuse/adapt `ResultCard` to render a stored
  `Sighting`.
- WI-3.5 Empty state ("No sightings yet — point at the sky").
- WI-3.6 Widget tests: tabs hidden when Collector mode off; shown when on
  (including while paused); disabling prompts confirmation and wipes; list
  rendering and empty state.

**Exit criteria:** with Collector mode off the UI is unchanged and no data is
retained; with it on, identified aircraft appear in the Logbook and persist
across restarts, pausing stops new entries without losing existing ones, and
tapping a row opens its detail.

---

## Phase 4 — Collections & medals

The "flying ace" reward layer.

**Work items**
- WI-4.1 Define collection extractors (pure functions over `List<Sighting>`):
  unique destinations, origins, airlines, aircraft types, manufacturers,
  registrations.
- WI-4.2 Add a static ICAO-prefix→country map + a **Countries** collection
  derived from airport ICAO codes.
- WI-4.3 Define the tiered medal ladder (Cadet→Air Marshal thresholds as tunable
  constants) and a `Medal`/achievement model with progress-to-next-tier.
- WI-4.4 Add a handful of themed one-off achievements (e.g. High Roller,
  Speed Demon, Right Overhead, Globe Trotter) as predicate-based rules over a
  sighting or the aggregate set.
- WI-4.5 `medalsProvider` computing earned/locked + progress from sightings.
- WI-4.6 Medals UI: shelf grid of earned/locked medals with progress bars.
- WI-4.7 Unit tests for each extractor, tier boundaries (off-by-one), and every
  themed achievement predicate; ensure partial sightings don't crash country/
  route logic.

**Exit criteria:** collection counts and medal tiers compute correctly from a
known fixture set; Medals tab reflects them.

---

## Phase 5 — Records & statistics

Personal bests and insight views.

**Work items**
- WI-5.1 Records aggregate (pure): highest altitude, fastest, farthest, closest,
  highest overhead — each keeping the value + originating `Sighting`.
- WI-5.2 (Optional) Longest route via great-circle distance between
  origin/destination when both are known (reuse `lib/src/domain/geo.dart`).
- WI-5.3 Statistics aggregate (pure): top-5 destinations/airlines/types, rarest
  destination, per-day counts, day-streak, confidence mix, bearing distribution.
- WI-5.4 Stats UI: Records board + Top-5 lists + a simple sightings-over-time and
  compass-rose visual (basic `CustomPaint` acceptable).
- WI-5.5 Unit tests for records selection (ties, missing values) and stats math
  (top-N ordering, streak across gaps, rarity with single-occurrence).

**Exit criteria:** records and stats match hand-computed expectations for a
fixture set and handle empty/partial data without errors.

---

## Phase 6 — Reward feedback & polish

Make unlocks feel immediate; finish edges.

**Work items**
- WI-6.1 After logging, detect newly-earned entries/medals and surface a
  snackbar/toast on the `Sky` tab ("New destination! FRA (12 total)" / "New
  medal: Flying Ace").
- WI-6.3 Handle store growth: cap or paginate the logbook list rendering if the
  count grows large (data itself stays complete).
- WI-6.4 Accessibility/labels pass on new screens; ensure new UI matches
  existing theme.
- WI-6.5 Update `README.md` with a short "Collect & Medals" feature blurb.

**Exit criteria:** earning something shows immediate feedback; docs updated.

---

## Testing strategy

- **Opt-in gate:** explicit tests that with collecting **off** the identify path
  writes nothing (the identification-only guarantee), that **pause** suppresses
  new logging without touching existing data, that **disabling wipes** the
  store, and that both flags persist across a simulated restart and default to
  off.
- **Unit-first:** all extractors, records, stats, and medal predicates are pure
  functions over `List<Sighting>` — test them with fixtures (mirrors existing
  `test/ranking_test.dart` style).
- **Store:** round-trip and persistence-boundary tests via the fake and a real
  `shared_preferences` mock.
- **Controller:** logging behaviour (success/clear-skies/error/dedup) with a
  `FakeSightingStore` and existing `mocktail` fakes.
- **Widget:** logbook list, empty state, medals shelf, reward snackbar.
- Gate: `flutter analyze` clean + `flutter test` green before merge.

## Sequencing & dependencies

- Phase 0 → 1 → 2 are strictly ordered (storage → model → logging).
- Phases 3, 4, 5 all depend on 2 but are **independent of each other** and can be
  built in any order / parallel.
- Phase 6 depends on 4 (and ideally 5) for meaningful reward messages.

## Suggested MVP (first shippable slice)

Phases **0 → 1 → 2 → 3** (including the WI-3.0 opt-in checkbox and WI-2.2 gate),
plus the single **unique-destinations medal ladder** from Phase 4 (WI-4.1
destinations only, WI-4.3, WI-4.5, WI-4.6) and the post-identify toast (WI-6.1).
This proves the opt-in → capture → collect → reward loop end to end while keeping
the default experience untouched; records, full stats, and remaining collections
layer on afterwards with no rework to the store.

## Open questions

- **Opt-in surface** — ✅ **Decided:** a checkbox in the existing settings dialog
  (WI-3.0). No separate onboarding/first-run prompt.
- **Data on opt-out** — ✅ **Decided:** turning Collector mode **off wipes** the
  store (with confirmation), so "off" means nothing retained. A separate
  **Pause** stops logging while keeping data.
- **Uniqueness rules** — confirm collections use unique keys while statistics use
  raw counts (per brainstorm §7).
- **De-dup window** — is 60 s by `icao24` the right default?
- **Partial sightings** — confirmed approach: still logged; contribute to
  physics-based records/medals but not to route/airline collections.
- **Storage backend** — start on `shared_preferences` JSON; revisit if volume or
  query needs push us to Drift/Hive.
- **Medal thresholds** — placeholders; tune after observing real sighting rates.
