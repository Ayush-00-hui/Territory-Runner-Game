import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/logging/app_logger.dart';
import '../../models/activity_type.dart';

/// Event dispatched when a runner closes an arbitrary GPS loop
class EnclosedLoopEvent {
  final List<LatLng> polygon;
  final double areaSqMeters;
  final double areaSqKm;
  final double loopDistanceMeters;
  final DateTime closedAt;

  EnclosedLoopEvent({
    required this.polygon,
    required this.areaSqMeters,
    required this.areaSqKm,
    required this.loopDistanceMeters,
    required this.closedAt,
  });
}

/// Real-time proximity candidate information for live UI closure guidance.
class ClosureProximityCandidate {
  final int candidateIndex;
  final LatLng candidatePoint;
  final double distanceMeters;
  final double closureThresholdMeters;
  final double loopPathDistanceMeters;
  final double proximity; // 0.0 (far / 120m) to 1.0 (at closure threshold)

  const ClosureProximityCandidate({
    required this.candidateIndex,
    required this.candidatePoint,
    required this.distanceMeters,
    required this.closureThresholdMeters,
    required this.loopPathDistanceMeters,
    required this.proximity,
  });
}

/// Arbitrary Shape Polygon Territory Enclosure Engine
/// Continuously tracks GPS breadcrumbs, detects loop closures (<= 35m),
/// filters satellite multipath outliers (> 35 km/h for running, 60 km/h for cycling, 15 km/h for walking),
/// and computes accurate geodesic surface area via the Shoelace Formula on a local equirectangular tangent plane.
class PolygonEnclosureEngine {
  final List<LatLng> _path = [];
  final List<DateTime> _timestamps = [];
  LatLng? _lastReceivedPosition;
  DateTime? _lastReceivedTimestamp;
  String? _lastInvalidReason;

  // Enclosure configuration parameters
  final double
  minClosureDistanceMeters; // Proximity threshold to trigger closed loop
  final int minPointsRequired; // Minimum path nodes for a valid loop
  final double? _minLoopDistanceMetersOverride; // Explicit override
  final double? _minLoopAreaSqMetersOverride; // Explicit override
  final double maxLoopAreaSqMeters; // Maximum single-loop area (matches Go server: 5,000,000 m²)
  final double? maxSpeedKmhOutlier; // Explicit outlier ceiling override
  final double
  maxSignalGapSeconds; // Max gap before track segmentation (default: 15s)
  final double maxPauseDisplacementMeters; // Max straight-line displacement across gap to treat as pause (default: 50m)
  final double maxPauseDurationSeconds; // Max pause duration before reset (default: 600s / 10 min)
  ExerciseActivityType? activityType; // Activity mode calibrating thresholds

  /// Rejection messages matching Go backend's errors.
  static const String loopTooLargeReason =
      'Loop area exceeds maximum allowable single run threshold (5000000 m²)';
  static const String loopPerimeterTooSmallReason =
      'Loop perimeter below minimum threshold';
  static const String loopAreaTooSmallReason =
      'Loop area below minimum threshold';
  static const String signalGapReason =
      'GPS signal interrupted (>15s gap) — path reset to prevent inaccurate enclosure';
  static const String loopTooThinReason = 'Loop too thin';

  PolygonEnclosureEngine({
    this.minClosureDistanceMeters = 35.0,
    this.minPointsRequired = 4,
    double? minLoopDistanceMeters,
    double? minLoopAreaSqMeters,
    this.maxLoopAreaSqMeters = 5000000.0,
    this.maxSpeedKmhOutlier,
    this.maxSignalGapSeconds = 15.0,
    this.maxPauseDisplacementMeters = 50.0,
    this.maxPauseDurationSeconds = 600.0,
    this.activityType,
  }) : _minLoopDistanceMetersOverride = minLoopDistanceMeters,
       _minLoopAreaSqMetersOverride = minLoopAreaSqMeters;

  void setActivityType(ExerciseActivityType type) {
    activityType = type;
  }

