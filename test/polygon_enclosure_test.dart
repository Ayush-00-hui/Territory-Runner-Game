import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';

void main() {
  group('PolygonEnclosureEngine Tests', () {
    late PolygonEnclosureEngine engine;

    setUp(() {
      engine = PolygonEnclosureEngine(
        minClosureDistanceMeters: 35.0,
        minPointsRequired: 4,
        minLoopDistanceMeters: 50.0,
      );
    });

    test('Initial state is empty', () {
      expect(engine.currentPath, isEmpty);
      expect(engine.pointCount, 0);
    });

    test('Straight line does not trigger closed loop', () {
      // 5 points along a straight line in London
      final p1 = LatLng(51.5074, -0.1278);
      final p2 = LatLng(51.5080, -0.1278);
      final p3 = LatLng(51.5086, -0.1278);
      final p4 = LatLng(51.5092, -0.1278);
      final p5 = LatLng(51.5098, -0.1278);

      expect(engine.addPosition(p1), isNull);
      expect(engine.addPosition(p2), isNull);
      expect(engine.addPosition(p3), isNull);
      expect(engine.addPosition(p4), isNull);
      expect(engine.addPosition(p5), isNull);

      expect(engine.pointCount, 5);
    });

    test('Closed rectangular loop triggers EnclosedLoopEvent', () {
      // 100m x 100m approx box in London
      // ~0.0009 deg lat = ~100m
      // ~0.0014 deg lng = ~100m
      final p1 = LatLng(51.5000, -0.1200);
      final p2 = LatLng(51.5009, -0.1200);
      final p3 = LatLng(51.5009, -0.1214);
      final p4 = LatLng(51.5000, -0.1214);
      final p5 = LatLng(51.5001, -0.1201); // within ~15m of p1

      expect(engine.addPosition(p1), isNull);
      expect(engine.addPosition(p2), isNull);
      expect(engine.addPosition(p3), isNull);
      expect(engine.addPosition(p4), isNull);

      final event = engine.addPosition(p5);
      expect(event, isNotNull);
      expect(event!.polygon.length, 5);
      expect(event.loopDistanceMeters, greaterThan(250.0));
      expect(event.areaSqMeters, greaterThan(5000.0));
      expect(event.areaSqKm, greaterThan(0.005));

      // Path resets after loop closure, keeping p5
      expect(engine.pointCount, 1);
      expect(engine.currentPath.first, p5);
    });

    test('Geodesic Shoelace Formula calculates valid area', () {
      // Known rectangular polygon of approx 100m x 100m = ~10,000 m²
      final square = [
        LatLng(51.5000, -0.1200),
        LatLng(51.5009, -0.1200),
        LatLng(51.5009, -0.12144),
        LatLng(51.5000, -0.12144),
      ];

      final area = PolygonEnclosureEngine.computeGeodesicShoelaceArea(square);
      expect(area, greaterThan(9000.0));
      expect(area, lessThan(11000.0));
    });

    test('Under 3 points returns 0 area', () {
      expect(PolygonEnclosureEngine.computeGeodesicShoelaceArea([]), 0.0);
      expect(PolygonEnclosureEngine.computeGeodesicShoelaceArea([LatLng(0, 0)]), 0.0);
      expect(PolygonEnclosureEngine.computeGeodesicShoelaceArea([LatLng(0, 0), LatLng(1, 1)]), 0.0);
    });
  });
}
