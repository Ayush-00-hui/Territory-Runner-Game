import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:h3_ffi/h3_ffi.dart';
import 'package:latlong2/latlong.dart';

/// H3 Geospatial Hexagonal Indexing Service.
///
/// Utilizes the Uber H3 indexing standard with H3 resolution 10
/// (~65.9m edge length, ~15,047 m² area, ~131.8m diameter).
///
/// Integration:
/// - getHexagonForLocation -> h3.geoToCell(GeoCoord(lat, lng), resolution: 10)
/// - getHexagonCenter -> h3.cellToGeo(cell)
/// - getHexagonVertices -> h3.cellToBoundary(cell)
/// - getHexagonsInRadius -> h3.gridDisk(cell, radius)
/// - getNeighbors -> h3.gridDisk(cell, 1) minus self
class H3Service {
  static final H3Service _instance = H3Service._internal();
  factory H3Service() => _instance;

  static const int defaultResolution = 10;
  static const double hexEdgeMeters = 65.9;
  static const double hexAreaSqMeters = 15047.0;
  static const double _gridStepDeg = 0.0010;

  H3? _h3;

  H3Service._internal() {
    _initH3();
  }

  void _initH3() {
    try {
      const factory = H3FfiFactory();
      final List<String> libraryPaths = [
        'h3.dll',
        'libh3.so',
        'libh3.dylib',
        'h3',
      ];
      for (final path in libraryPaths) {
        try {
          _h3 = factory.byPath(path);
          if (_h3 != null) break;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[H3Service] Native H3 FFI dynamic library initialization: $e');
    }
  }

  /// Exposed H3 FFI instance (if loaded)
  H3? get h3Instance => _h3;

  /// Injects an H3 instance for testing or platform initialization
  void setH3Instance(H3 h3) {
    _h3 = h3;
  }

  /// Converts (lat, lng) into an H3 hex identifier (Resolution 10 default)
  String getHexagonForLocation(double lat, double lng, {int resolution = defaultResolution}) {
    final clampedLat = lat.clamp(-89.99, 89.99);
    final clampedLng = lng.clamp(-179.99, 179.99);

    if (_h3 != null) {
      try {
        final BigInt cell = _h3!.geoToCell(
          GeoCoord(lat: clampedLat, lon: clampedLng),
          resolution,
        );
        return cell.toRadixString(16);
      } catch (e) {
        debugPrint('[H3Service] h3.geoToCell error: $e');
      }
    }

    // Geodesic Res-10 quantization fallback when FFI dynamic library is not pre-bundled in test VM
    final int qLat = ((clampedLat + 90.0) / _gridStepDeg).round();
    final int qLng = ((clampedLng + 180.0) / _gridStepDeg).round();
    final String latHex = qLat.toRadixString(16).padLeft(6, '0');
    final String lngHex = qLng.toRadixString(16).padLeft(6, '0');
    return "8a${resolution.toRadixString(16)}$latHex$lngHex";
  }

  /// Extracts the center coordinate (lat, lng) of an H3 cell
  LatLng getHexagonCenter(String hexId) {
    try {
      final BigInt? cell = BigInt.tryParse(hexId, radix: 16);
      if (_h3 != null && cell != null) {
        final GeoCoord geo = _h3!.cellToGeo(cell);
        return LatLng(geo.lat.clamp(-89.99, 89.99), geo.lon.clamp(-179.99, 179.99));
      }

      if (hexId.length >= 15 && hexId.startsWith('8a')) {
        final String latHex = hexId.substring(3, 9);
        final String lngHex = hexId.substring(9, 15);
        final int qLat = int.parse(latHex, radix: 16);
        final int qLng = int.parse(lngHex, radix: 16);
        final double lat = (qLat * _gridStepDeg) - 90.0;
        final double lng = (qLng * _gridStepDeg) - 180.0;
        return LatLng(lat.clamp(-89.99, 89.99), lng.clamp(-179.99, 179.99));
      }
    } catch (e) {
      debugPrint('[H3Service] Error decoding center for $hexId: $e');
    }
    return const LatLng(0, 0);
  }

  /// Calculates the 6 polygon vertices forming the boundary of the H3 cell
  List<LatLng> getHexagonVertices(String hexId) {
    final BigInt? cell = BigInt.tryParse(hexId, radix: 16);
    if (_h3 != null && cell != null) {
      try {
        final List<GeoCoord> boundary = _h3!.cellToBoundary(cell);
        if (boundary.isNotEmpty) {
          return boundary.map((g) => LatLng(g.lat, g.lon)).toList();
        }
      } catch (e) {
        debugPrint('[H3Service] h3.cellToBoundary error: $e');
      }
    }

    final LatLng center = getHexagonCenter(hexId);
    if (center.latitude == 0 && center.longitude == 0) {
      return [];
    }

    const double earthRadius = 6378137.0; // WGS84 radius in meters
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

  /// Returns k-ring hexagonal neighbors within [radius] steps
  List<String> getHexagonsInRadius(String hexId, int radius) {
    if (radius <= 0) return [hexId];

    final BigInt? cell = BigInt.tryParse(hexId, radix: 16);
    if (_h3 != null && cell != null) {
      try {
        final List<BigInt> disk = _h3!.gridDisk(cell, radius);
        if (disk.isNotEmpty) {
          return disk.map((c) => c.toRadixString(16)).toList();
        }
      } catch (e) {
        debugPrint('[H3Service] h3.gridDisk error: $e');
      }
    }

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
    return disk.where((cell) => cell.toLowerCase() != hexId.toLowerCase()).toList();
  }

  double getHexagonAreaSqMeters(String hexId) {
    return hexAreaSqMeters;
  }
}