  /// Authoritative kinematic outlier filter ceiling (km/h) for the active exercise modality.
  double get effectiveMaxSpeedOutlier {
    if (maxSpeedKmhOutlier != null) return maxSpeedKmhOutlier!;
    switch (activityType ?? ExerciseActivityType.running) {
      case ExerciseActivityType.walking:
        return 15.0;
      case ExerciseActivityType.cycling:
        return 60.0;
      case ExerciseActivityType.running:
        return 35.0;
    }
  }

  /// Authoritative perimeter threshold (meters) for the active exercise modality:
  /// Walking: 40m, Running: 60m, Cycling: 150m
  double get effectiveMinLoopDistanceMeters {
    if (_minLoopDistanceMetersOverride != null) {
      return _minLoopDistanceMetersOverride;
    }
    switch (activityType ?? ExerciseActivityType.running) {
      case ExerciseActivityType.walking:
        return 40.0;
      case ExerciseActivityType.cycling:
        return 150.0;
      case ExerciseActivityType.running:
        return 60.0;
    }
  }

  /// Authoritative loop area threshold (m²) for the active exercise modality:
  /// Walking: 100 m², Running: 200 m², Cycling: 1000 m²
  double get effectiveMinLoopAreaSqMeters {
    if (_minLoopAreaSqMetersOverride != null) {
      return _minLoopAreaSqMetersOverride;
    }
    switch (activityType ?? ExerciseActivityType.running) {
      case ExerciseActivityType.walking:
        return 100.0;
      case ExerciseActivityType.cycling:
        return 1000.0;
      case ExerciseActivityType.running:
        return 200.0;
    }
  }

  double get minLoopDistanceMeters => effectiveMinLoopDistanceMeters;
  double get minLoopAreaSqMeters => effectiveMinLoopAreaSqMeters;

  /// Dynamically scaled loop closure threshold based on satellite horizontal accuracy dilution.
  /// Standard phone GPS (~10m accuracy) resolves to exactly [minClosureDistanceMeters] (35.0m).
  /// Sub-meter / high-precision GNSS (< 5m) tightens down to ~33.0m (minimum 25.0m).
  /// Urban canyon / multipath accuracy (15-25m) scales gracefully up to 41.0m (capped at 50.0m).
  double effectiveClosureDistance({double? horizontalAccuracyMeters}) {
    if (horizontalAccuracyMeters == null || horizontalAccuracyMeters <= 0.0) {
      return minClosureDistanceMeters;
    }
    final scaled =
        minClosureDistanceMeters + (horizontalAccuracyMeters - 10.0) * 0.4;
    return scaled.clamp(25.0, 50.0);
  }

  List<LatLng> get currentPath => List.unmodifiable(_path);
  int get pointCount => _path.length;
  String? get lastInvalidReason => _lastInvalidReason;

  void clear() {
    _path.clear();
    _timestamps.clear();
    _lastReceivedPosition = null;
    _lastReceivedTimestamp = null;
    _lastInvalidReason = null;
  }

  /// Scans active path vertices to locate the nearest eligible candidate vertex for closing a loop.
  /// An eligible candidate is an earlier vertex whose path distance to [currentPos] satisfies
  /// [effectiveMinLoopDistanceMeters]. Returns null if no eligible candidate is within [maxDetectionDistanceMeters] (default: 120m).
  ClosureProximityCandidate? findNearestClosureCandidate(
    LatLng currentPos, {
    double? horizontalAccuracyMeters,
    double maxDetectionDistanceMeters = 120.0,
  }) {
    if (_path.length < minPointsRequired) return null;
    final int n = _path.length;
    final double closureThreshold = effectiveClosureDistance(
      horizontalAccuracyMeters: horizontalAccuracyMeters,
    );

    ClosureProximityCandidate? best;
    double minDistance = maxDetectionDistanceMeters;
    double accumulatedLoopDist = 0.0;

    for (int i = n - 2; i >= 0; i--) {
      accumulatedLoopDist += haversineDistanceMeters(_path[i], _path[i + 1]);
      if (accumulatedLoopDist < effectiveMinLoopDistanceMeters) {
        continue;
      }
      final candidatePoint = _path[i];
      final dist = haversineDistanceMeters(currentPos, candidatePoint);
      if (dist < minDistance) {
        minDistance = dist;
        final proximity =
            (1.0 -
                    ((dist - closureThreshold) /
                        (maxDetectionDistanceMeters - closureThreshold)))
                .clamp(0.0, 1.0);
        best = ClosureProximityCandidate(
          candidateIndex: i,
          candidatePoint: candidatePoint,
          distanceMeters: dist,
          closureThresholdMeters: closureThreshold,
          loopPathDistanceMeters: accumulatedLoopDist,
          proximity: proximity,
        );
      }
    }
    return best;
  }

