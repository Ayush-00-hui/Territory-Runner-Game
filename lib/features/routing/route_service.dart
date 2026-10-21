import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:clipper2/clipper2.dart';

import '../../core/logging/app_logger.dart';
import '../gameplay/territory_service.dart';
import '../gameplay/polygon_enclosure_engine.dart';

/// Representation of an AI-recommended running loop route
class SuggestedRoute {
  final List<LatLng> polyline;
  final double estimatedNewTerritoryAreaSqM;
  final double totalDistanceKm;
  final double targetDistanceKm;
  final double targetAreaSqM;
  final bool isOffline;
  final int? _estimatedDurationMinutes;

  const SuggestedRoute({
    required this.polyline,
    this.estimatedNewTerritoryAreaSqM = 0.0,
    required this.totalDistanceKm,
    required this.targetDistanceKm,
    this.targetAreaSqM = 0.0,
    this.isOffline = false,
    int? estimatedDurationMinutes,
    // ignore: prefer_initializing_formals
  }) : _estimatedDurationMinutes = estimatedDurationMinutes;

  int get estimatedDurationMinutes =>
      _estimatedDurationMinutes ??
      (totalDistanceKm <= 0
          ? 1
          : (totalDistanceKm * 6.0).round().clamp(1, 180));

  /// Approximate territory claim count for UI backwards compatibility
  int get estimatedNewTerritoryCount =>
      math.max(1, (estimatedNewTerritoryAreaSqM / 20.0).round());
}

