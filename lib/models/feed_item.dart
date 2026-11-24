import 'package:latlong2/latlong.dart';

/// Represents a completed run shared by a friend in the activity feed.
class FeedItem {
  final String id;
  final String userId;
  final String username;
  final String? faction;
  final String activityType;
  final int durationSeconds;
  final double distanceMeters;
  final double areaClaimed;
  final DateTime createdAt;
  final List<LatLng> routeThumbnail;
  final Map<String, int> kudosCounts;
  final String? myKudos;

  const FeedItem({
    required this.id,
    required this.userId,
    required this.username,
    this.faction,
    this.activityType = 'running',
    required this.durationSeconds,
    required this.distanceMeters,
    required this.areaClaimed,
    required this.createdAt,
    this.routeThumbnail = const [],
    this.kudosCounts = const {},
    this.myKudos,
  });

  /// Total count of all kudos and reactions combined.
  int get totalKudosCount {
    var total = 0;
    for (final count in kudosCounts.values) {
      total += count;
    }
    return total;
  }

  FeedItem copyWith({
    String? id,
    String? userId,
    String? username,
    String? faction,
    String? activityType,
    int? durationSeconds,
    double? distanceMeters,
    double? areaClaimed,
    DateTime? createdAt,
    List<LatLng>? routeThumbnail,
    Map<String, int>? kudosCounts,
    String? myKudos,
    bool clearMyKudos = false,
  }) {
    return FeedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      faction: faction ?? this.faction,
      activityType: activityType ?? this.activityType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      areaClaimed: areaClaimed ?? this.areaClaimed,
      createdAt: createdAt ?? this.createdAt,
      routeThumbnail: routeThumbnail ?? this.routeThumbnail,
      kudosCounts: kudosCounts ?? this.kudosCounts,
      myKudos: clearMyKudos ? null : (myKudos ?? this.myKudos),
    );
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final rawThumbnail = json['route_thumbnail'] as List<dynamic>? ?? [];
    final pts = <LatLng>[];
    for (final item in rawThumbnail) {
      if (item is List && item.length >= 2) {
        final lat = (item[0] as num).toDouble();
        final lng = (item[1] as num).toDouble();
        pts.add(LatLng(lat, lng));
      }
    }

    final rawKudos = json['kudos_counts'] as Map<String, dynamic>? ?? {};
    final counts = <String, int>{};
    rawKudos.forEach((key, value) {
      if (value is num) {
        counts[key] = value.toInt();
      }
    });

    return FeedItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Runner',
      faction: json['faction'] as String?,
      activityType: json['activity_type'] as String? ?? 'running',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      areaClaimed: (json['area_claimed'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      routeThumbnail: pts,
      kudosCounts: counts,
      myKudos: json['my_kudos'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'username': username,
    if (faction != null) 'faction': faction,
    'activity_type': activityType,
    'duration_seconds': durationSeconds,
    'distance_meters': distanceMeters,
    'area_claimed': areaClaimed,
    'created_at': createdAt.toIso8601String(),
    'route_thumbnail': routeThumbnail
        .map((pt) => [pt.latitude, pt.longitude])
        .toList(),
    'kudos_counts': kudosCounts,
    if (myKudos != null) 'my_kudos': myKudos,
  };
}
