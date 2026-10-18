import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/constants.dart';
import '../../../models/territory.dart';
import '../../../models/ws_events.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../services/tile_cache_service.dart';
import '../../gameplay/polygon_enclosure_engine.dart';

/// Performance-optimized Map Layers component wrapped in a RepaintBoundary.
class MapLayers {
  MapLayers._();

  /// Dark-mode global map tile layer with offline disk caching
  static TileLayer buildTileLayer() {
    return TileLayer(
      urlTemplate: AppConstants.mapApiKey.isNotEmpty
          ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}'
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      maxZoom: 19,
      userAgentPackageName: 'com.territoryrunner.app',
      tileProvider: OfflineFirstTileProvider(),
      tileBuilder: (context, tileWidget, tile) {
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            -0.85, 0, 0, 0, 220,
            0, -0.85, 0, 0, 220,
            0, 0, -0.85, 0, 220,
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
    String? currentUserId,
  }) {
    final List<Polygon> polygons = [];

    for (final territory in territories) {
      final double currentStrength = territory.computeCurrentStrength();
      // Strength shown as outline opacity (from 0.25 at 0% strength to 1.0 at 100%)
      final double outlineAlpha = (0.25 + 0.75 * (currentStrength / 100.0)).clamp(0.20, 1.0);
      final bool isHighlighted = territory.id == highlightedTerritoryId;
      final bool isRival = territory.color == AppColors.rival ||
          territory.id.contains('rival') ||
          (currentUserId != null && territory.ownerId.isNotEmpty && territory.ownerId != currentUserId);

      final Color borderColor;
      final Color fillColor;
      final double strokeWidth;

      if (isHighlighted) {
        borderColor = AppColors.gold;
        fillColor = AppColors.gold.withValues(alpha: 0.35);
        strokeWidth = 3.0;
      } else if (isRival) {
        borderColor = AppColors.territoryRivalBorder.withValues(alpha: outlineAlpha);
        fillColor = AppColors.territoryRivalFill.withValues(alpha: (0.14 * (currentStrength / 100.0)).clamp(0.08, 0.20));
        strokeWidth = 1.5;
      } else {
        borderColor = AppColors.territoryMineBorder.withValues(alpha: outlineAlpha);
        fillColor = AppColors.territoryMineFill.withValues(alpha: (0.16 * (currentStrength / 100.0)).clamp(0.10, 0.25));
        strokeWidth = 1.5;
      }

      final shells = classifyRings(territory.polygons);
      for (final shell in shells) {
        polygons.add(
          Polygon(
            points: shell.outer,
            holePointsList: shell.holes.isNotEmpty ? shell.holes : null,
            color: fillColor,
            borderColor: borderColor,
            borderStrokeWidth: strokeWidth,
          ),
        );
      }
    }

    return PolygonLayer(polygons: polygons);
  }