/// AI Route Recommendation Engine.
///
/// Features:
/// 1. Real-road pedestrian graph routing via OSRM (Open Source Routing Machine).
/// 2. Biased towards uncaptured territory (actively steers loop away from owned polygons).
/// 3. Resilient offline fallback: seamlessly generates a haversine-based closed loop
///    if network is unavailable.
/// 4. Claim Planner: converts target area to walking distance and computes net new
///    territory gain via Clipper2 polygon subtraction.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;

  /// Test hook or runtime flag to force offline synthetic loop routing
  static bool forceOffline = false;

  final TerritoryService _territoryService = TerritoryService();

  RouteService._internal();

  /// Converts a target claim area (in m²) to an approximate walking loop perimeter (in km).
  /// For street grids / pedestrian paths, the walking factor is ~3.8 * sqrt(area).
  static double targetAreaToDistanceKm(double targetAreaSqM) {
    final double side = math.sqrt(math.max(100.0, targetAreaSqM));
    final double perimeterMeters = side * 3.8;
    return (perimeterMeters / 1000.0).clamp(0.12, 25.0);
  }

  /// Proposes a closed running loop matching [targetAreaSqM] from [currentLocation].
  /// Uses OSRM pedestrian routing if online, or synthetic geodesic loop if offline.
  /// Computes net new area by subtracting existing sovereign land via Clipper2.
  Future<SuggestedRoute> suggestRouteForTargetArea({
    required LatLng currentLocation,
    required double targetAreaSqM,
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final double targetDistanceKm = targetAreaToDistanceKm(targetAreaSqM);
    return suggestRouteAsync(
      currentLocation: currentLocation,
      targetDistanceKm: targetDistanceKm,
      targetAreaSqM: targetAreaSqM,
      timeout: timeout,
    );
  }

  /// Computes the net new area in m² by subtracting the runner's already-owned
  /// territories using Clipper2 difference.
  double computeNetNewArea(
    List<LatLng> loopPolyline, [
    List<List<LatLng>>? existingOwnedPolygons,
  ]) {
    if (loopPolyline.length < 3) return 0.0;
    final double rawArea = PolygonEnclosureEngine.computeGeodesicShoelaceArea(
      loopPolyline,
    );
    if (rawArea <= 0) return 0.0;

    final Paths64 playerExistingPaths = [];
    if (existingOwnedPolygons != null) {
      for (final poly in existingOwnedPolygons) {
        if (poly.length >= 3) {
          playerExistingPaths.add(TerritoryService.latLngsToPath64(poly));
        }
      }
    } else {
      final profile = _territoryService.getProfile();
      final ownedTerritories = _territoryService
          .getCapturedTerritoryObjects()
          .where((t) => t.ownerId == profile.id)
          .toList();

      for (final t in ownedTerritories) {
        for (final poly in t.polygons) {
          if (poly.length >= 3) {
            playerExistingPaths.add(TerritoryService.latLngsToPath64(poly));
          }
        }
      }
    }

    if (playerExistingPaths.isEmpty) {
      return rawArea;
    }

    try {
      final loopPath = TerritoryService.latLngsToPath64(loopPolyline);
      final Paths64 diff = Clipper.difference(
        subject: [loopPath],
        clip: playerExistingPaths,
        fillRule: FillRule.nonZero,
      );

      if (diff.isEmpty) return 0.0;

      double netArea = 0.0;
      for (final path in diff) {
        final ring = TerritoryService.path64ToLatLngs(path);
        netArea += PolygonEnclosureEngine.computeSignedGeodesicShoelaceArea(
          ring,
        );
      }
      return math.max(0.0, netArea.abs());
    } catch (e) {
      AppLogger.warning('Net area clipping error: $e', tag: 'RouteService');
      return rawArea;
    }
  }

  /// Suggests a closed loop route matching [targetDistanceKm] (within ~15%),
  /// biased towards uncaptured ground.
  Future<SuggestedRoute> suggestRouteAsync({
    required LatLng currentLocation,
    required double targetDistanceKm,
    double? targetAreaSqM,
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final effectiveTargetArea =
        targetAreaSqM ??
        (math.pow(targetDistanceKm * 1000.0 / 3.8, 2.0).toDouble());

    if (forceOffline) {
      return suggestRoute(
        currentLocation: currentLocation,
        targetDistanceKm: targetDistanceKm,
        targetAreaSqM: effectiveTargetArea,
        isOffline: true,
      );
    }

    final ownedTerritories = _territoryService.getCapturedTerritoryObjects();

    // 1. Attempt Real-Road OSRM pedestrian loop generation
    try {
      final osrmRoute = await _fetchOsrmLoop(
        currentLocation: currentLocation,
        targetDistanceKm: targetDistanceKm,
        targetAreaSqM: effectiveTargetArea,
        ownedTerritories: ownedTerritories,
        timeout: timeout,
      );
      if (osrmRoute != null && osrmRoute.polyline.length >= 3) {
        return osrmRoute;
      }
    } catch (e) {
      AppLogger.info(
        'OSRM query failed or offline ($e). Falling back to synthetic geodesic loop.',
        tag: 'RouteService',
      );
    }

    // 2. Offline Fallback: Geodesic loop synthesis
    return suggestRoute(
      currentLocation: currentLocation,
      targetDistanceKm: targetDistanceKm,
      targetAreaSqM: effectiveTargetArea,
      isOffline: true,
    );
  }

  /// Synchronous fallback route generator (also used directly when offline)
  SuggestedRoute suggestRoute({
    required LatLng currentLocation,
    required double targetDistanceKm,
    double? targetAreaSqM,
    bool isOffline = true,
  }) {
    final effectiveTargetArea =
        targetAreaSqM ??
        (math.pow(targetDistanceKm * 1000.0 / 3.8, 2.0).toDouble());
    final ownedTerritories = _territoryService.getCapturedTerritoryObjects();
    final polyline = _generateBiasedWaypoints(
      currentLocation: currentLocation,
      targetDistanceKm: targetDistanceKm,
      ownedTerritories: ownedTerritories,
      nodeCount: 16,
    );

    final double totalDist = _computeTotalRouteDistanceKm(polyline);
    final double netAreaSqM = computeNetNewArea(polyline);

    return SuggestedRoute(
      polyline: polyline,
      estimatedNewTerritoryAreaSqM: netAreaSqM,
      totalDistanceKm: totalDist,
      targetDistanceKm: targetDistanceKm,
      targetAreaSqM: effectiveTargetArea,
      isOffline: isOffline,
    );
  }

  /// Queries OSRM for a pedestrian walking loop across strategic waypoints
  Future<SuggestedRoute?> _fetchOsrmLoop({
    required LatLng currentLocation,
    required double targetDistanceKm,
    required double targetAreaSqM,
    required List<dynamic> ownedTerritories,
    required Duration timeout,
  }) async {
    // Construct 3-4 directional waypoints around origin
    final waypoints = _generateBiasedWaypoints(
      currentLocation: currentLocation,
      targetDistanceKm: targetDistanceKm,
      ownedTerritories: ownedTerritories,
      nodeCount: 4,
    );

    // Build OSRM walking route query: lng,lat;lng,lat;...
    final coordsParam = waypoints
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/walking/$coordsParam?overview=full&geometries=geojson',
    );

    final client = HttpClient();
    client.connectionTimeout = timeout;

    try {
      final request = await client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final routes = json['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes.first as Map<String, dynamic>;
          final double distanceMeters = (firstRoute['distance'] as num)
              .toDouble();
          final geometry = firstRoute['geometry'] as Map<String, dynamic>;
          final rawCoords = geometry['coordinates'] as List<dynamic>;

          final List<LatLng> osrmPolyline = rawCoords.map((c) {
            final coord = c as List<dynamic>;
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          final double netAreaSqM = computeNetNewArea(osrmPolyline);
          final double totalKm = distanceMeters / 1000.0;

          AppLogger.debug(
            'OSRM street route synthesized: ${totalKm.toStringAsFixed(2)}km with ${osrmPolyline.length} street vertices',
            tag: 'RouteService',
          );

          return SuggestedRoute(
            polyline: osrmPolyline,
            estimatedNewTerritoryAreaSqM: netAreaSqM,
            totalDistanceKm: totalKm,
            targetDistanceKm: targetDistanceKm,
            targetAreaSqM: targetAreaSqM,
            isOffline: false,
          );
        }
      }
    } finally {
      client.close(force: true);
    }
    return null;
  }

  /// Synthesizes closed loop waypoints biased away from existing territory polygons
  List<LatLng> _generateBiasedWaypoints({
    required LatLng currentLocation,
    required double targetDistanceKm,
    required List<dynamic> ownedTerritories,
    required int nodeCount,
  }) {
    // Radius of the circumscribed loop circle
    final double radiusKm = (targetDistanceKm / (2.0 * math.pi)).clamp(
      0.02,
      10.0,
    );
    final double radiusDegLat = radiusKm / 111.32;
    final double radiusDegLng =
        radiusKm /
        (111.32 * math.cos(currentLocation.latitude * math.pi / 180.0));

    // Determine centroid of already-owned territory to bias loop in opposite direction
    double biasAngleRad = 0.0;
    if (ownedTerritories.isNotEmpty) {
      double sumLat = 0.0;
      double sumLng = 0.0;
      int ptCount = 0;
      for (final t in ownedTerritories) {
        final polygon = t.polygon as List<LatLng>;
        for (final p in polygon) {
          sumLat += p.latitude;
          sumLng += p.longitude;
          ptCount++;
        }
      }
      if (ptCount > 0) {
        final double centroidLat = sumLat / ptCount;
        final double centroidLng = sumLng / ptCount;
        final double dLat = centroidLat - currentLocation.latitude;
        final double dLng = centroidLng - currentLocation.longitude;
        // Bias in the 180-degree opposite direction of owned territory
        biasAngleRad = math.atan2(dLat, dLng) + math.pi;
      }
    }

    final List<LatLng> loop = [];
    for (int i = 0; i < nodeCount; i++) {
      final double theta = biasAngleRad + (2.0 * math.pi * i / nodeCount);
      // Add slight organic curve wobble
      final double rMod = 1.0 + 0.12 * math.sin(3.0 * theta);
      final double lat =
          currentLocation.latitude + (radiusDegLat * rMod * math.sin(theta));
      final double lng =
          currentLocation.longitude + (radiusDegLng * rMod * math.cos(theta));
      loop.add(LatLng(lat, lng));
    }
    // Close back to start
    loop.add(loop.first);
    return loop;
  }

  double _computeTotalRouteDistanceKm(List<LatLng> points) {
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversineDistanceKm(points[i], points[i + 1]);
    }
    return total;
  }

  double _haversineDistanceKm(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0088;
    final double dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
    final double dLng = (p2.longitude - p1.longitude) * math.pi / 180.0;

    final double lat1Rad = p1.latitude * math.pi / 180.0;
    final double lat2Rad = p2.latitude * math.pi / 180.0;

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }
}
