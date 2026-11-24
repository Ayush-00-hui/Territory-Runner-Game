import 'package:latlong2/latlong.dart';

/// Represents a persistent runner route or claimed territory loop that can be
/// followed again with live navigation cues, off-route alerts, and completion tracking.
class SavedLoop {
  final String id;
  final String name;
  final List<LatLng> points;
  final double distanceMeters;
  final double areaSqMeters;
  final DateTime createdAt;
  final int? bestTimeSeconds;
  final int runCount;

  const SavedLoop({
    required this.id,
    required this.name,
    required this.points,
    required this.distanceMeters,
    required this.areaSqMeters,
    required this.createdAt,
    this.bestTimeSeconds,
    this.runCount = 0,
  });

  SavedLoop copyWith({
    String? id,
    String? name,
    List<LatLng>? points,
    double? distanceMeters,
    double? areaSqMeters,
    DateTime? createdAt,
    int? bestTimeSeconds,
    int? runCount,
  }) {
    return SavedLoop(
      id: id ?? this.id,
      name: name ?? this.name,
      points: points ?? this.points,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      areaSqMeters: areaSqMeters ?? this.areaSqMeters,
      createdAt: createdAt ?? this.createdAt,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
      runCount: runCount ?? this.runCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'distanceMeters': distanceMeters,
    'areaSqMeters': areaSqMeters,
    'createdAt': createdAt.toIso8601String(),
    'bestTimeSeconds': bestTimeSeconds,
    'runCount': runCount,
  };

  factory SavedLoop.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List? ?? [];
    final points = rawPoints.map((p) {
      final map = p as Map<String, dynamic>;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    }).toList();

    return SavedLoop(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Saved Loop',
      points: points,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      areaSqMeters: (json['areaSqMeters'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      bestTimeSeconds: json['bestTimeSeconds'] as int?,
      runCount: (json['runCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Real-time navigation telemetry when following a saved loop.
class SavedLoopProgress {
  /// Estimated progress along the loop from 0.0 (start) to 1.0 (finished).
  final double progressFraction;

  /// Perpendicular distance from runner's current location to nearest route segment (meters).
  final double distanceToRouteMeters;

  /// True if runner has drifted farther than the off-route threshold (>40m).
  final bool isOffRoute;

  /// Distance remaining along the planned loop to reach completion (meters).
  final double remainingDistanceMeters;

  const SavedLoopProgress({
    required this.progressFraction,
    required this.distanceToRouteMeters,
    required this.isOffRoute,
    required this.remainingDistanceMeters,
  });
}