  /// Manual "SEAL CURRENT SHAPE" override action.
  /// Force-closes the active GPS path into a player territory polygon.
  /// If [candidateIndex] is specified, seals the loop from [candidateIndex] to the current end.
  /// Otherwise, if a near candidate is detected, seals to that candidate; else seals back to start.
  EnclosedLoopEvent? sealCurrentPath({int? candidateIndex}) {
    _lastInvalidReason = null;
    if (_path.length < 3) return null;

    final now = DateTime.now();
    int startIdx = candidateIndex ?? 0;
    if (candidateIndex == null && _path.length >= minPointsRequired) {
      final candidate = findNearestClosureCandidate(_path.last);
      if (candidate != null && candidate.candidateIndex > 0) {
        startIdx = candidate.candidateIndex;
      }
    }

    final List<LatLng> closedPoints = List<LatLng>.from(
      startIdx == 0 ? _path : _path.sublist(startIdx),
    );
    // Connect back to the first vertex if not already adjacent
    if (closedPoints.first.latitude != closedPoints.last.latitude ||
        closedPoints.first.longitude != closedPoints.last.longitude) {
      closedPoints.add(closedPoints.first);
    }

    if (hasSelfIntersection(closedPoints)) {
      _lastInvalidReason = 'Loop crossed itself — try again';
      AppLogger.debug(
        'Manual seal rejected: $_lastInvalidReason',
        tag: 'PolygonEnclosureEngine',
      );
      return null;
    }

    final loopLength = _calculatePathDistance(closedPoints);
    if (loopLength < effectiveMinLoopDistanceMeters) {
      _lastInvalidReason = loopPerimeterTooSmallReason;
      AppLogger.debug(
        'Manual seal rejected: $_lastInvalidReason',
        tag: 'PolygonEnclosureEngine',
      );
      return null;
    }

    final areaSqM = computeGeodesicShoelaceArea(closedPoints);
    final areaSqKm = areaSqM / 1000000.0;

    if (areaSqM < effectiveMinLoopAreaSqMeters) {
      _lastInvalidReason = loopAreaTooSmallReason;
      AppLogger.debug(
        'Manual seal rejected: $_lastInvalidReason',
        tag: 'PolygonEnclosureEngine',
      );
      return null;
    }

    if (areaSqM > maxLoopAreaSqMeters) {
      _lastInvalidReason = loopTooLargeReason;
      AppLogger.debug(
        'Manual seal rejected: $_lastInvalidReason',
        tag: 'PolygonEnclosureEngine',
      );
      return null;
    }

    // Isoperimetric quotient check: reject loops with thinness < 0.02
    final thinness = computeThinness(closedPoints);
    if (thinness < 0.02) {
      _lastInvalidReason = loopTooThinReason;
      AppLogger.debug(
        'Manual seal rejected: $_lastInvalidReason',
        tag: 'PolygonEnclosureEngine',
      );
      return null;
    }

    final event = EnclosedLoopEvent(
      polygon: closedPoints,
      areaSqMeters: areaSqM,
      areaSqKm: areaSqKm,
      loopDistanceMeters: loopLength,
      closedAt: now,
    );

    AppLogger.info(
      'Manually SEALED current shape! Points: ${closedPoints.length}, Perimeter: ${loopLength.toStringAsFixed(1)}m, Area: ${areaSqM.toStringAsFixed(1)}m²',
      tag: 'PolygonEnclosureEngine',
    );

    final lastPos = _path.last;
    if (startIdx > 0) {
      final remainingPath = _path.sublist(0, startIdx + 1);
      final remainingTimestamps = _timestamps.sublist(0, startIdx + 1);
      _path.clear();
      _timestamps.clear();
      _path.addAll(remainingPath);
      _timestamps.addAll(remainingTimestamps);
    } else {
      _path.clear();
      _timestamps.clear();
      _path.add(lastPos);
      _timestamps.add(now);
    }

    return event;
  }

