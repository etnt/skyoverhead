/// Pure collection extractors over `List<Sighting>` (Phase 4).
///
/// Collections use **unique keys** (a set of distinct values), which is what
/// the medal ladder and the Medals shelf count. Statistics (Phase 5) will use
/// raw occurrence counts instead. Every extractor tolerates partial sightings:
/// missing/blank fields simply contribute nothing rather than throwing.
library;

import 'countries.dart';
import 'models.dart';
import 'sighting.dart';

/// The kinds of collection the app tracks.
enum CollectionKind {
  destinations,
  origins,
  airlines,
  aircraftTypes,
  manufacturers,
  registrations,
  countries,
}

/// A human label for a [CollectionKind].
extension CollectionKindLabel on CollectionKind {
  String get label => switch (this) {
        CollectionKind.destinations => 'Destinations',
        CollectionKind.origins => 'Origins',
        CollectionKind.airlines => 'Airlines',
        CollectionKind.aircraftTypes => 'Aircraft types',
        CollectionKind.manufacturers => 'Manufacturers',
        CollectionKind.registrations => 'Registrations',
        CollectionKind.countries => 'Countries',
      };
}

/// Unique destination airport codes (IATA preferred, else ICAO).
Set<String> uniqueDestinations(List<Sighting> sightings) =>
    _codes(sightings, (s) => s.destination);

/// Unique origin airport codes (IATA preferred, else ICAO).
Set<String> uniqueOrigins(List<Sighting> sightings) =>
    _codes(sightings, (s) => s.origin);

/// Unique airline / operator names.
Set<String> uniqueAirlines(List<Sighting> sightings) => _strings(
      sightings,
      (s) => s.airline ?? s.registeredOwnerOperator,
    );

/// Unique aircraft type designators (model).
Set<String> uniqueAircraftTypes(List<Sighting> sightings) =>
    _strings(sightings, (s) => s.model);

/// Unique manufacturers.
Set<String> uniqueManufacturers(List<Sighting> sightings) =>
    _strings(sightings, (s) => s.manufacturer);

/// Unique aircraft registrations (upper-cased).
Set<String> uniqueRegistrations(List<Sighting> sightings) =>
    _strings(sightings, (s) => s.registration, upper: true);

/// Unique countries derived from origin and destination airport ICAO codes.
Set<String> uniqueCountries(List<Sighting> sightings) {
  final result = <String>{};
  for (final s in sightings) {
    final from = countryForIcao(s.origin?.icao);
    if (from != null) result.add(from);
    final to = countryForIcao(s.destination?.icao);
    if (to != null) result.add(to);
  }
  return result;
}

/// Compute the unique-key set for any [kind].
Set<String> collectionFor(CollectionKind kind, List<Sighting> sightings) =>
    switch (kind) {
      CollectionKind.destinations => uniqueDestinations(sightings),
      CollectionKind.origins => uniqueOrigins(sightings),
      CollectionKind.airlines => uniqueAirlines(sightings),
      CollectionKind.aircraftTypes => uniqueAircraftTypes(sightings),
      CollectionKind.manufacturers => uniqueManufacturers(sightings),
      CollectionKind.registrations => uniqueRegistrations(sightings),
      CollectionKind.countries => uniqueCountries(sightings),
    };

Set<String> _codes(
  List<Sighting> sightings,
  Airport? Function(Sighting) pick,
) {
  final result = <String>{};
  for (final s in sightings) {
    final code = airportCode(pick(s));
    if (code != null) result.add(code);
  }
  return result;
}

Set<String> _strings(
  List<Sighting> sightings,
  String? Function(Sighting) pick, {
  bool upper = false,
}) {
  final result = <String>{};
  for (final s in sightings) {
    final raw = pick(s)?.trim();
    if (raw == null || raw.isEmpty) continue;
    result.add(upper ? raw.toUpperCase() : raw);
  }
  return result;
}

/// The preferred display code for an [airport]: IATA if present, else ICAO,
/// upper-cased and trimmed; `null` when neither is known.
String? airportCode(Airport? airport) {
  if (airport == null) return null;
  final iata = airport.iata?.trim();
  if (iata != null && iata.isNotEmpty) return iata.toUpperCase();
  final icao = airport.icao?.trim();
  if (icao != null && icao.isNotEmpty) return icao.toUpperCase();
  return null;
}
