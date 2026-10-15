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
  static PolygonLayer buildPolygonLayer(List<Territory> territories) {
    final List<Polygon> polygons = [];

    for (final territory in territories) {
      for (final poly in territory.polygons) {
        if (poly.length >= 3) {
          polygons.add(
            Polygon(
              points: poly,
              color: territory.color.withValues(alpha: 0.25),
              borderColor: territory.color,
              borderStrokeWidth: 2.5,
            ),
          );
        }
      }
    }

    return PolygonLayer(polygons: polygons);
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