  /// Ingests a new GPS position and checks for arbitrary polygon loop enclosure.
  /// Dynamically scales loop closure distance based on [horizontalAccuracyMeters].
  /// Returns [EnclosedLoopEvent] if a valid loop was closed, or null otherwise.
  EnclosedLoopEvent? addPosition(
    LatLng position, [
    DateTime? timestamp,
    double? horizontalAccuracyMeters,
  ]) {
    _lastInvalidReason = null;
    final now = timestamp ?? DateTime.now();

    // 0. GPS Signal Gap Guard: Gaps > maxSignalGapSeconds (15s) segment the track.
    // Displacement-aware: if gap > 15s but straight-line distance from last path point <= 50m,
    // treat as a pause: keep the path, do not reset, do not count the gap as movement.
    // Reset if displacement > 50m or gap > 10 minutes (600s).
    if (_timestamps.isNotEmpty && _path.isNotEmpty) {
      final double gapSec =
          (now.difference(_timestamps.last).inMilliseconds / 1000.0).abs();
      if (gapSec > maxSignalGapSeconds) {
        final double displacement = haversineDistanceMeters(
          _path.last,
          position,
        );
        if (gapSec > maxPauseDurationSeconds ||
            displacement > maxPauseDisplacementMeters) {
          _lastInvalidReason = signalGapReason;
          _path.clear();
          _timestamps.clear();
          _path.add(position);
          _timestamps.add(now);
          _lastReceivedPosition = position;
          _lastReceivedTimestamp = now;
          AppLogger.info(
            'GPS signal interrupted (${gapSec.toStringAsFixed(1)}s gap, ${displacement.toStringAsFixed(1)}m displacement) — path reset',
            tag: 'PolygonEnclosureEngine',
          );
          return null;
        }
      }
    }

    // 1. Discard satellite multipath outlier jumps against immediately preceding sample
    if (_lastReceivedTimestamp != null && _lastReceivedPosition != null) {
      final double dtSec =
          (now.difference(_lastReceivedTimestamp!).inMilliseconds / 1000.0)
              .abs();
      if (dtSec >= 0.5 && dtSec <= 5.0) {
        final double stepDist = haversineDistanceMeters(
          _lastReceivedPosition!,
          position,
        );
        final double speedKmh = (stepDist / dtSec) * 3.6;
        if (speedKmh > effectiveMaxSpeedOutlier) {
          _lastReceivedPosition = position;
          _lastReceivedTimestamp = now;
          AppLogger.debug(
            'Jitter outlier rejected: ${speedKmh.toStringAsFixed(1)} km/h (ceiling: $effectiveMaxSpeedOutlier km/h)',
            tag: 'PolygonEnclosureEngine',
          );
          return null;
        }
      }
    }
    _lastReceivedPosition = position;
    _lastReceivedTimestamp = now;

    if (_path.isNotEmpty) {
      final lastPoint = _path.last;
      final distFromLast = haversineDistanceMeters(lastPoint, position);

      // Filter out stationary noise (< 1.8 meters)
      if (distFromLast < 1.8) {
        return null;
      }
    }

    _path.add(position);
    _timestamps.add(now);

    // Need enough vertices to evaluate closed loop
    if (_path.length < minPointsRequired) {
      return null;
    }

    final currentIndex = _path.length - 1;
    final currentPos = _path[currentIndex];

    // --- 1. LASSO CLOSURE CHECK ---
    // If newest path segment properly crosses an earlier segment (not adjacent),
    // close the loop at the intersection point:
    // polygon = [intersection point, path vertices after crossed segment ... current vertex, intersection point]
    if (_path.length >= 4) {
      final pLast1 = _path[currentIndex - 1];
      final pLast2 = currentPos;

      EnclosedLoopEvent? bestLassoEvent;
      int? bestLassoJ;
      LatLng? bestLassoIntersection;
      double maxLassoArea = -1.0;

      for (int j = 0; j <= currentIndex - 3; j++) {
        final pEarly1 = _path[j];
        final pEarly2 = _path[j + 1];

        if (doSegmentsIntersect(pEarly1, pEarly2, pLast1, pLast2)) {
          final intersection = computeIntersectionPoint(
            pEarly1,
            pEarly2,
            pLast1,
            pLast2,
          );
          if (intersection != null) {
            final lassoPoints = <LatLng>[intersection];
            for (int k = j + 1; k < currentIndex; k++) {
              lassoPoints.add(_path[k]);
            }
            lassoPoints.add(intersection);

            final loopLength = _calculatePathDistance(lassoPoints);
            if (loopLength >= effectiveMinLoopDistanceMeters &&
                !hasSelfIntersection(lassoPoints)) {
              final areaSqM = computeGeodesicShoelaceArea(lassoPoints);
              if (areaSqM >= effectiveMinLoopAreaSqMeters &&
                  areaSqM <= maxLoopAreaSqMeters &&
                  areaSqM > maxLassoArea) {
                maxLassoArea = areaSqM;
                bestLassoJ = j;
                bestLassoIntersection = intersection;
                bestLassoEvent = EnclosedLoopEvent(
                  polygon: lassoPoints,
                  areaSqMeters: areaSqM,
                  areaSqKm: areaSqM / 1000000.0,
                  loopDistanceMeters: loopLength,
                  closedAt: now,
                );
              }
            }
          }
        }
      }

      if (bestLassoEvent != null &&
          bestLassoJ != null &&
          bestLassoIntersection != null) {
        AppLogger.info(
          'Lasso loop closed at intersection! Points: ${bestLassoEvent.polygon.length}, Perimeter: ${bestLassoEvent.loopDistanceMeters.toStringAsFixed(1)}m, Area: ${bestLassoEvent.areaSqMeters.toStringAsFixed(1)}m²',
          tag: 'PolygonEnclosureEngine',
        );

        // Keep the tail before the crossing as the remaining path
        final newPath = <LatLng>[];
        final newTimestamps = <DateTime>[];
        for (int k = 0; k <= bestLassoJ; k++) {
          newPath.add(_path[k]);
          newTimestamps.add(_timestamps[k]);
        }
        newPath.add(bestLassoIntersection);
        final dTotal = haversineDistanceMeters(
          _path[bestLassoJ],
          _path[bestLassoJ + 1],
        );
        final dPart = haversineDistanceMeters(
          _path[bestLassoJ],
          bestLassoIntersection,
        );
        final fraction = dTotal > 1e-6 ? (dPart / dTotal).clamp(0.0, 1.0) : 0.0;
        final tEarly1 = _timestamps[bestLassoJ];
        final tEarly2 = _timestamps[bestLassoJ + 1];
        final intMillis =
            tEarly1.millisecondsSinceEpoch +
            ((tEarly2.millisecondsSinceEpoch - tEarly1.millisecondsSinceEpoch) *
                    fraction)
                .round();
        newTimestamps.add(DateTime.fromMillisecondsSinceEpoch(intMillis));

        _path.clear();
        _timestamps.clear();
        _path.addAll(newPath);
        _timestamps.addAll(newTimestamps);
        _lastInvalidReason = null;

        return bestLassoEvent;
      }
    }

    // --- 2. PROXIMITY CLOSURE CHECK ---
    // Try ALL candidate start indices, accept the best valid loop
    EnclosedLoopEvent? bestProximityEvent;
    double maxProximityArea = -1.0;
    String? candidateFailureReason;

    for (int i = 0; i <= currentIndex - minPointsRequired; i++) {
      final candidatePoint = _path[i];
      final distance = haversineDistanceMeters(currentPos, candidatePoint);

      final closureThreshold = effectiveClosureDistance(
        horizontalAccuracyMeters: horizontalAccuracyMeters,
      );
      if (distance <= closureThreshold) {
        final loopPoints = List<LatLng>.from(
          _path.sublist(i, currentIndex + 1),
        );
        final loopLength = _calculatePathDistance(loopPoints);

        if (loopLength < effectiveMinLoopDistanceMeters) {
          candidateFailureReason ??= loopPerimeterTooSmallReason;
          continue;
        }

        if (hasSelfIntersection(loopPoints)) {
          candidateFailureReason = 'Loop crossed itself — try again';
          continue;
        }

        final areaSqM = computeGeodesicShoelaceArea(loopPoints);
        if (areaSqM < effectiveMinLoopAreaSqMeters) {
          candidateFailureReason = loopAreaTooSmallReason;
          continue;
        }

        if (areaSqM > maxLoopAreaSqMeters) {
          candidateFailureReason = loopTooLargeReason;
          continue;
        }

        final thinness = computeThinness(loopPoints);
        if (thinness < 0.02) {
          candidateFailureReason = loopTooThinReason;
          continue;
        }

        if (areaSqM > maxProximityArea) {
          maxProximityArea = areaSqM;
          bestProximityEvent = EnclosedLoopEvent(
            polygon: loopPoints,
            areaSqMeters: areaSqM,
            areaSqKm: areaSqM / 1000000.0,
            loopDistanceMeters: loopLength,
            closedAt: now,
          );
        }
      }
    }

    if (bestProximityEvent != null) {
      AppLogger.info(
        'Closed loop detected! Points: ${bestProximityEvent.polygon.length}, Perimeter: ${bestProximityEvent.loopDistanceMeters.toStringAsFixed(1)}m, Area: ${bestProximityEvent.areaSqMeters.toStringAsFixed(1)}m²',
        tag: 'PolygonEnclosureEngine',
      );

      _path.clear();
      _timestamps.clear();
      _path.add(position);
      _timestamps.add(now);
      _lastInvalidReason = null;

      return bestProximityEvent;
    }

    if (candidateFailureReason != null) {
      _lastInvalidReason = candidateFailureReason;
    }

    return null;
  }

