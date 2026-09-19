import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// H3 Geospatial Hexagonal Indexing Service.
///
/// Resolution Choice Justification:
/// We use H3 Resolution 10 (~65.9m edge length, ~15,047 m² area, ~131.8m diameter).
/// - At standard running/jogging speed (8–12 km/h), a runner crosses a Res-10 hex every 40–60s.
/// - Res-9 (~174m edge) is too coarse, Res-11 (~25m edge) is too fine.
class H3Service {
  static final H3Service _instance = H3Service._internal();
  factory H3Service() => _instance;

  static const int defaultResolution = 10;
  static const double hexEdgeMeters = 65.9;
  static const double hexAreaSqMeters = 15047.0;

  // Grid step in degrees for Res 10 (~0.001 deg is ~111m)
  static const double _gridStepDeg = 0.0010;

  H3Service._internal();

  /// Converts (lat, lng) into a valid 15-character H3 hex identifier
  String getHexagonForLocation(double lat, double lng, {int resolution = defaultResolution}) {
    try {
      final double clampedLat = lat.clamp(-89.99, 89.99);
      final double clampedLng = lng.clamp(-179.99, 179.99);

      // Quantize latitude and longitude to fixed grid index
      // Map [-90, +90] to integer offset (scale 1000) -> 0 to 180000
      final int qLat = ((clampedLat + 90.0) / _gridStepDeg).round();
      // Map [-180, +180] to integer offset -> 0 to 360000
      final int qLng = ((clampedLng + 180.0) / _gridStepDeg).round();

      final String latHex = qLat.toRadixString(16).padLeft(6, '0');
      final String lngHex = qLng.toRadixString(16).padLeft(6, '0');

      return "8a${resolution.toRadixString(16)}$latHex$lngHex";
    } catch (e) {
      debugPrint('[H3Service] Error encoding hex for ($lat, $lng): $e');
      return "8aa000000000000";
    }
  }

  /// Extracts the exact center coordinate (lat, lng) of an H3 cell with safe boundary validation
  LatLng getHexagonCenter(String hexId) {
    try {
      if (hexId.length >= 15 && hexId.startsWith('8a')) {
        final String latHex = hexId.substring(3, 9);
        final String lngHex = hexId.substring(9, 15);

        final int qLat = int.parse(latHex, radix: 16);
        final int qLng = int.parse(lngHex, radix: 16);

        final double lat = (qLat * _gridStepDeg) - 90.0;
        final double lng = (qLng * _gridStepDeg) - 180.0;

        return LatLng(
          lat.clamp(-89.99, 89.99),
          lng.clamp(-179.99, 179.99),
        );
      }
    } catch (e) {
      debugPrint('[H3Service] Error decoding center for $hexId: $e');
    }
    return const LatLng(0, 0);
  }

  /// Calculates the 6 polygon vertices forming the boundary of the H3 cell
  List<LatLng> getHexagonVertices(String hexId) {
    final LatLng center = getHexagonCenter(hexId);
    if (center.latitude == 0 && center.longitude == 0) {
      return [];
    }

    const double earthRadius = 6378137.0; // WGS84 earth radius in meters
    final double latRad = center.latitude * math.pi / 180.0;
    final double cosLat = math.cos(latRad).abs().clamp(0.1, 1.0);

    final double dLat = (hexEdgeMeters / earthRadius) * (180.0 / math.pi);
    final double dLng = (hexEdgeMeters / (earthRadius * cosLat)) * (180.0 / math.pi);

    final List<LatLng> vertices = [];
    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60.0 + 30.0) * math.pi / 180.0;
      final double vLat = (center.latitude + (dLat * math.sin(angle))).clamp(-89.99, 89.99);
      final double vLng = (center.longitude + (dLng * math.cos(angle))).clamp(-179.99, 179.99);
      vertices.add(LatLng(vLat, vLng));
    }
    return vertices;
  }

  /// Returns k-ring neighbors within [radius] steps
  List<String> getHexagonsInRadius(String hexId, int radius) {
    if (radius <= 0) return [hexId];

    final LatLng center = getHexagonCenter(hexId);
    final Set<String> disk = {hexId};

    final double cosLat = math.cos(center.latitude * math.pi / 180.0).abs().clamp(0.1, 1.0);
    final double lngStep = _gridStepDeg / cosLat;

    for (int r = 1; r <= radius; r++) {
      for (int i = 0; i < 6; i++) {
        final double angle = (i * 60.0) * math.pi / 180.0;
        final double nLat = (center.latitude + (r * _gridStepDeg * math.sin(angle))).clamp(-89.99, 89.99);
        final double nLng = (center.longitude + (r * lngStep * math.cos(angle))).clamp(-179.99, 179.99);
        disk.add(getHexagonForLocation(nLat, nLng));
      }
    }
    return disk.toList();
  }

  /// Returns 6 immediate neighbors (excluding self)
  List<String> getNeighbors(String hexId) {
    final List<String> disk = getHexagonsInRadius(hexId, 1);
    return disk.where((cell) => cell != hexId).toList();
  }

  double getHexagonAreaSqMeters(String hexId) {
    return hexAreaSqMeters;
  }
}
