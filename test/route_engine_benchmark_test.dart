import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/routing/route_service.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RouteService routeService;
  const LatLng startPos = LatLng(37.7749, -122.4194);
  const double targetBudgetKm = 3.0; // 3km target run

  setUpAll(() async {
    Hive.init('./test_hive_route');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
    routeService = RouteService();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('Route Recommendation Engine Benchmarks', () {
    test('RouteService produces a closed valid loop within distance budget', () {
      final SuggestedRoute route = routeService.suggestRoute(
        currentLocation: startPos,
        targetDistanceKm: targetBudgetKm,
      );

      expect(route.polyline.length, greaterThanOrEqualTo(3));
      // First and last point should form a closed loop
      expect(route.polyline.first.latitude, equals(route.polyline.last.latitude));
      expect(route.polyline.first.longitude, equals(route.polyline.last.longitude));
      expect(route.totalDistanceKm, lessThanOrEqualTo(targetBudgetKm * 1.15)); // Within 15% tolerance
      expect(route.estimatedNewTerritoryAreaSqM, greaterThan(1000.0));
    });

    test('Benchmark: AI Biased Route Loop vs Random Walks on Polygon Area', () {
      final SuggestedRoute aiRoute = routeService.suggestRoute(
        currentLocation: startPos,
        targetDistanceKm: targetBudgetKm,
      );

      final double aiAreaSqM = aiRoute.estimatedNewTerritoryAreaSqM;

      // Simulate N=20 random walk closed loops of equivalent distance budget
      const int numRandomWalks = 20;
      double totalRandomAreaSqM = 0.0;
      final math.Random rng = math.Random(42); // Seeded for deterministic reproducible benchmarks

      for (int i = 0; i < numRandomWalks; i++) {
        final List<LatLng> randomLoop = [startPos];
        double currentLat = startPos.latitude;
        double currentLng = startPos.longitude;
        double heading = rng.nextDouble() * 2.0 * math.pi;

        const int steps = 12;
        final double stepKm = targetBudgetKm / (steps + 1);

        for (int s = 0; s < steps; s++) {
          heading += (rng.nextDouble() - 0.5) * 1.2; // random drift
          currentLat += (stepKm / 111.32) * math.sin(heading);
          currentLng += (stepKm / 111.32) * math.cos(heading);
          randomLoop.add(LatLng(currentLat, currentLng));
        }
        randomLoop.add(startPos); // close loop

        final double randomArea = PolygonEnclosureEngine.computeGeodesicShoelaceArea(randomLoop);
        totalRandomAreaSqM += randomArea;
      }

      final double avgRandomAreaSqM = totalRandomAreaSqM / numRandomWalks;
      final double percentImprovement = ((aiAreaSqM - avgRandomAreaSqM) / (avgRandomAreaSqM > 0 ? avgRandomAreaSqM : 1)) * 100.0;

      // ignore: avoid_print
      print('====================================================');
      // ignore: avoid_print
      print('ROUTE ENGINE BENCHMARK RESULTS:');
      // ignore: avoid_print
      print('AI Biased Loop Area  : ${aiAreaSqM.toStringAsFixed(0)} m² (${aiRoute.totalDistanceKm.toStringAsFixed(2)} km)');
      // ignore: avoid_print
      print('Average Random Walk  : ${avgRandomAreaSqM.toStringAsFixed(0)} m²');
      // ignore: avoid_print
      print('AI Route Improvement : +${percentImprovement.toStringAsFixed(1)}% new ground enclosed');
      // ignore: avoid_print
      print('====================================================');

      expect(aiAreaSqM, greaterThan(avgRandomAreaSqM),
          reason: 'AI route recommendation should outperform unguided random loops in territory acquisition');
    });
  });
}