  /// Computes the exact 2D planar intersection point of segments (p1->p2) and (p3->p4).
  /// Returns null if the segments are parallel or do not properly intersect.
  static LatLng? computeIntersectionPoint(
    LatLng p1,
    LatLng p2,
    LatLng p3,
    LatLng p4,
  ) {
    final x1 = p1.longitude;
    final y1 = p1.latitude;
    final x2 = p2.longitude;
    final y2 = p2.latitude;
    final x3 = p3.longitude;
    final y3 = p3.latitude;
    final x4 = p4.longitude;
    final y4 = p4.latitude;

    final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denom.abs() < 1e-12) return null;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    final u = ((x1 - x3) * (y1 - y2) - (y1 - y3) * (x1 - x2)) / denom;

    if (t > 1e-9 && t < 1.0 - 1e-9 && u > 1e-9 && u < 1.0 - 1e-9) {
      final intLng = x1 + t * (x2 - x1);
      final intLat = y1 + t * (y2 - y1);
      return LatLng(intLat, intLng);
    }
    return null;
  }

  /// Computes the isoperimetric quotient thinness: 4 * pi * Area / Perimeter^2.
  static double computeThinness(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    double perimeter = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      perimeter += haversineDistanceMeters(points[i], points[i + 1]);
    }
    if (perimeter <= 0.0) return 0.0;
    final area = computeGeodesicShoelaceArea(points);
    return (4.0 * math.pi * area) / (perimeter * perimeter);
  }

  /// Checks if line segments (p1->p2) and (p3->p4) properly cross or overlap collinearly
  static bool doSegmentsIntersect(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    double ccw(LatLng a, LatLng b, LatLng c) {
      return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
          (b.latitude - a.latitude) * (c.longitude - a.longitude);
    }

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    if (((d1 > 1e-13 && d2 < -1e-13) || (d1 < -1e-13 && d2 > 1e-13)) &&
        ((d3 > 1e-13 && d4 < -1e-13) || (d3 < -1e-13 && d4 > 1e-13))) {
      return true;
    }

    // Collinear overlap check
    if (d1.abs() <= 1e-13 &&
        d2.abs() <= 1e-13 &&
        d3.abs() <= 1e-13 &&
        d4.abs() <= 1e-13) {
      final dx = p2.longitude - p1.longitude;
      final dy = p2.latitude - p1.latitude;
      final lenSq = dx * dx + dy * dy;
      if (lenSq > 1e-18) {
        final t3 =
            ((p3.longitude - p1.longitude) * dx +
                (p3.latitude - p1.latitude) * dy) /
            lenSq;
        final t4 =
            ((p4.longitude - p1.longitude) * dx +
                (p4.latitude - p1.latitude) * dy) /
            lenSq;
        final minT = math.min(t3, t4);
        final maxT = math.max(t3, t4);
        final overlapStart = math.max(0.0, minT);
        final overlapEnd = math.min(1.0, maxT);
        if (overlapEnd - overlapStart > 1e-6) {
          return true;
        }
      }
    }

    return false;
  }

  /// Validates whether a closed or open polygon path contains self-intersections or foldback spurs
  static bool hasSelfIntersection(List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    final int n = polygon.length;

    // 1. Check for 180-degree foldbacks on adjacent segments
    for (int i = 0; i < n - 2; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      final p3 = polygon[i + 2];
      final dx1 = p2.longitude - p1.longitude;
      final dy1 = p2.latitude - p1.latitude;
      final dx2 = p3.longitude - p2.longitude;
      final dy2 = p3.latitude - p2.latitude;
      final cross = dx1 * dy2 - dy1 * dx2;
      final dot = dx1 * dx2 + dy1 * dy2;
      if (cross.abs() < 1e-12 && dot < -1e-12) {
        return true; // 180-degree foldback spur
      }
    }

    // 2. Check for intersections and collinear overlaps between non-adjacent segments
    for (int i = 0; i < n - 1; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      for (int j = i + 2; j < n - 1; j++) {
        if (i == 0 && j == n - 2) {
          continue; // Ignore shared start-end vertex in closed ring
        }
        final p3 = polygon[j];
        final p4 = polygon[j + 1];
        if (doSegmentsIntersect(p1, p2, p3, p4)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Calculates total linear path distance in meters using geodesic Haversine
  double _calculatePathDistance(List<LatLng> points) {
    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += haversineDistanceMeters(points[i], points[i + 1]);
    }
    return totalDistance;
  }

  /// High-precision Haversine geodesic distance in meters on WGS84 sphere
  static double haversineDistanceMeters(LatLng p1, LatLng p2) {
    const double earthRadius = 6378137.0;
    final double dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final double dLng = (p2.longitude - p1.longitude) * (math.pi / 180.0);
    final double lat1 = p1.latitude * (math.pi / 180.0);
    final double lat2 = p2.latitude * (math.pi / 180.0);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final double c =
        2 *
        math.atan2(
          math.sqrt(a.clamp(0.0, 1.0)),
          math.sqrt((1 - a).clamp(0.0, 1.0)),
        );
    return earthRadius * c;
  }

  /// Calculates exact surface area of an arbitrary polygon in square meters
  /// using the Geodesic Shoelace Formula on a local tangent plane projection.
  static double computeGeodesicShoelaceArea(List<LatLng> polygon) {
    return computeSignedGeodesicShoelaceArea(polygon).abs();
  }

  /// Same projection as [computeGeodesicShoelaceArea] but keeps the sign
  /// (orientation). Used to sum union results that contain holes: Clipper2
  /// returns holes with the opposite orientation of outer rings, so the signed
  /// sum correctly subtracts hole area instead of adding it.
  static double computeSignedGeodesicShoelaceArea(List<LatLng> polygon) {
    if (polygon.length < 3) return 0.0;

    // Earth equatorial radius in meters
    const double earthRadius = 6378137.0;

    // Find origin point for local tangent projection
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    final double originLat = (sumLat / polygon.length) * (math.pi / 180.0);
    final double originLng = (sumLng / polygon.length) * (math.pi / 180.0);

    // Project spherical coordinates into local Cartesian metric coordinates (x, y in meters)
    final List<math.Point<double>> metricPoints = [];
    for (final p in polygon) {
      final double latRad = p.latitude * (math.pi / 180.0);
      final double lngRad = p.longitude * (math.pi / 180.0);

      final double x =
          earthRadius *
          (lngRad - originLng) *
          math.cos((latRad + originLat) / 2.0);
      final double y = earthRadius * (latRad - originLat);

      metricPoints.add(math.Point<double>(x, y));
    }

    // Apply standard 2D Shoelace Area Formula
    double area = 0.0;
    final int n = metricPoints.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += (metricPoints[i].x * metricPoints[j].y);
      area -= (metricPoints[j].x * metricPoints[i].y);
    }

    return area / 2.0;
  }
}
