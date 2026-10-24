import 'package:latlong2/latlong.dart';

import 'faction_standing.dart';

/// Live kinematic presence of a nearby runner broadcast over WebSocket
class RunnerPresenceEvent {
  final String userId;
  final String username;
  final String faction;
  final LatLng position;
  final double speed;
  final double heading;
  final DateTime updatedAt;

  const RunnerPresenceEvent({
    required this.userId,
    required this.username,
    required this.faction,
    required this.position,
    required this.speed,
    required this.heading,
    required this.updatedAt,
  });

  factory RunnerPresenceEvent.fromJson(Map<String, dynamic> json) {
    return RunnerPresenceEvent(
      userId: json['user_id'] as String? ?? 'unknown',
      username: json['username'] as String? ?? 'Runner',
      faction: FactionStanding.canonicalFaction(json['faction'] as String?),
      position: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0.0,
        (json['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Instant tactical alert received when a rival carves into the player's territory
class TerritoryAlertEvent {
  final String event;
  final String attackerId;
  final String attackerName;
  final double areaClaimedSqm;
  final String victimUserId;
  final String message;
  final DateTime timestamp;

  const TerritoryAlertEvent({
    required this.event,
    required this.attackerId,
    required this.attackerName,
    required this.areaClaimedSqm,
    required this.victimUserId,
    required this.message,
    required this.timestamp,
  });

  factory TerritoryAlertEvent.fromJson(Map<String, dynamic> json) {
    return TerritoryAlertEvent(
      event: json['event'] as String? ?? 'territory_carved',
      attackerId: json['attacker_id'] as String? ?? '',
      attackerName: json['attacker_name'] as String? ?? 'Rival Runner',
      areaClaimedSqm: (json['area_claimed_sqm'] as num?)?.toDouble() ?? 0.0,
      victimUserId: json['victim_user_id'] as String? ?? '',
      message: json['message'] as String? ?? 'Your territory was sliced!',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Global conquest newsfeed milestone received when any runner completes a conquest
class ConquestBroadcastEvent {
  final String event;
  final String attackerId;
  final String attackerName;
  final double areaClaimedSqm;
  final String message;
  final DateTime timestamp;

  const ConquestBroadcastEvent({
    required this.event,
    required this.attackerId,
    required this.attackerName,
    required this.areaClaimedSqm,
    required this.message,
    required this.timestamp,
  });

  factory ConquestBroadcastEvent.fromJson(Map<String, dynamic> json) {
    return ConquestBroadcastEvent(
      event: json['event'] as String? ?? 'territory_claimed',
      attackerId: json['attacker_id'] as String? ?? '',
      attackerName: json['attacker_name'] as String? ?? 'Runner',
      areaClaimedSqm: (json['area_claimed_sqm'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? 'New territory claimed!',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
