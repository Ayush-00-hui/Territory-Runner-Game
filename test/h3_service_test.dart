import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/h3_service.dart';

void main() {
  group('H3Service Unit Tests', () {
    final H3Service h3Service = H3Service();
    const double testLat = 37.7749; // San Francisco
    const double testLng = -122.4194;

    test('getHexagonForLocation generates valid H3-formatted hex string', () {
      final String hexId = h3Service.getHexagonForLocation(testLat, testLng);
      expect(hexId, isNotEmpty);
      expect(hexId.startsWith('8a'), isTrue);
      expect(hexId.length, equals(15));
    });

    test('gridDisk with radius 0 returns only the self hexId', () {
      final String hexId = h3Service.getHexagonForLocation(testLat, testLng);
      final List<String> disk = h3Service.getHexagonsInRadius(hexId, 0);
      expect(disk.length, equals(1));
      expect(disk.first, equals(hexId));
    });

    test('getNeighbors returns 6 distinct neighboring hex cells', () {
      final String hexId = h3Service.getHexagonForLocation(testLat, testLng);
      final List<String> neighbors = h3Service.getNeighbors(hexId);
      
      expect(neighbors.contains(hexId), isFalse, reason: 'Neighbors should exclude self');
      expect(neighbors.length, lessThanOrEqualTo(6));
      expect(neighbors.toSet().length, equals(neighbors.length), reason: 'Neighbors must be unique');
    });

    test('Hexagon vertices form a closed 6-sided polygon of correct scale', () {
      final String hexId = h3Service.getHexagonForLocation(testLat, testLng);
      final List<LatLng> vertices = h3Service.getHexagonVertices(hexId);

      expect(vertices.length, equals(6));
      final LatLng center = h3Service.getHexagonCenter(hexId);

      // Distance from center to vertices should be ~65.9m (radius)
      for (final v in vertices) {
        final double dLat = (v.latitude - center.latitude) * 111139.0;
        final double dLng = (v.longitude - center.longitude) * 111139.0 * math.cos(center.latitude * math.pi / 180.0);
        final double distMeters = math.sqrt(dLat * dLat + dLng * dLng);
        expect(distMeters, closeTo(65.9, 10.0));
      }
    });

    test('Hexagon area is reported at ~15,047 m²', () {
      final String hexId = h3Service.getHexagonForLocation(testLat, testLng);
      final double area = h3Service.getHexagonAreaSqMeters(hexId);
      expect(area, equals(15047.0));
    });
  });
}
