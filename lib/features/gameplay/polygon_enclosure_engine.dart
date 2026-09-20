import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

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
/// filters satellite multipath outliers (> 35 km/h), and computes accurate
/// geodesic surface area via the Shoelace Formula on a local equirectangular tangent plane.
class PolygonEnclosureEngine {
  final List<LatLng> _path = [];
  final List<DateTime> _timestamps = [];
  
  // Enclosure configuration parameters
  final double minClosureDistanceMeters; // Proximity threshold to trigger closed loop
  final int minPointsRequired; // Minimum path nodes for a valid loop
  final double minLoopDistanceMeters; // Minimum loop perimeter

  PolygonEnclosureEngine({
    this.minClosureDistanceMeters = 35.0,
    this.minPointsRequired = 4,
    this.minLoopDistanceMeters = 40.0,
  });

  List<LatLng> get currentPath => List.unmodifiable(_path);
  int get pointCount => _path.length;

  void clear() {
    _path.clear();
    _timestamps.clear();
  }

  /// Manual "SEAL CURRENT SHAPE" override action.
  /// Force-closes the active GPS path into a sovereign territory polygon.
  EnclosedLoopEvent? sealCurrentPath() {
    if (_path.length < 3) return null;

    final now = DateTime.now();
    final List<LatLng> closedPoints = List<LatLng>.from(_path);
    // Connect back to the first vertex if not already adjacent
    if (closedPoints.first.latitude != closedPoints.last.latitude ||
        closedPoints.first.longitude != closedPoints.last.longitude) {
      closedPoints.add(closedPoints.first);
    }

    final loopLength = _calculatePathDistance(closedPoints);
    final areaSqM = computeGeodesicShoelaceArea(closedPoints);
    final areaSqKm = areaSqM / 1000000.0;

    final event = EnclosedLoopEvent(
      polygon: closedPoints,
      areaSqMeters: areaSqM,
      areaSqKm: areaSqKm,
      loopDistanceMeters: loopLength,
      closedAt: now,
    );

    debugPrint(
      '[PolygonEnclosureEngine] ⚡ Manually SEALED current shape! Points: ${closedPoints.length}, Perimeter: ${loopLength.toStringAsFixed(1)}m, Area: ${areaSqM.toStringAsFixed(1)}m²',
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
    final now = timestamp ?? DateTime.now();

    if (_path.isNotEmpty) {
      final lastPoint = _path.last;
      final distFromLast = haversineDistanceMeters(lastPoint, position);

      // Filter out stationary noise (< 1.8 meters)
      if (distFromLast < 1.8) {
        return null;
      }

      // Discard satellite multipath outlier jumps (> 35 km/h)
      if (_timestamps.isNotEmpty) {
        final double dtSec = (now.difference(_timestamps.last).inMilliseconds / 1000.0).abs();
        if (dtSec >= 0.5 && dtSec <= 5.0) {
          final double speedKmh = (distFromLast / dtSec) * 3.6;
          if (speedKmh > 35.0) {
            debugPrint('[PolygonEnclosureEngine] Jitter outlier rejected: ${speedKmh.toStringAsFixed(1)} km/h');
            return null;
          }
        }
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

    // Check backwards from the earliest points to find closure
    for (int i = 0; i <= currentIndex - minPointsRequired; i++) {
      final candidatePoint = _path[i];
      final distance = haversineDistanceMeters(currentPos, candidatePoint);

      if (distance <= minClosureDistanceMeters) {
        // Calculate the sub-path forming this loop
        final loopPoints = _path.sublist(i, currentIndex + 1);
        final loopLength = _calculatePathDistance(loopPoints);

        if (loopLength >= minLoopDistanceMeters) {
          final areaSqM = computeGeodesicShoelaceArea(loopPoints);
          final areaSqKm = areaSqM / 1000000.0;

          // Valid enclosed loop detected
          final event = EnclosedLoopEvent(
            polygon: List<LatLng>.from(loopPoints),
            areaSqMeters: areaSqM,
            areaSqKm: areaSqKm,
            loopDistanceMeters: loopLength,
            closedAt: now,
          );

          debugPrint(
            '[PolygonEnclosureEngine] 🏁 Closed loop detected! Points: ${loopPoints.length}, Perimeter: ${loopLength.toStringAsFixed(1)}m, Area: ${areaSqM.toStringAsFixed(1)}m² (${areaSqKm.toStringAsFixed(4)} km²)',
          );

          // Retain current position as origin for next loop
          _path.clear();
          _timestamps.clear();
          _path.add(position);
          _timestamps.add(now);

          return event;
        }
      }
    }

    return null;
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

    return (area.abs() / 2.0);
  }
}
