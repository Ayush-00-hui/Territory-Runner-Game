import 'package:latlong2/latlong.dart';

/// Represents a geographic exclusion zone (home, office, school) where GPS tracks
/// and claimed territorial boundaries are redacted to protect user safety and privacy.
class PrivacyZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isEnabled;
  final DateTime createdAt;

  const PrivacyZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 200.0,
    this.isEnabled = true,
    required this.createdAt,
  });

  LatLng get center => LatLng(latitude, longitude);

  PrivacyZone copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return PrivacyZone(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'is_enabled': isEnabled,
        'created_at': createdAt.toIso8601String(),
      };

  factory PrivacyZone.fromJson(Map<String, dynamic> json) {
    return PrivacyZone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Privacy Zone',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 200.0,
      isEnabled: json['is_enabled'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