  /// Ray-casting point-in-polygon containment test.
  /// Determines if [point] lies strictly inside [polygon].
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    final double x = point.longitude;
    final double y = point.latitude;
    final int n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final bool intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Classifies a set of rings into outer boundaries (shells) and inner holes.
  /// An inner hole is placed inside the smallest enclosing outer shell.
  /// If a ring is contained inside an odd number of other rings, it is a hole.
  /// If contained by an even number (0, 2, ...), it is an exterior boundary (shell).
  static List<PolygonShell> classifyRings(List<List<LatLng>> rawRings) {
    final validRings = rawRings.where((r) => r.length >= 3).toList();
    if (validRings.isEmpty) return const [];
    if (validRings.length == 1) {
      return [PolygonShell(validRings.first)];
    }

    // Pre-calculate geodesic area for each ring
    final areas = validRings
        .map((r) => PolygonEnclosureEngine.computeGeodesicShoelaceArea(r))
        .toList();

    // Check if inner ring is enclosed by outer ring
    bool ringIsEnclosedBy(int innerIdx, int outerIdx) {
      if (areas[outerIdx] <= areas[innerIdx]) return false;
      final innerRing = validRings[innerIdx];
      final outerRing = validRings[outerIdx];
      int insideCount = 0;
      int testedCount = 0;
      final int step = math.max(1, innerRing.length ~/ 4);
      for (int i = 0; i < innerRing.length && testedCount < 4; i += step) {
        testedCount++;
        if (isPointInPolygon(innerRing[i], outerRing)) {
          insideCount++;
        }
      }
      return insideCount > (testedCount ~/ 2);
    }

    // For each ring, count how many other rings strictly enclose it
    final List<int> enclosureCounts = List.filled(validRings.length, 0);
    final List<List<int>> enclosingRings = List.generate(validRings.length, (_) => []);

    for (int i = 0; i < validRings.length; i++) {
      for (int j = 0; j < validRings.length; j++) {
        if (i != j && ringIsEnclosedBy(i, j)) {
          enclosureCounts[i]++;
          enclosingRings[i].add(j);
        }
      }
    }

    // Even count = outer shell, Odd count = hole
    final shells = <int, PolygonShell>{};
    final holeIndices = <int>[];

    for (int i = 0; i < validRings.length; i++) {
      if (enclosureCounts[i] % 2 == 0) {
        shells[i] = PolygonShell(validRings[i]);
      } else {
        holeIndices.add(i);
      }
    }

    // Assign each hole to the smallest enclosing outer shell
    for (final hIdx in holeIndices) {
      int? bestShellIdx;
      double smallestShellArea = double.infinity;

      for (final sIdx in enclosingRings[hIdx]) {
        if (shells.containsKey(sIdx) && areas[sIdx] < smallestShellArea) {
          smallestShellArea = areas[sIdx];
          bestShellIdx = sIdx;
        }
      }

      if (bestShellIdx != null) {
        shells[bestShellIdx]!.holes.add(validRings[hIdx]);
      } else {
        shells[hIdx] = PolygonShell(validRings[hIdx]);
      }
    }

    return shells.values.toList();
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
              border: Border.all(color: badgeColor.withValues(alpha: 0.8), width: 1.0),
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
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

  /// Active breadcrumbs, in-progress enclosure path, suggested route, and rival breadcrumbs
  static PolylineLayer buildPolylineLayer({
    required bool isRunActive,
    required List<LatLng> runCoordinates,
    required List<LatLng> currentEnclosurePath,
    List<LatLng>? suggestedRouteCoordinates,
    Map<String, List<LatLng>>? rivalBreadcrumbs,
    Map<String, RunnerPresenceEvent>? activeRivalRunners,
  }) {
    return PolylineLayer(
      polylines: [
        // Live Rival Moving Breadcrumb Trails
        if (rivalBreadcrumbs != null)
          for (final entry in rivalBreadcrumbs.entries)
            if (entry.value.length >= 2)
              Polyline(
                points: entry.value,
                color: _resolveRivalColor(entry.key, activeRivalRunners),
                strokeWidth: 2.0,
              ),
        // Local Runner Trail: Solid 2.5px Pacer Blue (accent), NO glow
        if (isRunActive && runCoordinates.length >= 2)
          Polyline(
            points: runCoordinates,
            color: AppColors.accent,
            strokeWidth: 2.5,
          ),
        // Enclosure Proximity Path
        if (currentEnclosurePath.length >= 2)
          Polyline(
            points: currentEnclosurePath,
            color: AppColors.info,
            strokeWidth: 2.0,
          ),
        // AI Suggested Route: Clean 2.5px line, NO glow
        if (suggestedRouteCoordinates != null && suggestedRouteCoordinates.length >= 2)
          Polyline(
            points: suggestedRouteCoordinates,
            color: AppColors.accent.withValues(alpha: 0.6),
            strokeWidth: 2.5,
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

    // User Position Marker: Crisp geometric circle with center notch, NO pulsing rings, NO glow
    if (currentLocation != null) {
      markers.add(
        Marker(
          point: currentLocation,
          width: 28,
          height: 28,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.bgDeep, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Active Rival Runners broadcast over real-time WebSocket
    for (final rival in activeRivalRunners.values) {
      final rivalColor = getFactionColor(rival.faction);
      final speedKmh = rival.speed * 3.6;

      markers.add(
        Marker(
          point: rival.position,
          width: 110,
          height: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clean Callsign & Speed Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rivalColor.withValues(alpha: 0.6), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rivalColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rival.username,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (speedKmh > 0.5) ...[
                      const SizedBox(width: 4),
                      Text(
                        '⚡${speedKmh.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: rivalColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Directional Heading Indicator (crisp geometric icon, NO glow)
              Transform.rotate(
                angle: rival.heading * (math.pi / 180.0),
                child: Icon(
                  Icons.navigation_rounded,
                  color: rivalColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  /// Maps faction name to dedicated cyber aesthetic accent color
  static Color getFactionColor(String faction) {
    final lower = faction.toLowerCase();
    if (lower.contains('vanguard') || lower.contains('cyan') || lower.contains('cyber')) {
      return AppColors.info;
    }
    if (lower.contains('iron') || lower.contains('legion') || lower.contains('solar')) {
      return AppColors.secondary;
    }
    return AppColors.rival;
  }

  static Color _resolveRivalColor(
    String userId,
    Map<String, RunnerPresenceEvent>? rivals,
  ) {
    if (rivals != null && rivals.containsKey(userId)) {
      return getFactionColor(rivals[userId]!.faction);
    }
    return AppColors.rival;
  }
}

class PolygonShell {
  final List<LatLng> outer;
  final List<List<LatLng>> holes = [];
  PolygonShell(this.outer);
}
