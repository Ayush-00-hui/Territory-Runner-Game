import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:clipper2/clipper2.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';

void main() {
  group('Clipper2 Territory Union & Difference Tests', () {
    test('Two overlapping squares merge into a single contiguous polygon territory', () {
      // Square A: (51.5000, -0.1200) to (51.5010, -0.1210)
      final List<LatLng> squareA = [
        const LatLng(51.5000, -0.1200),
        const LatLng(51.5010, -0.1200),
        const LatLng(51.5010, -0.1210),
        const LatLng(51.5000, -0.1210),
      ];

      // Square B: (51.5005, -0.1205) to (51.5015, -0.1215) overlapping Square A
      final List<LatLng> squareB = [
        const LatLng(51.5005, -0.1205),
        const LatLng(51.5015, -0.1205),
        const LatLng(51.5015, -0.1215),
        const LatLng(51.5005, -0.1215),
      ];

      final pathA = TerritoryService.latLngsToPath64(squareA);
      final pathB = TerritoryService.latLngsToPath64(squareB);

      final Paths64 unionPaths = Clipper.union(
        subject: [pathA],
        clip: [pathB],
        fillRule: FillRule.nonZero,
      );

      expect(unionPaths.length, 1, reason: 'Overlapping squares should merge into 1 polygon ring');
      
      final mergedPolygon = TerritoryService.path64ToLatLngs(unionPaths.first);
      final areaA = PolygonEnclosureEngine.computeGeodesicShoelaceArea(squareA);
      final areaB = PolygonEnclosureEngine.computeGeodesicShoelaceArea(squareB);
      final mergedArea = PolygonEnclosureEngine.computeGeodesicShoelaceArea(mergedPolygon);

      expect(mergedArea, greaterThan(areaA));
      expect(mergedArea, greaterThan(areaB));
      expect(mergedArea, lessThan(areaA + areaB), reason: 'Merged area should eliminate overlapping union region');
    });

    test('One player loop cuts into and shrinks rival player claimed area', () {
      // Rival territory: Big Square (51.5000, -0.1200) to (51.5020, -0.1220)
      final List<LatLng> rivalSquare = [
        const LatLng(51.5000, -0.1200),
        const LatLng(51.5020, -0.1200),
        const LatLng(51.5020, -0.1220),
        const LatLng(51.5000, -0.1220),
      ];

      // Attacking player loop: Bites off corner (51.5010, -0.1210) to (51.5030, -0.1230)
      final List<LatLng> attackSquare = [
        const LatLng(51.5010, -0.1210),
        const LatLng(51.5030, -0.1210),
        const LatLng(51.5030, -0.1230),
        const LatLng(51.5010, -0.1230),
      ];

      final rivalPath = TerritoryService.latLngsToPath64(rivalSquare);
      final attackPath = TerritoryService.latLngsToPath64(attackSquare);

      final Paths64 clippedRivalPaths = Clipper.difference(
        subject: [rivalPath],
        clip: [attackPath],
        fillRule: FillRule.nonZero,
      );

      expect(clippedRivalPaths, isNotEmpty);
      
      final clippedMultiPolys = clippedRivalPaths.map(TerritoryService.path64ToLatLngs).toList();
      final initialRivalArea = PolygonEnclosureEngine.computeGeodesicShoelaceArea(rivalSquare);
      final remainingRivalArea = clippedMultiPolys.fold(
        0.0,
        (acc, poly) => acc + PolygonEnclosureEngine.computeGeodesicShoelaceArea(poly),
      );

      expect(remainingRivalArea, lessThan(initialRivalArea), reason: 'Rival territory area must shrink when contested');
      expect(remainingRivalArea, greaterThan(0.0));
    });
  });
}
