# Gamification & Collector Direction — Brainstorm

Status: **Brainstorm / exploratory** — nothing here is committed. This is a menu of
ideas to react to, not a plan.

## 1. Why this fits Sky Overhead

The app already identifies a rich, per-flight data object (`Candidate`) every time the
user taps "What's overhead?". Each identification is essentially a **trading card** with
lots of collectible attributes:

- Aircraft: `manufacturer`, `model`, `registration`, `icao24`
- Operator: `airline`, `registeredOwnerOperator`
- Route: `origin` / `destination` airports (ICAO / IATA / name)
- Physics: `altitudeM`, `speedMps`, `distanceKm`, `bearingDeg`, `elevationDeg`
- Meta: `confidence`, `positionAgeS`, `photoUrl`

The **one missing ingredient today is persistence** — results vanish when the app
closes. Adding a local store (see §7) turns every tap into a permanent "capture" and
unlocks everything below.

## 2. Core loop: capture → collect → reward

```
Point at sky → Identify → Auto-log the sighting → Update collections/stats → Unlock medals
```

Each successful identification becomes a **Sighting** record. Sightings feed:

1. **Collections** (destinations seen, airlines, aircraft types, countries…)
2. **Records** (personal bests: highest, fastest, farthest…)
3. **Medals / achievements** (milestones across collections and records)
4. **Statistics** (top 5s, rarity, streaks)

## 3. Collections (the "Pokédex" layer)

Things the user is filling up over time. Each has a total-unique count and a
completion feel.

| Collection | Source field(s) | Example entry |
|---|---|---|
| Destinations seen | `destination.icao/iata/name` | "FRA — Frankfurt am Main" |
| Origins seen | `origin.*` | "ARN — Stockholm Arlanda" |
| Airlines spotted | `airline` / `registeredOwnerOperator` | "Lufthansa" |
| Aircraft types | `manufacturer` + `model` | "Airbus A320" |
| Manufacturers | `manufacturer` | "Boeing" |
| Registrations (tail numbers) | `registration` | "D-AIZE" |
| Countries (derived) | airport ICAO prefix → country | "Germany" |

> **Derivation note:** Country can be derived from an airport's ICAO prefix (e.g.
> `ED*` = Germany, `ES*` = Sweden) without any new API. A small static prefix→country
> map covers this cheaply.

## 4. Medals — "flying ace" style ranks

Medals reward reaching thresholds. Two flavours:

### 4a. Tiered ranks (repeat the same medal at rising thresholds)

Classic aviation-flavoured progression, e.g. **Destinations seen**:

| Rank | Unique destinations |
|---|---|
| Cadet | 1 |
| Wingman | 5 |
| Aviator | 10 |
| Flying Ace | 25 |
| Squadron Leader | 50 |
| Air Marshal | 100 |

The same tier ladder can be reused for **Airlines**, **Aircraft types**, **Countries**,
etc., each as its own track.

### 4b. Themed one-off achievements

Fun, specific unlocks that make sightings feel like moments:

- **High Roller** — spot an aircraft above 12,000 m.
- **Speed Demon** — spot ground speed over 1,000 km/h.
- **Right Overhead** — elevation ≥ 85° (almost directly above you).
- **On the Horizon** — a valid ID at your minimum elevation / max distance edge.
- **Fresh Off the Radar** — `positionAgeS` ≤ 3 s (near-live fix).
- **Needle in a Haystack** — a `high` confidence ID while ≥ 3 alternatives existed.
- **Globe Trotter** — origin and destination in two different countries.
- **Hometown Hero** — spot a flight whose origin *or* destination is your nearest airport.
- **Night Owl** / **Early Bird** — first sighting logged after 22:00 / before 06:00.
- **Rainbow Fleet** — spot 5 different airlines in a single day.

## 5. Records (personal bests)

Single-value leaderboards against *yourself*. Each keeps the value + the sighting that set it.

- **Highest altitude** (`altitudeM`)
- **Fastest** (`speedMps` → km/h)
- **Farthest** (`distanceKm`)
- **Closest** (min `distanceKm`)
- **Highest overhead** (max `elevationDeg`)
- **Longest route** (great-circle distance between `origin` and `destination`, if both known)

Presenting these as a "Records" board gives a reason to keep tapping even when no new
collection entry is earned.

## 6. Statistics & insights

Read-only analytics that make the collection feel alive:

- **Top 5 destinations** (most frequently seen `destination`).
- **Top 5 airlines / aircraft types.**
- **Rarest destination** — seen exactly once, or least often.
- **Rarest aircraft type / airline.**
- **Sightings over time** — per day/week counts, simple sparkline.
- **Streak** — consecutive days with at least one sighting.
- **Coverage map** — bearings of all sightings as a compass rose (which directions of
  sky you watch most).
- **Confidence mix** — share of high / medium / ambiguous IDs.

## 7. Data & persistence (what this needs technically)

All of the above depends on storing sightings locally. Options, lightest first:

1. **`shared_preferences` + JSON** — simplest; fine for a few hundred sightings.
2. **Hive** — typed boxes, good ergonomics, no SQL.
3. **`sqflite` / Drift** — best if we want real queries for the stats/top-5 features.

Suggested minimal `Sighting` record (a snapshot of the `Candidate` at capture time):

```
Sighting {
  timestamp        // when captured
  icao24
  callsign
  registration
  manufacturer, model
  airline / operator
  originIcao/Iata/Name
  destinationIcao/Iata/Name
  altitudeM, speedMps, distanceKm, bearingDeg, elevationDeg
  confidence
  photoUrl
}
```

Derived aggregates (unique destinations, top 5s, medals earned) can be **computed on
read** from the sightings list, so we don't have to maintain them separately at first.

### De-duplication question

Do we count *unique* destinations, or every *sighting*? Likely both:
- **Collections / medals** → unique keys (e.g. distinct destination ICAO).
- **Statistics** → raw sighting counts (so "most seen" makes sense).

Also decide: should tapping the same plane twice in 60 s count once? (Suggest: collapse
by `icao24` within a short window to avoid inflation.)

## 8. UX surfaces to add

- **"Logbook" / "Collection" tab** — replaces the single-screen model with a small
  bottom nav: *Sky* (current), *Logbook*, *Medals*, *Stats*.
- **Post-identify toast** — "New destination! FRA added (12 total)" or "New medal:
  Flying Ace" right after a capture, so rewards feel immediate.
- **Medal shelf** — grid of earned/locked medals with progress bars to the next tier.
- **Sighting detail** — tap a logbook entry to re-open its `ResultCard`.

## 9. Open questions / decisions

- **Persistence choice** — start with `shared_preferences` JSON, or go straight to a DB?
- **Uniqueness rules** — per §7 (unique vs. raw, de-dup window).
- **Offline / privacy** — keep everything device-local (no account)? Simplest and
  privacy-friendly, but no cross-device sync.
- **Handling missing enrichment** — many sightings will have `enrichmentStatus =
  unavailable` (no route/airline). How do those count? Suggest: still log them, but they
  only contribute to physics-based records/medals, not destination collections.
- **Medal tuning** — thresholds in §4a are placeholders; tune once we see real sighting
  rates.

## 10. Suggested first slice (MVP)

A small, shippable increment that proves the loop:

1. Add local persistence and log every successful identification as a `Sighting`.
2. Add a **Logbook** list (reverse-chronological sightings).
3. Track **unique destinations seen** + a single medal ladder (§4a) for it.
4. Show a **post-identify toast** when a new destination or medal is earned.

Everything else (records, stats, more collections, themed achievements) layers on top of
the same sightings store without rework.
