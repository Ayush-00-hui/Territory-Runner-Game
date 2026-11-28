import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/services/route_loop_synthesizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteLoopSynthesizerService RTX 5070 Generative Model Tests', () {
    late RouteLoopSynthesizerService service;
    const origin = LatLng(28.6139, 77.2090); // New Delhi Landmark

    setUp(() {
      service = RouteLoopSynthesizerService();
    });

    test('Initializes with default generative metadata', () async {
      await service.initialize();
      expect(service.isModelLoaded, true);
      expect(service.condMean.length, 5);
      expect(service.condStd.length, 5);
    });

    test('Synthesizes 3.0 km closed running loop accurately', () {
      final loop = service.generateLoop(
        origin: origin,
        constraints: const RouteLoopConstraints(
          targetDistanceKm: 3.0,
          aspectRatio: 1.2,
          smoothness: 0.9,
        ),
      );

      expect(loop.isClosed, true);
      expect(loop.waypoints.first, origin);
      expect(loop.waypoints.last, origin);
      expect(loop.actualDistanceKm, closeTo(3.0, 0.08)); // Within 2.5%
      expect(loop.estimatedAreaHectares, greaterThan(2.0));
      expect(loop.estimatedXp, greaterThan(300));
      expect(loop.shapeDescriptor, 'Radial Zone');
    });

    test('Synthesizes 5.0 km elongated corridor loop', () {
      final loop = service.generateLoop(
        origin: origin,
        constraints: const RouteLoopConstraints(
          targetDistanceKm: 5.0,
          aspectRatio: 2.0,
          smoothness: 0.8,
        ),
      );

      expect(loop.isClosed, true);
      expect(loop.waypoints.first, origin);
      expect(loop.waypoints.last, origin);
      expect(loop.actualDistanceKm, closeTo(5.0, 0.12));
      expect(loop.estimatedAreaHectares, greaterThan(4.0));
      expect(loop.estimatedXp, greaterThan(600));
      expect(loop.shapeDescriptor, 'Corridor Loop');
    });

    test('Synthesizes 10.0 km endurance loop with custom waypoint density', () {
      final loop = service.generateLoop(
        origin: origin,
        constraints: const RouteLoopConstraints(
          targetDistanceKm: 10.0,
          aspectRatio: 1.5,
          smoothness: 0.85,
          numWaypoints: 48,
        ),
      );

      expect(loop.isClosed, true);
      expect(loop.waypoints.length, 49); // 48 segments + closed origin point
      expect(loop.actualDistanceKm, closeTo(10.0, 0.25));
      expect(loop.estimatedAreaHectares, greaterThan(15.0));
      expect(loop.estimatedXp, greaterThan(1200));
    });
  });
}
