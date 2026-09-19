import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../gameplay/h3_service.dart';
import '../gameplay/territory_service.dart';

/// Representation of an AI-recommended running loop route
class SuggestedRoute {
  final List<LatLng> polyline;
  final List<String> hexIds;
  final int estimatedNewTerritoryCount;
  final double totalDistanceKm;
  final double targetDistanceKm;

  const SuggestedRoute({
    required this.polyline,
    required this.hexIds,
    required this.estimatedNewTerritoryCount,
    required this.totalDistanceKm,
    required this.targetDistanceKm,
  });
}

/// AI Route Recommendation Engine.
///
/// Formulation:
/// Models route synthesis as the Orienteering Problem (OP) on the H3 geospatial graph:
/// - Nodes: Candidate H3 hexagons within the reachable bounding radius.
/// - Distance Metric: Geodesic Haversine approximation (used for fast, deterministic on-device routing).
/// - Node Prize: 1.0 if hex is unclaimed by user, 0.0 if already owned.
/// - Optimization: Two-phase pipeline:
///     1. Greedy nearest-unclaimed-hex construction with loop constraint (returning to start).
///     2. 2-opt local search improvement pass + greedy node insertions within <500ms budget.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;

  final H3Service _h3Service = H3Service();
  final TerritoryService _territoryService = TerritoryService();

  RouteService._internal();

  /// Suggests a loop route maximizing unclaimed hexes within [targetDistanceKm] budget.
  SuggestedRoute suggestRoute({
    required LatLng currentLocation,
    required double targetDistanceKm,
    Set<String>? ownedHexesOverride,
    Duration timeBudget = const Duration(milliseconds: 400),
  }) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Set<String> ownedHexes = ownedHexesOverride ?? _territoryService.getCapturedTerritories().toSet();

    final String startHexId = _h3Service.getHexagonForLocation(currentLocation.latitude, currentLocation.longitude);
    final LatLng startCenter = _h3Service.getHexagonCenter(startHexId);

    // 1. Generate candidate graph within bounding radius
    // Diameter is targetDistanceKm, so max radius from origin is ~ targetDistanceKm / 2.2
    final double maxRadiusKm = math.max(0.4, targetDistanceKm / 2.2);
    final int ringSteps = math.max(1, (maxRadiusKm / 0.12).round()).clamp(1, 15);
    final List<String> candidateHexes = _h3Service.getHexagonsInRadius(startHexId, ringSteps);

    // Filter candidate nodes with coordinates and prizes
    final Map<String, LatLng> nodeCoords = {};
    final Map<String, double> nodePrizes = {};

    for (final hex in candidateHexes) {
      final center = _h3Service.getHexagonCenter(hex);
      nodeCoords[hex] = center;
      nodePrizes[hex] = ownedHexes.contains(hex) ? 0.0 : 1.0;
    }

    // 2. Baseline Phase: Greedy Loop Construction
    List<String> route = [startHexId];
    Set<String> visited = {startHexId};
    double currentDistance = 0.0;

    while (true) {
      if (stopwatch.elapsed > timeBudget) break;

      final String currentHex = route.last;
      final LatLng currentCoord = nodeCoords[currentHex] ?? currentLocation;

      String? bestNext;
      double bestScore = -1.0;
      double bestStepDist = 0.0;

      for (final candidate in candidateHexes) {
        if (visited.contains(candidate)) continue;

        final LatLng candCoord = nodeCoords[candidate]!;
        final double distToCand = _haversineDistanceKm(currentCoord, candCoord);
        final double distBackToStart = _haversineDistanceKm(candCoord, startCenter);

        // Check if adding candidate exceeds total distance budget
        if (currentDistance + distToCand + distBackToStart <= targetDistanceKm) {
          final double prize = nodePrizes[candidate] ?? 0.0;
          // Score formula: Prize density inversely proportional to step distance
          final double score = (prize * 2.0 + 0.1) / (distToCand + 0.05);
          if (score > bestScore) {
            bestScore = score;
            bestNext = candidate;
            bestStepDist = distToCand;
          }
        }
      }

      if (bestNext != null) {
        route.add(bestNext);
        visited.add(bestNext);
        currentDistance += bestStepDist;
      } else {
        break; // No more nodes fit within the budget
      }
    }

    // Close loop back to start
    if (route.length > 1 && route.last != startHexId) {
      currentDistance += _haversineDistanceKm(nodeCoords[route.last]!, startCenter);
      route.add(startHexId);
    }

    // 3. Improvement Phase: 2-Opt Local Search & Node Insertion
    route = _optimize2Opt(route, nodeCoords, stopwatch, timeBudget);
    route = _insertAdditionalNodes(route, candidateHexes, visited, nodeCoords, nodePrizes, targetDistanceKm, stopwatch, timeBudget);

    // 4. Construct Polyline and Compute Final Stats
    final List<LatLng> polyline = [currentLocation];
    int newTerritoriesCount = 0;
    final Set<String> uniqueHexesInRoute = {};

    for (int i = 1; i < route.length - 1; i++) {
      final hex = route[i];
      polyline.add(nodeCoords[hex]!);
      if (!ownedHexes.contains(hex) && !uniqueHexesInRoute.contains(hex)) {
        newTerritoriesCount++;
      }
      uniqueHexesInRoute.add(hex);
    }
    polyline.add(currentLocation);

    final double totalDist = _computeTotalRouteDistanceKm(polyline);

    debugPrint('[RouteService] Generated ${polyline.length} pt route: ${totalDist.toStringAsFixed(2)}km, ~$newTerritoriesCount new hexes in ${stopwatch.elapsedMilliseconds}ms');

    return SuggestedRoute(
      polyline: polyline,
      hexIds: route,
      estimatedNewTerritoryCount: newTerritoriesCount,
      totalDistanceKm: totalDist,
      targetDistanceKm: targetDistanceKm,
    );
  }

  /// 2-Opt route optimizer to untangle loops and reduce edge costs
  List<String> _optimize2Opt(
    List<String> route,
    Map<String, LatLng> coords,
    Stopwatch sw,
    Duration budget,
  ) {
    if (route.length < 5) return route;

    List<String> best = List.from(route);
    bool improved = true;

    while (improved && sw.elapsed < budget) {
      improved = false;
      for (int i = 1; i < best.length - 2; i++) {
        for (int j = i + 1; j < best.length - 1; j++) {
          final double dCurrent = _haversineDistanceKm(coords[best[i - 1]]!, coords[best[i]]!) +
              _haversineDistanceKm(coords[best[j]]!, coords[best[j + 1]]!);
          final double dSwapped = _haversineDistanceKm(coords[best[i - 1]]!, coords[best[j]]!) +
              _haversineDistanceKm(coords[best[i]]!, coords[best[j + 1]]!);

          if (dSwapped < dCurrent - 0.001) {
            // Reverse segment from i to j
            final reversed = best.sublist(i, j + 1).reversed.toList();
            best = [
              ...best.sublist(0, i),
              ...reversed,
              ...best.sublist(j + 1),
            ];
            improved = true;
            break;
          }
        }
        if (improved) break;
      }
    }
    return best;
  }

  /// Greedy node insertion utilizing saved 2-opt distance margin
  List<String> _insertAdditionalNodes(
    List<String> route,
    List<String> candidates,
    Set<String> visited,
    Map<String, LatLng> coords,
    Map<String, double> prizes,
    double maxBudgetKm,
    Stopwatch sw,
    Duration budget,
  ) {
    List<String> currentRoute = List.from(route);

    for (final cand in candidates) {
      if (sw.elapsed > budget) break;
      if (visited.contains(cand) || (prizes[cand] ?? 0.0) <= 0.0) continue;

      final candCoord = coords[cand]!;
      int? bestInsertIdx;
      double minDeltaDist = double.infinity;

      for (int i = 0; i < currentRoute.length - 1; i++) {
        final p1 = coords[currentRoute[i]]!;
        final p2 = coords[currentRoute[i + 1]]!;
        final double oldDist = _haversineDistanceKm(p1, p2);
        final double newDist = _haversineDistanceKm(p1, candCoord) + _haversineDistanceKm(candCoord, p2);
        final double delta = newDist - oldDist;

        if (delta < minDeltaDist) {
          minDeltaDist = delta;
          bestInsertIdx = i + 1;
        }
      }

      if (bestInsertIdx != null) {
        final double totalDistAfter = _computeTotalHexRouteDistance(currentRoute, coords) + minDeltaDist;
        if (totalDistAfter <= maxBudgetKm) {
          currentRoute.insert(bestInsertIdx, cand);
          visited.add(cand);
        }
      }
    }

    return currentRoute;
  }

  double _computeTotalRouteDistanceKm(List<LatLng> points) {
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversineDistanceKm(points[i], points[i + 1]);
    }
    return total;
  }

  double _computeTotalHexRouteDistance(List<String> hexes, Map<String, LatLng> coords) {
    double total = 0.0;
    for (int i = 0; i < hexes.length - 1; i++) {
      total += _haversineDistanceKm(coords[hexes[i]]!, coords[hexes[i + 1]]!);
    }
    return total;
  }

  /// High-precision Haversine Distance (local geodesic approximation)
  double _haversineDistanceKm(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0088;
    final double dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
    final double dLng = (p2.longitude - p1.longitude) * math.pi / 180.0;

    final double lat1Rad = p1.latitude * math.pi / 180.0;
    final double lat2Rad = p2.latitude * math.pi / 180.0;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1Rad) * math.cos(lat2Rad);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }
}
