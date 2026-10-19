import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';

/// Tests for the mechanics fixes:
///  - max single-loop area guard (parity with the Go server, 5,000,000 m²)
///  - signed area helper used so union holes are subtracted, not added
void main() {
  // ~3.3 km x ~3.3 km square near the equator: roughly 11 km², far above 5 km².
  const double d = 0.03;
  final DateTime t0 = DateTime.utc(2026, 10, 15, 10, 0, 0);

  List<LatLng> hugeSquare() => const [
        LatLng(0.0, 0.0),
        LatLng(0.0, d),
        LatLng(d, d),
        LatLng(d, 0.0),
      ];

  group('Max loop area guard', () {
    test('auto-closed loop above 5 km² is rejected with the shared reason', () {
      final engine = PolygonEnclosureEngine();
      final pts = hugeSquare();
      for (int i = 0; i < pts.length; i++) {
        expect(engine.addPosition(pts[i], t0.add(Duration(seconds: i * 10))), isNull);
      }
      // Back near the start (~15 m away) -> would close, but area is too large.
      final event = engine.addPosition(
        const LatLng(0.0001, 0.0001),
        t0.add(const Duration(seconds: 40)),
      );
      expect(event, isNull);
      expect(engine.lastInvalidReason, equals(PolygonEnclosureEngine.loopTooLargeReason));
    });

    test('manual seal above 5 km² is rejected and path is kept', () {
      final engine = PolygonEnclosureEngine();
      final pts = hugeSquare();
      for (int i = 0; i < pts.length; i++) {
        engine.addPosition(pts[i], t0.add(Duration(seconds: i * 10)));
      }
      final event = engine.sealCurrentPath();
      expect(event, isNull);
      expect(engine.lastInvalidReason, equals(PolygonEnclosureEngine.loopTooLargeReason));
      expect(engine.pointCount, equals(4));
    });

    test('raising maxLoopAreaSqMeters accepts the same loop', () {
      final engine = PolygonEnclosureEngine(maxLoopAreaSqMeters: 1e9);
      final pts = hugeSquare();
      for (int i = 0; i < pts.length; i++) {
        engine.addPosition(pts[i], t0.add(Duration(seconds: i * 10)));
      }
      final event = engine.sealCurrentPath();
      expect(event, isNotNull);
      expect(event!.areaSqMeters, greaterThan(5000000.0));
    });
  });

  group('Signed geodesic area', () {
    test('orientation flips the sign, magnitude is identical', () {
      final ccw = hugeSquare();
      final cw = ccw.reversed.toList();
      final a = PolygonEnclosureEngine.computeSignedGeodesicShoelaceArea(ccw);
      final b = PolygonEnclosureEngine.computeSignedGeodesicShoelaceArea(cw);
      expect(a, greaterThan(0));
      expect(b, lessThan(0));
      expect(a.abs(), closeTo(b.abs(), 1e-6));
      expect(PolygonEnclosureEngine.computeGeodesicShoelaceArea(ccw), closeTo(a.abs(), 1e-6));
    });

    test('a hole (opposite orientation) is subtracted from the outer ring', () {
      const double o = 0.009;
      const double h = 0.0027;
      final outer = const [
        LatLng(51.5, -0.12),
        LatLng(51.5, -0.12 + o * 1.6),
        LatLng(51.5 + o, -0.12 + o * 1.6),
        LatLng(51.5 + o, -0.12),
      ];
      final hole = const [
        LatLng(51.503, -0.117),
        LatLng(51.503 + h, -0.117),
        LatLng(51.503 + h, -0.117 + h * 1.6),
        LatLng(51.503, -0.117 + h * 1.6),
      ];
      final so = PolygonEnclosureEngine.computeSignedGeodesicShoelaceArea(outer);
      final si = PolygonEnclosureEngine.computeSignedGeodesicShoelaceArea(hole);
      expect(so, greaterThan(0));
      expect(si, lessThan(0));
      final net = (so + si).abs();
      final expected = so.abs() - si.abs();
      expect(net, closeTo(expected, 1.0));
      expect(net, lessThan(so.abs()));
    });
  });
}
