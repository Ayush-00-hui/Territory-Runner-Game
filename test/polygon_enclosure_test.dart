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
      expect(
        PolygonEnclosureEngine.computeGeodesicShoelaceArea([LatLng(0, 0)]),
        0.0,
      );
      expect(
        PolygonEnclosureEngine.computeGeodesicShoelaceArea([
          LatLng(0, 0),
          LatLng(1, 1),
        ]),
        0.0,
      );
    });

    test(
      'Self-intersecting loop (figure-8) is rejected with clear error reason',
      () {
        final engine = PolygonEnclosureEngine();
        // Pure figure-8 loop intersecting in the center with lobes < 40m
        final p1 = LatLng(51.50000, -0.12000);
        final p2 = LatLng(51.50016, -0.12016);
        final p3 = LatLng(51.50016, -0.12000);
        final p4 = LatLng(51.50000, -0.12016);

        expect(
          PolygonEnclosureEngine.hasSelfIntersection([p1, p2, p3, p4, p1]),
          isTrue,
        );

        engine.addPosition(p1);
        engine.addPosition(p2);
        engine.addPosition(p3);
        engine.addPosition(p4);

        final manualEvent = engine.sealCurrentPath();
        expect(manualEvent, isNull);
        expect(
          engine.lastInvalidReason,
          equals('Loop crossed itself — try again'),
        );
      },
    );

    test(
      'Lasso closure captures loop and retains tail for continued running',
      () {
        final engine = PolygonEnclosureEngine();
        // Stem: p0 -> p1
        // Loop: p1 -> p2 -> p3 -> crosses stem
        final p0 = LatLng(51.50000, -0.12000);
        final p1 = LatLng(51.50050, -0.12000);
        final p2 = LatLng(51.50050, -0.12150);
        final p3 = LatLng(51.50020, -0.12150);
        final p4 = LatLng(
          51.50020,
          -0.11950,
        ); // crosses p0->p1 at (51.50020, -0.12000)

        expect(engine.addPosition(p0), isNull);
        expect(engine.addPosition(p1), isNull);
        expect(engine.addPosition(p2), isNull);
        expect(engine.addPosition(p3), isNull);
        final lassoEvent = engine.addPosition(p4);

        expect(
          lassoEvent,
          isNotNull,
          reason: 'Crossing stem must trigger lasso loop enclosure',
        );
        expect(lassoEvent!.areaSqMeters, greaterThan(3000.0));
        // Remaining path must keep the tail: [p0, intersection]
        expect(engine.currentPath.length, equals(2));
        expect(engine.currentPath.first, equals(p0));
        expect(engine.currentPath.last.latitude, closeTo(51.50020, 1e-4));
        expect(engine.currentPath.last.longitude, closeTo(-0.12000, 1e-4));
      },
    );

    test(
      'Multi-candidate proximity closure selects candidate maximizing area',
      () {
        final engine = PolygonEnclosureEngine(minClosureDistanceMeters: 35.0);
        final pStart = LatLng(51.50000, -0.12000);
        final p1 = LatLng(51.50080, -0.12000);
        final p2 = LatLng(51.50080, -0.12140);
        final p3 = LatLng(51.50000, -0.12140);
        final p4 = LatLng(51.50005, -0.12005); // near pStart (~8m)

        expect(engine.addPosition(pStart), isNull);
        expect(engine.addPosition(p1), isNull);
        expect(engine.addPosition(p2), isNull);
        expect(engine.addPosition(p3), isNull);
        final event = engine.addPosition(p4);

        expect(event, isNotNull);
        expect(event!.areaSqMeters, greaterThan(7000.0));
      },
    );

    test('Rejection reason is cleared at start of subsequent addPosition call', () {
      final engine = PolygonEnclosureEngine();
      final t0 = DateTime(2026, 10, 20, 10, 0, 0);
      final p1 = LatLng(51.5000, -0.1200);
      final p2 = LatLng(51.5009, -0.1200);
      engine.addPosition(p1, t0);
      engine.addPosition(p2, t0.add(const Duration(seconds: 10)));

      // Trigger gap rejection (> 50m jump after 30s gap)
      final pJump = LatLng(51.5009, -0.1214);
      engine.addPosition(pJump, t0.add(const Duration(seconds: 40)));
      expect(engine.lastInvalidReason, equals(PolygonEnclosureEngine.signalGapReason));

      // Subsequent normal tick within valid parameters
      final pNormal = LatLng(51.5009, -0.1216);
      engine.addPosition(pNormal, t0.add(const Duration(seconds: 43)));

      // MUST be cleared! Reason should only be exposed for the call that produced it.
      expect(
        engine.lastInvalidReason,
        isNull,
        reason: 'Rejection reason must be cleared on the next call if no rejection occurred',
      );
    });
  });
}
