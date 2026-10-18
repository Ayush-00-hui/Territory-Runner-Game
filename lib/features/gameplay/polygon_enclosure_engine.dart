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
  final double minClosureDistanceMeters; // Proximity threshold to trigger closed loop
  final int minPointsRequired; // Minimum path nodes for a valid loop
  final double minLoopDistanceMeters; // Minimum loop perimeter
  final double maxLoopAreaSqMeters; // Maximum single-loop area (matches Go server: 5,000,000 m²)
  final double? maxSpeedKmhOutlier; // Explicit outlier ceiling override
  ExerciseActivityType? activityType; // Activity mode calibrating outlier ceilings

  /// Rejection message used when a loop exceeds [maxLoopAreaSqMeters].
  /// Kept identical to the Go backend's ErrLoopAreaTooLarge text.
  static const String loopTooLargeReason =
      'Loop area exceeds maximum allowable single run threshold (5000000 m²)';

  PolygonEnclosureEngine({
    this.minClosureDistanceMeters = 35.0,
    this.minPointsRequired = 4,
    this.minLoopDistanceMeters = 40.0,
    this.maxLoopAreaSqMeters = 5000000.0,
    this.maxSpeedKmhOutlier,
    this.activityType,
  });

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

  /// Manual "SEAL CURRENT SHAPE" override action.
  /// Force-closes the active GPS path into a sovereign territory polygon.
  EnclosedLoopEvent? sealCurrentPath() {
    _lastInvalidReason = null;
    if (_path.length < 3) return null;

    final now = DateTime.now();
    final List<LatLng> closedPoints = List<LatLng>.from(_path);
    // Connect back to the first vertex if not already adjacent
    if (closedPoints.first.latitude != closedPoints.last.latitude ||
        closedPoints.first.longitude != closedPoints.last.longitude) {
      closedPoints.add(closedPoints.first);
    }

    if (hasSelfIntersection(closedPoints)) {
      _lastInvalidReason = 'Loop crossed itself — try again';
      AppLogger.debug('Manual seal rejected: $_lastInvalidReason', tag: 'PolygonEnclosureEngine');
      return null;
    }

    final loopLength = _calculatePathDistance(closedPoints);
    final areaSqM = computeGeodesicShoelaceArea(closedPoints);
    final areaSqKm = areaSqM / 1000000.0;

    if (areaSqM > maxLoopAreaSqMeters) {
      _lastInvalidReason = loopTooLargeReason;
      AppLogger.debug('Manual seal rejected: $_lastInvalidReason', tag: 'PolygonEnclosureEngine');
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
    _path.clear();
    _timestamps.clear();
    _path.add(lastPos);
    _timestamps.add(now);

    return event;
  }

  /// Ingests a new GPS position and checks for arbitrary polygon loop enclosure.
  /// Returns [EnclosedLoopEvent] if a valid loop was closed, or null otherwise.
  EnclosedLoopEvent? addPosition(LatLng position, [DateTime? timestamp]) {
    _lastInvalidReason = null;
    final now = timestamp ?? DateTime.now();

    // 1. Discard satellite multipath outlier jumps against immediately preceding sample
    if (_lastReceivedTimestamp != null && _lastReceivedPosition != null) {
      final double dtSec = (now.difference(_lastReceivedTimestamp!).inMilliseconds / 1000.0).abs();
      if (dtSec >= 0.5 && dtSec <= 5.0) {
        final double stepDist = haversineDistanceMeters(_lastReceivedPosition!, position);
        final double speedKmh = (stepDist / dtSec) * 3.6;
        if (speedKmh > effectiveMaxSpeedOutlier) {
          _lastReceivedPosition = position;
          _lastReceivedTimestamp = now;
          AppLogger.debug('Jitter outlier rejected: ${speedKmh.toStringAsFixed(1)} km/h (ceiling: $effectiveMaxSpeedOutlier km/h)', tag: 'PolygonEnclosureEngine');
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
          final intersection = computeIntersectionPoint(pEarly1, pEarly2, pLast1, pLast2);
          if (intersection != null) {
            final lassoPoints = <LatLng>[intersection];
            for (int k = j + 1; k < currentIndex; k++) {
              lassoPoints.add(_path[k]);
            }
            lassoPoints.add(intersection);

            final loopLength = _calculatePathDistance(lassoPoints);
            if (loopLength >= minLoopDistanceMeters && !hasSelfIntersection(lassoPoints)) {
              final areaSqM = computeGeodesicShoelaceArea(lassoPoints);
              if (areaSqM <= maxLoopAreaSqMeters && areaSqM > maxLassoArea) {
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

      if (bestLassoEvent != null && bestLassoJ != null && bestLassoIntersection != null) {
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
        final dTotal = haversineDistanceMeters(_path[bestLassoJ], _path[bestLassoJ + 1]);
        final dPart = haversineDistanceMeters(_path[bestLassoJ], bestLassoIntersection);
        final fraction = dTotal > 1e-6 ? (dPart / dTotal).clamp(0.0, 1.0) : 0.0;
        final tEarly1 = _timestamps[bestLassoJ];
        final tEarly2 = _timestamps[bestLassoJ + 1];
        final intMillis = tEarly1.millisecondsSinceEpoch +
            ((tEarly2.millisecondsSinceEpoch - tEarly1.millisecondsSinceEpoch) * fraction).round();
        newTimestamps.add(DateTime.fromMillisecondsSinceEpoch(intMillis));

        _path.clear();
        _timestamps.clear();
        _path.addAll(newPath);
        _timestamps.addAll(newTimestamps);

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

      if (distance <= minClosureDistanceMeters) {
        final loopPoints = List<LatLng>.from(_path.sublist(i, currentIndex + 1));
        final loopLength = _calculatePathDistance(loopPoints);

        if (loopLength < minLoopDistanceMeters) {
          candidateFailureReason ??= 'Loop perimeter below minimum threshold (40.0m)';
          continue;
        }

        if (hasSelfIntersection(loopPoints)) {
          candidateFailureReason = 'Loop crossed itself — try again';
          continue;
        }

        final areaSqM = computeGeodesicShoelaceArea(loopPoints);
        if (areaSqM > maxLoopAreaSqMeters) {
          candidateFailureReason = loopTooLargeReason;
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

      return bestProximityEvent;
    }

    if (candidateFailureReason != null) {
      _lastInvalidReason = candidateFailureReason;
    }

    return null;
  }

  /// Computes the exact 2D planar intersection point of segments (p1->p2) and (p3->p4).
  /// Returns null if the segments are parallel or do not properly intersect.
  static LatLng? computeIntersectionPoint(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
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

  /// Checks if line segments (p1->p2) and (p3->p4) properly cross
  static bool doSegmentsIntersect(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    double ccw(LatLng a, LatLng b, LatLng c) {
      return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
          (b.latitude - a.latitude) * (c.longitude - a.longitude);
    }

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    if (((d1 > 1e-9 && d2 < -1e-9) || (d1 < -1e-9 && d2 > 1e-9)) &&
        ((d3 > 1e-9 && d4 < -1e-9) || (d3 < -1e-9 && d4 > 1e-9))) {
      return true;
    }
    return false;
  }

  /// Validates whether a closed or open polygon path contains self-intersections
  static bool hasSelfIntersection(List<LatLng> polygon) {
    if (polygon.length < 4) return false;
    final int n = polygon.length;
    for (int i = 0; i < n - 1; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      for (int j = i + 2; j < n - 1; j++) {
        if (i == 0 && j == n - 2) continue; // Ignore shared start-end vertex in closed ring
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

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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

      final double x = earthRadius * (lngRad - originLng) * math.cos((latRad + originLat) / 2.0);
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
