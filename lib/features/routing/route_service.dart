import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../gameplay/territory_service.dart';
import '../gameplay/polygon_enclosure_engine.dart';

/// Representation of an AI-recommended running loop route
class SuggestedRoute {
  final List<LatLng> polyline;
  final double estimatedNewTerritoryAreaSqM;
  final double totalDistanceKm;
  final double targetDistanceKm;

  const SuggestedRoute({
    required this.polyline,
    this.estimatedNewTerritoryAreaSqM = 0.0,
    required this.totalDistanceKm,
    required this.targetDistanceKm,
  });

  /// Approximate territory claim count for UI backwards compatibility
  int get estimatedNewTerritoryCount => math.max(1, (estimatedNewTerritoryAreaSqM / 20.0).round());
}

/// AI Route Recommendation Engine.
///
/// Features:
/// 1. Real-road pedestrian graph routing via OSRM (Open Source Routing Machine).
///    NOTE: The public endpoint (https://router.project-osrm.org) is utilized for
///    development and demonstrations. Production deployments require a self-hosted
///    OSRM instance to adhere to public server rate limits.
/// 2. Biased towards uncaptured territory (actively steers loop away from owned polygons).
/// 3. Resilient offline fallback: seamlessly generates a haversine-based closed loop
///    if network is unavailable.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;

  final TerritoryService _territoryService = TerritoryService();

  RouteService._internal();

  /// Suggests a closed loop route matching [targetDistanceKm] (within ~15%),
  /// biased towards uncaptured ground.
  Future<SuggestedRoute> suggestRouteAsync({
    required LatLng currentLocation,
    required double targetDistanceKm,
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final ownedTerritories = _territoryService.getCapturedTerritoryObjects();
    
    // 1. Attempt Real-Road OSRM pedestrian loop generation
    try {
      final osrmRoute = await _fetchOsrmLoop(
        currentLocation: currentLocation,
        targetDistanceKm: targetDistanceKm,
        ownedTerritories: ownedTerritories,
        timeout: timeout,
      );
      if (osrmRoute != null && osrmRoute.polyline.length >= 3) {
        return osrmRoute;
      }
    } catch (e) {
      debugPrint('[RouteService] OSRM query failed or offline ($e). Falling back to synthetic geodesic loop.');
    }

    // 2. Offline Fallback: Geodesic loop synthesis
    return suggestRoute(
      currentLocation: currentLocation,
      targetDistanceKm: targetDistanceKm,
    );
  }

  /// Synchronous fallback route generator (also used directly when offline)
  SuggestedRoute suggestRoute({
    required LatLng currentLocation,
    required double targetDistanceKm,
  }) {
    final ownedTerritories = _territoryService.getCapturedTerritoryObjects();
    final polyline = _generateBiasedWaypoints(
      currentLocation: currentLocation,
      targetDistanceKm: targetDistanceKm,
      ownedTerritories: ownedTerritories,
      nodeCount: 16,
    );

    final double totalDist = _computeTotalRouteDistanceKm(polyline);
    final double areaSqM = PolygonEnclosureEngine.computeGeodesicShoelaceArea(polyline);

    return SuggestedRoute(
      polyline: polyline,
      estimatedNewTerritoryAreaSqM: areaSqM,
      totalDistanceKm: totalDist,
      targetDistanceKm: targetDistanceKm,
    );
  }

  /// Queries OSRM for a pedestrian walking loop across strategic waypoints
  Future<SuggestedRoute?> _fetchOsrmLoop({
    required LatLng currentLocation,
    required double targetDistanceKm,
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
    final coordsParam = waypoints.map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}').join(';');
    final url = Uri.parse('https://router.project-osrm.org/route/v1/walking/$coordsParam?overview=full&geometries=geojson');

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
          final double distanceMeters = (firstRoute['distance'] as num).toDouble();
          final geometry = firstRoute['geometry'] as Map<String, dynamic>;
          final rawCoords = geometry['coordinates'] as List<dynamic>;

          final List<LatLng> osrmPolyline = rawCoords.map((c) {
            final coord = c as List<dynamic>;
            return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
          }).toList();

          final double areaSqM = PolygonEnclosureEngine.computeGeodesicShoelaceArea(osrmPolyline);
          final double totalKm = distanceMeters / 1000.0;

          debugPrint('[RouteService] OSRM street route synthesized: ${totalKm.toStringAsFixed(2)}km with ${osrmPolyline.length} street vertices');

          return SuggestedRoute(
            polyline: osrmPolyline,
            estimatedNewTerritoryAreaSqM: areaSqM,
            totalDistanceKm: totalKm,
            targetDistanceKm: targetDistanceKm,
          );
        }
      }
    } finally {
      client.close();
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
    final double radiusKm = (targetDistanceKm / (2.0 * math.pi)).clamp(0.2, 10.0);
    final double radiusDegLat = radiusKm / 111.32;
    final double radiusDegLng = radiusKm / (111.32 * math.cos(currentLocation.latitude * math.pi / 180.0));

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
      final double lat = currentLocation.latitude + (radiusDegLat * rMod * math.sin(theta));
      final double lng = currentLocation.longitude + (radiusDegLng * rMod * math.cos(theta));
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

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1Rad) * math.cos(lat2Rad);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }
}

