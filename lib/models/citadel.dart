import 'package:latlong2/latlong.dart';

/// Point-of-Interest Citadel / Stronghold representing King of the Hill landmarks.
enum CitadelCategory {
  park,
  hilltop,
  stadium,
  monument,
  bridge,
}

class Citadel {
  final String id;
  final String name;
  final CitadelCategory category;
  final LatLng position;
  final double radiusMeters;
  String controllingFaction;
  String rulerAthleteName;
  DateTime capturedAt;
  double influenceRadiance;
  int defenseLevel;

  Citadel({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    this.radiusMeters = 80.0,
    required this.controllingFaction,
    required this.rulerAthleteName,
    required this.capturedAt,
    this.influenceRadiance = 1.5,
    this.defenseLevel = 1,
  });

  String get categoryIconName {
    switch (category) {
      case CitadelCategory.park:
        return 'nature';
      case CitadelCategory.hilltop:
        return 'terrain';
      case CitadelCategory.stadium:
        return 'sports';
      case CitadelCategory.monument:
        return 'account_balance';
      case CitadelCategory.bridge:
        return 'alt_route';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'radiusMeters': radiusMeters,
    'controllingFaction': controllingFaction,
    'rulerAthleteName': rulerAthleteName,
    'capturedAt': capturedAt.toIso8601String(),
    'influenceRadiance': influenceRadiance,
    'defenseLevel': defenseLevel,
  };

  factory Citadel.fromJson(Map<String, dynamic> json) {
    return Citadel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: CitadelCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => CitadelCategory.park,
      ),
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 80.0,
      controllingFaction: json['controllingFaction'] as String? ?? 'Apex Vanguard',
      rulerAthleteName: json['rulerAthleteName'] as String? ?? 'Ghost Guardian',
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      influenceRadiance: (json['influenceRadiance'] as num?)?.toDouble() ?? 1.5,
      defenseLevel: json['defenseLevel'] as int? ?? 1,
    );
  }
}
