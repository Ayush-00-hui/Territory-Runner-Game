import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/h3_service.dart';
import 'package:territory_runner/features/routing/route_service.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RouteService routeService;
  late H3Service h3Service;
  const LatLng startPos = LatLng(37.7749, -122.4194);
  const double targetBudgetKm = 3.0; // 3km target run
  late String startHex;
  late Set<String> mockOwnedHexes;

  setUpAll(() async {
    Hive.init('./test_hive_route');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v2');
    await Hive.openBox<RunnerProfile>('profile');
    routeService = RouteService();
    h3Service = H3Service();
    startHex = h3Service.getHexagonForLocation(startPos.latitude, startPos.longitude);
    mockOwnedHexes = h3Service.getNeighbors(startHex).take(3).toSet()..add(startHex);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('Route Recommendation Engine Benchmarks', () {

    test('RouteService produces a closed valid loop within distance budget', () {
      final SuggestedRoute route = routeService.suggestRoute(
        currentLocation: startPos,
        targetDistanceKm: targetBudgetKm,
        ownedHexesOverride: mockOwnedHexes,
      );

      expect(route.polyline.length, greaterThanOrEqualTo(3));
      // First and last point should be near start position
      expect(route.polyline.first.latitude, equals(startPos.latitude));
      expect(route.polyline.last.latitude, equals(startPos.latitude));
      expect(route.totalDistanceKm, lessThanOrEqualTo(targetBudgetKm * 1.15)); // Within 15% tolerance
      expect(route.estimatedNewTerritoryCount, greaterThan(0));
    });

    test('Benchmark: RouteService Orienteering vs N Random Walks', () {
      final SuggestedRoute aiRoute = routeService.suggestRoute(
        currentLocation: startPos,
        targetDistanceKm: targetBudgetKm,
        ownedHexesOverride: mockOwnedHexes,
      );

      final int aiHexesClaimed = aiRoute.estimatedNewTerritoryCount;

      // Simulate N=20 random walks of equivalent distance budget
      const int numRandomWalks = 20;
      int totalRandomHexes = 0;
      final math.Random rng = math.Random(42);

      for (int i = 0; i < numRandomWalks; i++) {
        final Set<String> visitedInRandom = {};
        double distWalked = 0.0;
        String currentHex = startHex;

        while (distWalked < targetBudgetKm) {
          final neighbors = h3Service.getNeighbors(currentHex);
          final nextHex = neighbors[rng.nextInt(neighbors.length)];
          final LatLng nextCenter = h3Service.getHexagonCenter(nextHex);
          final LatLng startCenter = h3Service.getHexagonCenter(startHex);
          final double returnDist = (Geolocator.distanceBetween(
                nextCenter.latitude,
                nextCenter.longitude,
                startCenter.latitude,
                startCenter.longitude,
              ) /
              1000.0);

          if (distWalked + 0.13 + returnDist > targetBudgetKm) {
            break;
          }

          if (!mockOwnedHexes.contains(nextHex)) {
            visitedInRandom.add(nextHex);
          }
          distWalked += 0.13;
          currentHex = nextHex;
        }
        totalRandomHexes += visitedInRandom.length;
      }

      final double avgRandomHexes = totalRandomHexes / numRandomWalks;
      final double percentImprovement = ((aiHexesClaimed - avgRandomHexes) / (avgRandomHexes > 0 ? avgRandomHexes : 1)) * 100.0;

      // ignore: avoid_print
      print('====================================================');
      // ignore: avoid_print
      print('ROUTE ENGINE BENCHMARK RESULTS:');
      // ignore: avoid_print
      print('AI Orienteering Route: $aiHexesClaimed new hexes (${aiRoute.totalDistanceKm.toStringAsFixed(2)} km)');
      // ignore: avoid_print
      print('Average Random Walk  : ${avgRandomHexes.toStringAsFixed(1)} new hexes');
      // ignore: avoid_print
      print('AI Route Improvement : +${percentImprovement.toStringAsFixed(1)}% new territory claimed');
      // ignore: avoid_print
      print('====================================================');

      expect(aiHexesClaimed, greaterThanOrEqualTo(avgRandomHexes.round()),
          reason: 'AI route recommendation should outperform random walks in territory acquisition efficiency');
    });
  });
}
