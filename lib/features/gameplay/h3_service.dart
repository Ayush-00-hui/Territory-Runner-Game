import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class H3Service {
  static final H3Service _instance = H3Service._internal();
  factory H3Service() => _instance;

  final int resolution = 11; 

  H3Service._internal();

  /// Convert a Latitude and Longitude to a pseudo-Hexagon Index string
  String getHexagonForLocation(double lat, double lng) {
    // Round to 4 decimal places to create a pseudo "grid"
    return "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";
  }

  /// Get the vertices of a hexagon index to draw on the map
  List<LatLng> getHexagonVertices(String hexId) {
    final parts = hexId.split(',');
    if (parts.length != 2) return [];
    
    final lat = double.tryParse(parts[0]) ?? 0;
    final lng = double.tryParse(parts[1]) ?? 0;
    
    // Draw a small 20-meter hexagon around the coordinate
    const double radius = 0.0002; // Roughly 20m in degrees
    List<LatLng> points = [];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      points.add(LatLng(
        lat + radius * math.sin(angle),
        lng + radius * math.cos(angle),
      ));
    }
    return points;
  }

  /// Get all hexagons within a certain ring radius
  List<String> getHexagonsInRadius(String hexId, int radius) {
    return [hexId];
  }
}
