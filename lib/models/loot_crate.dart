import 'package:latlong2/latlong.dart';

/// The category of consumable loot in a tactical crate.
enum LootCrateType {
  /// Repairs territory decay on home turf by 20%.
  shieldBattery,

  /// Temporarily doubles polygon territory capture multiplier for 500m.
  overchargeBeacon,

  /// Awards bonus faction XP shards for cosmetics and seasonal ranking.
  factionShard,
}

/// A procedurally spawned tactical loot crate in the world.
class LootCrate {
  final String id;
  final LootCrateType type;
  final LatLng position;
  final DateTime spawnedAt;
  final DateTime expiresAt;
  final double bonusMultiplier;
  final int bonusXp;
  bool isCollected;

  LootCrate({
    required this.id,
    required this.type,
    required this.position,
    required this.spawnedAt,
    required this.expiresAt,
    this.bonusMultiplier = 1.5,
    this.bonusXp = 50,
    this.isCollected = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get title {
    switch (type) {
      case LootCrateType.shieldBattery:
        return 'Shield Battery';
      case LootCrateType.overchargeBeacon:
        return 'Overcharge Beacon';
      case LootCrateType.factionShard:
        return 'Faction XP Shards';
    }
  }

  String get description {
    switch (type) {
      case LootCrateType.shieldBattery:
        return 'Restores 20% territory shield integrity.';
      case LootCrateType.overchargeBeacon:
        return 'Doubles territory capture points for 500m.';
      case LootCrateType.factionShard:
        return '+50 Faction Shards for seasonal ranking.';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'spawnedAt': spawnedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'bonusMultiplier': bonusMultiplier,
    'bonusXp': bonusXp,
    'isCollected': isCollected,
  };

  factory LootCrate.fromJson(Map<String, dynamic> json) {
    return LootCrate(
      id: json['id'] as String,
      type: LootCrateType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LootCrateType.factionShard,
      ),
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      spawnedAt: DateTime.parse(json['spawnedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      bonusMultiplier: (json['bonusMultiplier'] as num?)?.toDouble() ?? 1.5,
      bonusXp: json['bonusXp'] as int? ?? 50,
      isCollected: json['isCollected'] as bool? ?? false,
    );
  }
}
