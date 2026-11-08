import 'dart:math' as math;

/// Single point sample within a completed athletic run log.
class RunSample {
  /// Milliseconds elapsed since the start of the run session.
  final int timeOffsetMs;
  final double lat;
  final double lng;
  final double? altitude;
  final double? accuracy;

  const RunSample({
    required this.timeOffsetMs,
    required this.lat,
    required this.lng,
    this.altitude,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
    't': timeOffsetMs,
    'lat': lat,
    'lng': lng,
    if (altitude != null) 'alt': altitude,
    if (accuracy != null) 'acc': accuracy,
  };

  factory RunSample.fromJson(Map<String, dynamic> json) => RunSample(
    timeOffsetMs: (json['t'] as num).toInt(),
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    altitude: (json['alt'] as num?)?.toDouble(),
    accuracy: (json['acc'] as num?)?.toDouble(),
  );
}

/// Cadence statistics captured during an athletic run session.
class CadenceStats {
  final double averageSpm;
  final double maxSpm;
  final double confidence;

  const CadenceStats({
    required this.averageSpm,
    required this.maxSpm,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'avg': averageSpm,
    'max': maxSpm,
    'conf': confidence,
  };

  factory CadenceStats.fromJson(Map<String, dynamic> json) => CadenceStats(
    averageSpm: (json['avg'] as num).toDouble(),
    maxSpm: (json['max'] as num).toDouble(),
    confidence: (json['conf'] as num).toDouble(),
  );
}

/// Authoritative encrypted on-device record of a completed athletic run session.
class RunLogEntry {
  static const int currentVersion = 1;

  final int version;

  /// Unique session identifier, identical to the sync idempotency key.
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String activityType;
  final int movingSeconds;
  final int totalSeconds;
  final double distanceM;
  final List<RunSample> samples;
  final int? stepCount;
  final CadenceStats? cadenceStats;

  /// Physiological calorie expenditure estimate (stored exclusively on device).
  final int? calories;

  /// Version of the calorie model engine used for the estimate.
  final String? calorieModelVersion;

  final double? elevationGainM;
  final double? elevationLossM;
  final double claimedAreaSqM;
  final int xp;
  final String syncStatus;

  /// Indicates whether dense raw GPS samples were simplified via Douglas-Peucker.
  final bool isSimplified;

  const RunLogEntry({
    this.version = currentVersion,
    required this.id,
    required this.startedAt,
    required this.endedAt,
    this.activityType = 'running',
    required this.movingSeconds,
    required this.totalSeconds,
    required this.distanceM,
    required this.samples,
    this.stepCount,
    this.cadenceStats,
    this.calories,
    this.calorieModelVersion,
    this.elevationGainM,
    this.elevationLossM,
    this.claimedAreaSqM = 0.0,
    this.xp = 0,
    this.syncStatus = 'synced',
    this.isSimplified = false,
  });

  /// Average moving pace in seconds per kilometer (0 if distance <= 0).
  double get paceSecondsPerKm {
    if (distanceM <= 0 || movingSeconds <= 0) return 0.0;
    return (movingSeconds / (distanceM / 1000.0));
  }

  /// Average moving pace in seconds per mile (0 if distance <= 0).
  double get paceSecondsPerMile {
    if (distanceM <= 0 || movingSeconds <= 0) return 0.0;
    return (movingSeconds / (distanceM / 1609.344));
  }

  RunLogEntry copyWith({
    int? version,
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    String? activityType,
    int? movingSeconds,
    int? totalSeconds,
    double? distanceM,
    List<RunSample>? samples,
    int? stepCount,
    CadenceStats? cadenceStats,
    int? calories,
    String? calorieModelVersion,
    double? elevationGainM,
    double? elevationLossM,
    double? claimedAreaSqM,
    int? xp,
    String? syncStatus,
    bool? isSimplified,
  }) {
    return RunLogEntry(
      version: version ?? this.version,
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      activityType: activityType ?? this.activityType,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      distanceM: distanceM ?? this.distanceM,
      samples: samples ?? this.samples,
      stepCount: stepCount ?? this.stepCount,
      cadenceStats: cadenceStats ?? this.cadenceStats,
      calories: calories ?? this.calories,
      calorieModelVersion: calorieModelVersion ?? this.calorieModelVersion,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      elevationLossM: elevationLossM ?? this.elevationLossM,
      claimedAreaSqM: claimedAreaSqM ?? this.claimedAreaSqM,
      xp: xp ?? this.xp,
      syncStatus: syncStatus ?? this.syncStatus,
      isSimplified: isSimplified ?? this.isSimplified,
    );
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'id': id,
    'start': startedAt.toIso8601String(),
    'end': endedAt.toIso8601String(),
    'act': activityType,
    'mov_sec': movingSeconds,
    'tot_sec': totalSeconds,
    'dist_m': distanceM,
    'samples': samples.map((s) => s.toJson()).toList(),
    if (stepCount != null) 'steps': stepCount,
    if (cadenceStats != null) 'cad': cadenceStats!.toJson(),
    if (calories != null) 'cal': calories,
    if (calorieModelVersion != null) 'cal_v': calorieModelVersion,
    if (elevationGainM != null) 'ele_gain': elevationGainM,
    if (elevationLossM != null) 'ele_loss': elevationLossM,
    'area_sqm': claimedAreaSqM,
    'xp': xp,
    'sync': syncStatus,
    'simp': isSimplified,
  };

