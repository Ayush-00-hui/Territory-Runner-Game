import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/constants.dart';
import '../../../models/territory.dart';
import '../../../models/ws_events.dart';
import '../../../ui/theme/app_colors.dart';

/// Performance-optimized Map Layers component wrapped in a RepaintBoundary.
class MapLayers {
  MapLayers._();

  /// Dark-mode global map tile layer
  static TileLayer buildTileLayer() {
    return TileLayer(
      urlTemplate: AppConstants.mapApiKey.isNotEmpty
          ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}'
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      maxZoom: 19,
      userAgentPackageName: 'com.example.territory_runner',
      tileBuilder: (context, tileWidget, tile) {
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            -0.82, 0, 0, 0, 230,
            0, -0.82, 0, 0, 230,
            0, 0, -0.82, 0, 230,
            0, 0, 0, 1.0, 0,
          ]),
          child: tileWidget,
        );
      },
    );
  }

  /// Sovereign & Rival Territory Multi-Polygons Layer
  static PolygonLayer buildPolygonLayer(
    List<Territory> territories, {
    String? highlightedTerritoryId,
  }) {
    final List<Polygon> polygons = [];

    for (final territory in territories) {
      final double currentStrength = territory.computeCurrentStrength();
      // Strength shown as outline opacity (from 0.25 at 0% strength to 1.0 at 100%)
      final double outlineAlpha = (0.25 + 0.75 * (currentStrength / 100.0)).clamp(0.20, 1.0);
      final bool isHighlighted = territory.id == highlightedTerritoryId;

      final Color borderColor = isHighlighted
          ? AppColors.gold
          : territory.color.withValues(alpha: outlineAlpha);
      final double strokeWidth = isHighlighted
          ? 4.0
          : (territory.isWeak() ? 1.5 : 2.5);

      final Color fillColor = isHighlighted
          ? AppColors.gold.withValues(alpha: 0.35)
          : territory.color.withValues(alpha: (0.25 * (currentStrength / 100.0)).clamp(0.12, 0.30));

      for (final poly in territory.polygons) {
        if (poly.length >= 3) {
          polygons.add(
            Polygon(
              points: poly,
              color: fillColor,
              borderColor: borderColor,
              borderStrokeWidth: strokeWidth,
            ),
          );
        }
      }
    }

    return PolygonLayer(polygons: polygons);
  }

  /// Small athletic strength badges positioned at territory centroids
  static MarkerLayer buildTerritoryBadgesLayer(List<Territory> territories) {
    final List<Marker> badges = [];

    for (final territory in territories) {
      if (territory.polygon.length < 3) continue;
      final centroid = computeCentroid(territory.polygon);
      final currentStrength = territory.computeCurrentStrength();
      final isWeak = territory.isWeak();

      final Color badgeColor = isWeak
          ? AppColors.rival
          : (currentStrength >= 70 ? AppColors.mine : AppColors.warning);

      badges.add(
        Marker(
          point: centroid,
          width: 68,
          height: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.25),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isWeak ? Icons.warning_amber_rounded : Icons.shield_rounded,
                  size: 11,
                  color: badgeColor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${currentStrength.round()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MarkerLayer(markers: badges);
  }

  static LatLng computeCentroid(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(0, 0);
    double lat = 0;
    double lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  /// Active breadcrumbs, in-progress enclosure path, and AI route polyline layer
  static PolylineLayer buildPolylineLayer({
    required bool isRunActive,
    required List<LatLng> runCoordinates,
    required List<LatLng> currentEnclosurePath,
    List<LatLng>? suggestedRouteCoordinates,
  }) {
    return PolylineLayer(
      polylines: [
        if (isRunActive && runCoordinates.length >= 2)
          Polyline(
            points: runCoordinates,
            color: AppColors.mine,
            strokeWidth: 4.0,
          ),
        if (currentEnclosurePath.length >= 2)
          Polyline(
            points: currentEnclosurePath,
            color: AppColors.info,
            strokeWidth: 2.5,
          ),
        if (suggestedRouteCoordinates != null && suggestedRouteCoordinates.length >= 2)
          Polyline(
            points: suggestedRouteCoordinates,
            color: AppColors.secondary,
            strokeWidth: 4.0,
          ),
      ],
    );
  }

  /// Waypoint and live rival presence marker layer
  static MarkerLayer buildMarkerLayer({
    required LatLng? currentLocation,
    required Map<String, RunnerPresenceEvent> activeRivalRunners,
  }) {
    final List<Marker> markers = [];

    // User Waypoint Marker (Glowing Blue Pin)
    if (currentLocation != null) {
      markers.add(
        Marker(
          point: currentLocation,
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2979FF).withValues(alpha: 0.25),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2979FF),
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2979FF).withValues(alpha: 0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active Rival Runners broadcast over real-time WebSocket
    for (final rival in activeRivalRunners.values) {
      markers.add(
        Marker(
          point: rival.position,
          width: 90,
          height: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.rival, width: 1.2),
                ),
                child: Text(
                  rival.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Transform.rotate(
                angle: rival.heading * (math.pi / 180.0),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.rival,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }
}
