/// A named, user-saved observer location.
///
/// Users can store a latitude/longitude (plus elevation) under a name — e.g.
/// "Home" or "Summer house" — and later switch the observing position by
/// picking one of the saved entries. Serialization mirrors [Sighting]: stable
/// field names, tolerant of missing/unknown fields so stored data survives
/// model changes.
library;

class SavedLocation {
  /// Stable unique identifier (also used as the storage id).
  final String id;

  /// User-visible label, e.g. "Home". Unique among saved locations; saving
  /// under an existing name overwrites that entry.
  final String name;

  /// Observer latitude in degrees (-90..90).
  final double latitude;

  /// Observer longitude in degrees (-180..180).
  final double longitude;

  /// Observer height above sea level in metres.
  final double elevationM;

  const SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevationM = 0.0,
  });

  SavedLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? elevationM,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationM: elevationM ?? this.elevationM,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'elevationM': elevationM,
  };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      elevationM: _toDouble(json['elevationM']),
    );
  }

  static double _toDouble(dynamic value, [double fallback = 0.0]) =>
      value is num ? value.toDouble() : fallback;
}