  factory RunLogEntry.fromJson(Map<String, dynamic> json) {
    final rawSamples = (json['samples'] as List<dynamic>? ?? []);
    final samples = rawSamples
        .map((s) => RunSample.fromJson(s as Map<String, dynamic>))
        .toList();

    return RunLogEntry(
      version: (json['v'] as num?)?.toInt() ?? 1,
      id: json['id'] as String,
      startedAt: DateTime.parse(json['start'] as String),
      endedAt: DateTime.parse(json['end'] as String),
      activityType: json['act'] as String? ?? 'running',
      movingSeconds: (json['mov_sec'] as num).toInt(),
      totalSeconds: (json['tot_sec'] as num).toInt(),
      distanceM: (json['dist_m'] as num).toDouble(),
      samples: samples,
      stepCount: (json['steps'] as num?)?.toInt(),
      cadenceStats: json['cad'] != null
          ? CadenceStats.fromJson(json['cad'] as Map<String, dynamic>)
          : null,
      calories: (json['cal'] as num?)?.toInt(),
      calorieModelVersion: json['cal_v'] as String?,
      elevationGainM: (json['ele_gain'] as num?)?.toDouble(),
      elevationLossM: (json['ele_loss'] as num?)?.toDouble(),
      claimedAreaSqM: (json['area_sqm'] as num?)?.toDouble() ?? 0.0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      syncStatus: json['sync'] as String? ?? 'synced',
      isSimplified: json['simp'] as bool? ?? false,
    );
  }
}

/// Classic Douglas-Peucker polyline simplification algorithm adapted for geospatial samples.
List<RunSample> douglasPeucker(List<RunSample> points, double epsilonMeters) {
  if (points.length <= 2) return List<RunSample>.from(points);

  double maxDistance = 0.0;
  int index = 0;

  final first = points.first;
  final last = points.last;

  for (int i = 1; i < points.length - 1; i++) {
    final d = _perpendicularDistanceMeters(points[i], first, last);
    if (d > maxDistance) {
      maxDistance = d;
      index = i;
    }
  }

  if (maxDistance > epsilonMeters) {
    final left = douglasPeucker(points.sublist(0, index + 1), epsilonMeters);
    final right = douglasPeucker(points.sublist(index), epsilonMeters);
    return [...left.sublist(0, left.length - 1), ...right];
  } else {
    return [first, last];
  }
}

double _perpendicularDistanceMeters(
  RunSample p,
  RunSample lineStart,
  RunSample lineEnd,
) {
  const earthRadius = 6371000.0;
  final latMid = (lineStart.lat + lineEnd.lat) / 2.0 * math.pi / 180.0;
  final cosLat = math.cos(latMid);

  final xEnd =
      (lineEnd.lng - lineStart.lng) * math.pi / 180.0 * earthRadius * cosLat;
  final yEnd = (lineEnd.lat - lineStart.lat) * math.pi / 180.0 * earthRadius;

  final xP = (p.lng - lineStart.lng) * math.pi / 180.0 * earthRadius * cosLat;
  final yP = (p.lat - lineStart.lat) * math.pi / 180.0 * earthRadius;

  final lengthSq = xEnd * xEnd + yEnd * yEnd;
  if (lengthSq == 0) {
    return math.sqrt(xP * xP + yP * yP);
  }

  final t = (xP * xEnd + yP * yEnd) / lengthSq;
  if (t < 0.0) {
    return math.sqrt(xP * xP + yP * yP);
  } else if (t > 1.0) {
    final dx = xP - xEnd;
    final dy = yP - yEnd;
    return math.sqrt(dx * dx + dy * dy);
  }

  final numerator = (xP * yEnd - yP * xEnd).abs();
  return numerator / math.sqrt(lengthSq);
}
