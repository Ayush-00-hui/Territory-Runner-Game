import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/routing/route_service.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/features/map/widgets/map_layers.dart';
import 'package:territory_runner/features/map/widgets/claim_planner_sheet.dart';

void main() {
  setUpAll(() {
    RouteService.forceOffline = true;
  });

  tearDownAll(() {
    RouteService.forceOffline = false;
  });

  group('Claim Planner Area Math & Conversions', () {
    test('targetAreaToDistanceKm scales with square root of area', () {
      final d2k = RouteService.targetAreaToDistanceKm(2000.0);
      final d5k = RouteService.targetAreaToDistanceKm(5000.0);
      final d10k = RouteService.targetAreaToDistanceKm(10000.0);
      final d25k = RouteService.targetAreaToDistanceKm(25000.0);

      expect(d2k, inInclusiveRange(0.14, 0.22));
      expect(d5k, inInclusiveRange(0.24, 0.32));
      expect(d10k, inInclusiveRange(0.34, 0.45));
      expect(d25k, inInclusiveRange(0.55, 0.70));
      expect(d25k, greaterThan(d10k));
      expect(d10k, greaterThan(d5k));
      expect(d5k, greaterThan(d2k));
    });

    test('suggestRouteForTargetArea generates valid closed loop matching budget', () async {
      final routeService = RouteService();
      const origin = LatLng(37.7749, -122.4194);

      final route = await routeService.suggestRouteForTargetArea(
        currentLocation: origin,
        targetAreaSqM: 10000.0,
      );

      expect(route.polyline.length, greaterThanOrEqualTo(4));
      // Loop is closed
      expect(route.polyline.first.latitude, equals(route.polyline.last.latitude));
      expect(route.polyline.first.longitude, equals(route.polyline.last.longitude));
      expect(route.totalDistanceKm, greaterThan(0.1));
      expect(route.estimatedNewTerritoryAreaSqM, greaterThan(500.0));
      expect(route.estimatedDurationMinutes, greaterThanOrEqualTo(1));
    });

    test('Offline fallback flags isOffline and never throws', () {
      final routeService = RouteService();
      const origin = LatLng(37.7749, -122.4194);

      final route = routeService.suggestRoute(
        currentLocation: origin,
        targetDistanceKm: 1.0,
        targetAreaSqM: 5000.0,
        isOffline: true,
      );

      expect(route.isOffline, isTrue);
      expect(route.polyline.length, greaterThanOrEqualTo(3));
      expect(route.totalDistanceKm, greaterThan(0));
    });
  });

  group('Claim Planner Net Area Deduction via Clipper2', () {
    test('Deducts already-owned territory from proposed loop', () {
      final routeService = RouteService();

      // Existing owned territory at center: 100m x 100m square (~10,000 m²)
      const double centerLat = 37.7749;
      const double centerLng = -122.4194;
      const double halfSideDeg = 0.0005; // ~55m half-side
      final existingSquare = [
        const LatLng(centerLat - halfSideDeg, centerLng - halfSideDeg),
        const LatLng(centerLat + halfSideDeg, centerLng - halfSideDeg),
        const LatLng(centerLat + halfSideDeg, centerLng + halfSideDeg),
        const LatLng(centerLat - halfSideDeg, centerLng + halfSideDeg),
        const LatLng(centerLat - halfSideDeg, centerLng - halfSideDeg),
      ];
      final double existingArea = PolygonEnclosureEngine.computeGeodesicShoelaceArea(existingSquare);

      // Now propose a larger loop circumscribing the existing square (2x larger)
      const double outerHalfSide = 0.0010; // ~110m half-side
      final outerSquare = [
        const LatLng(centerLat - outerHalfSide, centerLng - outerHalfSide),
        const LatLng(centerLat + outerHalfSide, centerLng - outerHalfSide),
        const LatLng(centerLat + outerHalfSide, centerLng + outerHalfSide),
        const LatLng(centerLat - outerHalfSide, centerLng + outerHalfSide),
        const LatLng(centerLat - outerHalfSide, centerLng - outerHalfSide),
      ];
      final double totalOuterArea = PolygonEnclosureEngine.computeGeodesicShoelaceArea(outerSquare);

      final double netNewArea = routeService.computeNetNewArea(outerSquare, [existingSquare]);

      // The net new area must be total outer area MINUS the existing square area
      expect(netNewArea, lessThan(totalOuterArea));
      expect(netNewArea, greaterThan(0.0));
      final double expectedNet = totalOuterArea - existingArea;
      expect((netNewArea - expectedNet).abs(), lessThan(totalOuterArea * 0.05),
          reason: 'Net new area should be outer area minus owned square within 5% tolerance');
    });

    test('Loop entirely inside owned territory yields zero net area', () {
      final routeService = RouteService();

      // Large owned territory
      const double centerLat = 37.7749;
      const double centerLng = -122.4194;
      const double largeHalfSide = 0.0020;
      final largeSquare = [
        const LatLng(centerLat - largeHalfSide, centerLng - largeHalfSide),
        const LatLng(centerLat + largeHalfSide, centerLng - largeHalfSide),
        const LatLng(centerLat + largeHalfSide, centerLng + largeHalfSide),
        const LatLng(centerLat - largeHalfSide, centerLng + largeHalfSide),
        const LatLng(centerLat - largeHalfSide, centerLng - largeHalfSide),
      ];

      // Small loop completely inside the owned square
      const double smallHalfSide = 0.0003;
      final innerSquare = [
        const LatLng(centerLat - smallHalfSide, centerLng - smallHalfSide),
        const LatLng(centerLat + smallHalfSide, centerLng - smallHalfSide),
        const LatLng(centerLat + smallHalfSide, centerLng + smallHalfSide),
        const LatLng(centerLat - smallHalfSide, centerLng + smallHalfSide),
        const LatLng(centerLat - smallHalfSide, centerLng - smallHalfSide),
      ];

      final double netNewArea = routeService.computeNetNewArea(innerSquare, [largeSquare]);
      expect(netNewArea, equals(0.0),
          reason: 'Running inside your own territory earns 0 net new area');
    });
  });

  group('MapLayers Hole Rendering Classification Tests', () {
    test('Donut polygon correctly classifies into 1 outer shell with 1 hole', () {
      // Outer ring: 200m x 200m
      const double cLat = 37.7749;
      const double cLng = -122.4194;
      final outerRing = [
        const LatLng(cLat - 0.001, cLng - 0.001),
        const LatLng(cLat + 0.001, cLng - 0.001),
        const LatLng(cLat + 0.001, cLng + 0.001),
        const LatLng(cLat - 0.001, cLng + 0.001),
        const LatLng(cLat - 0.001, cLng - 0.001),
      ];

      // Inner hole: 50m x 50m inside outer ring
      final holeRing = [
        const LatLng(cLat - 0.0003, cLng - 0.0003),
        const LatLng(cLat + 0.0003, cLng - 0.0003),
        const LatLng(cLat + 0.0003, cLng + 0.0003),
        const LatLng(cLat - 0.0003, cLng + 0.0003),
        const LatLng(cLat - 0.0003, cLng - 0.0003),
      ];

      final shells = MapLayers.classifyRings([outerRing, holeRing]);

      expect(shells.length, equals(1), reason: 'Donut should produce exactly 1 outer shell');
      expect(shells.first.holes.length, equals(1), reason: 'Donut outer shell should contain 1 hole');
    });

    test('Two disjoint territories classify into 2 separate outer shells with 0 holes', () {
      final ringA = [
        const LatLng(37.77, -122.42),
        const LatLng(37.78, -122.42),
        const LatLng(37.78, -122.41),
        const LatLng(37.77, -122.41),
        const LatLng(37.77, -122.42),
      ];
      final ringB = [
        const LatLng(37.70, -122.45),
        const LatLng(37.71, -122.45),
        const LatLng(37.71, -122.44),
        const LatLng(37.70, -122.44),
        const LatLng(37.70, -122.45),
      ];

      final shells = MapLayers.classifyRings([ringA, ringB]);

      expect(shells.length, equals(2));
      expect(shells[0].holes, isEmpty);
      expect(shells[1].holes, isEmpty);
    });

    test('isPointInPolygon accurately detects interior and exterior points', () {
      final polygon = [
        const LatLng(10.0, 10.0),
        const LatLng(20.0, 10.0),
        const LatLng(20.0, 20.0),
        const LatLng(10.0, 20.0),
        const LatLng(10.0, 10.0),
      ];

      expect(MapLayers.isPointInPolygon(const LatLng(15.0, 15.0), polygon), isTrue);
      expect(MapLayers.isPointInPolygon(const LatLng(5.0, 5.0), polygon), isFalse);
      expect(MapLayers.isPointInPolygon(const LatLng(25.0, 25.0), polygon), isFalse);
    });
  });

  group('ClaimPlannerSheet Widget Tests', () {
    testWidgets('Renders presets, slider, telemetry grid, and start button', (tester) async {
      final routeService = RouteService();
      const origin = LatLng(37.7749, -122.4194);
      final initialRoute = routeService.suggestRoute(
        currentLocation: origin,
        targetDistanceKm: 0.27,
        targetAreaSqM: 5000.0,
      );
      SuggestedRoute? startedRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClaimPlannerSheet(
                currentLocation: origin,
                routeService: routeService,
                initialTargetAreaSqM: 5000.0,
                initialRoute: initialRoute,
                onRouteGenerated: (_) {},
                onStartRun: (route) {
                  startedRoute = route;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Header
      expect(find.text('Claim planner'), findsOneWidget);

      // Verify Presets
      expect(find.text('Park'), findsOneWidget);
      expect(find.text('District'), findsOneWidget);
      expect(find.text('Citadel'), findsOneWidget);
      expect(find.text('Empire'), findsOneWidget);

      // Verify Telemetry labels
      expect(find.text('Est. distance'), findsOneWidget);
      expect(find.text('Est. duration'), findsOneWidget);
      expect(find.text('Est. new area'), findsOneWidget);
      expect(find.text('Projected XP'), findsOneWidget);

      // Verify Start CTA
      final startButton = find.text('Start run with route');
      expect(startButton, findsOneWidget);

      // Tap Start Run
      await tester.tap(startButton);
      await tester.pump();

      expect(startedRoute, isNotNull);
      expect(startedRoute!.polyline.length, greaterThanOrEqualTo(3));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Tapping a preset switches target area and updates route', (tester) async {
      final routeService = RouteService();
      const origin = LatLng(37.7749, -122.4194);
      final initialRoute = routeService.suggestRoute(
        currentLocation: origin,
        targetDistanceKm: 0.17,
        targetAreaSqM: 2000.0,
      );
      SuggestedRoute? generatedRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClaimPlannerSheet(
                currentLocation: origin,
                routeService: routeService,
                initialTargetAreaSqM: 2000.0,
                initialRoute: initialRoute,
                onRouteGenerated: (route) {
                  generatedRoute = route;
                },
                onStartRun: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('2000 m²'), findsOneWidget);

      // Tap Citadel (10,000 m²)
      await tester.tap(find.text('Citadel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('10000 m²'), findsOneWidget);
      expect(generatedRoute, isNotNull);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
