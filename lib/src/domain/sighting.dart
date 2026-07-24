/// The collectible sighting record (Phase 1).
///
/// A [Sighting] is an immutable snapshot of a [Candidate] at the moment it was
/// identified, plus the [Confidence] of the pick and a capture timestamp. It is
/// what the collector feature persists (via `SightingStore<Sighting>`) and later
/// aggregates into collections, medals, records and statistics.
///
/// Serialization uses stable field names and is deliberately tolerant of
/// missing/unknown fields so stored data survives forward/backward model
/// changes: absent strings decode to `null`, absent numbers to `0`, and unknown
/// enum names fall back (`confidence` to [Confidence.none], `enrichmentStatus`
/// to `null`).
library;

import 'models.dart';

class Sighting {
  /// When this sighting was captured (local device time).
  final DateTime capturedAt;

  final String icao24;
  final String? callsign;
  final String? registration;
  final String? manufacturer;
  final String? model;
  final String? airline;
  final String? registeredOwnerOperator;
  final Airport? origin;
  final Airport? destination;
  final double altitudeM;
  final double? speedMps;
  final double distanceKm;
  final double bearingDeg;
  final double elevationDeg;
  final Confidence confidence;
  final String? photoUrl;
  final EnrichmentStatus? enrichmentStatus;

  const Sighting({
    required this.capturedAt,
    required this.icao24,
    this.callsign,
    this.registration,
    this.manufacturer,
    this.model,
    this.airline,
    this.registeredOwnerOperator,
    this.origin,
    this.destination,
    required this.altitudeM,
    this.speedMps,
    required this.distanceKm,
    required this.bearingDeg,
    required this.elevationDeg,
    required this.confidence,
    this.photoUrl,
    this.enrichmentStatus,
  });

  /// Snapshot a ranked [candidate] into a persistable sighting.
  factory Sighting.fromCandidate(
    Candidate candidate, {
    required Confidence confidence,
    required DateTime capturedAt,
  }) {
    return Sighting(
      capturedAt: capturedAt,
      icao24: candidate.icao24,
      callsign: candidate.callsign,
      registration: candidate.registration,
      manufacturer: candidate.manufacturer,
      model: candidate.model,
      airline: candidate.airline,
      registeredOwnerOperator: candidate.registeredOwnerOperator,
      origin: candidate.origin,
      destination: candidate.destination,
      altitudeM: candidate.altitudeM,
      speedMps: candidate.speedMps,
      distanceKm: candidate.distanceKm,
      bearingDeg: candidate.bearingDeg,
      elevationDeg: candidate.elevationDeg,
      confidence: confidence,
      photoUrl: candidate.photoUrl,
      enrichmentStatus: candidate.enrichmentStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'capturedAt': capturedAt.toIso8601String(),
        'icao24': icao24,
        if (callsign != null) 'callsign': callsign,
        if (registration != null) 'registration': registration,
        if (manufacturer != null) 'manufacturer': manufacturer,
        if (model != null) 'model': model,
        if (airline != null) 'airline': airline,
        if (registeredOwnerOperator != null)
          'registeredOwnerOperator': registeredOwnerOperator,
        if (origin != null) 'origin': _airportToJson(origin!),
        if (destination != null) 'destination': _airportToJson(destination!),
        'altitudeM': altitudeM,
        if (speedMps != null) 'speedMps': speedMps,
        'distanceKm': distanceKm,
        'bearingDeg': bearingDeg,
        'elevationDeg': elevationDeg,
        'confidence': confidence.name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (enrichmentStatus != null)
          'enrichmentStatus': enrichmentStatus!.name,
      };

  factory Sighting.fromJson(Map<String, dynamic> json) {
    return Sighting(
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      icao24: json['icao24'] as String? ?? '',
      callsign: json['callsign'] as String?,
      registration: json['registration'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      airline: json['airline'] as String?,
      registeredOwnerOperator: json['registeredOwnerOperator'] as String?,
      origin: _airportFromJson(json['origin']),
      destination: _airportFromJson(json['destination']),
      altitudeM: _toDouble(json['altitudeM']),
      speedMps: _toDoubleOrNull(json['speedMps']),
      distanceKm: _toDouble(json['distanceKm']),
      bearingDeg: _toDouble(json['bearingDeg']),
      elevationDeg: _toDouble(json['elevationDeg']),
      confidence: _confidenceFromName(json['confidence'] as String?),
      photoUrl: json['photoUrl'] as String?,
      enrichmentStatus: _enrichmentFromName(json['enrichmentStatus'] as String?),
    );
  }
}

Map<String, dynamic> _airportToJson(Airport a) => {
      if (a.icao != null) 'icao': a.icao,
      if (a.iata != null) 'iata': a.iata,
      if (a.name != null) 'name': a.name,
    };

Airport? _airportFromJson(dynamic json) {
  if (json is! Map) return null;
  return Airport(
    icao: json['icao'] as String?,
    iata: json['iata'] as String?,
    name: json['name'] as String?,
  );
}

double _toDouble(dynamic value, [double fallback = 0.0]) =>
    value is num ? value.toDouble() : fallback;

double? _toDoubleOrNull(dynamic value) =>
    value is num ? value.toDouble() : null;

Confidence _confidenceFromName(String? name) {
  for (final value in Confidence.values) {
    if (value.name == name) return value;
  }
  return Confidence.none;
}

EnrichmentStatus? _enrichmentFromName(String? name) {
  if (name == null) return null;
  for (final value in EnrichmentStatus.values) {
    if (value.name == name) return value;
  }
  return null;
}
