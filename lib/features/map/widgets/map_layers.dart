import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/constants.dart';
import '../../../models/territory.dart';
import '../../../models/ws_events.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_palette.dart';
import '../../../services/tile_cache_service.dart';
import '../../gameplay/polygon_enclosure_engine.dart';
import 'ghost_runner_marker.dart';

/// Performance-optimized Map Layers component wrapped in a RepaintBoundary.
class MapLayers {
  MapLayers._();

  /// High-visibility global map tile layer with offline disk caching and OpenStreetMap by default
  static TileLayer buildTileLayer({bool isLight = false}) {
    String urlTemplate;
    final Map<String, String> additionalOptions = {};

    if (AppConstants.tileApiKey.isNotEmpty) {
      additionalOptions['accessToken'] = AppConstants.tileApiKey;
      additionalOptions['apiKey'] = AppConstants.tileApiKey;
    }

    if (AppConstants.tileUrlTemplate != AppConstants.cartoVoyagerUrlTemplate &&
        AppConstants.tileUrlTemplate != AppConstants.defaultOsmUrlTemplate) {
      // User explicitly configured a custom TILE_URL_TEMPLATE
      urlTemplate = AppConstants.tileUrlTemplate;
    } else if (AppConstants.tileApiKey.isNotEmpty) {
      if (AppConstants.tileApiKey.startsWith('pk.') ||
          AppConstants.mapApiKey.isNotEmpty) {
        urlTemplate = isLight
            ? 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token={accessToken}'
            : 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}';
      } else {
        urlTemplate = isLight
            ? 'https://basemaps.cartocdn.com/rastertiles/light_all/{z}/{x}/{y}@2x.png?key={apiKey}'
            : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png?key={apiKey}';
      }
    } else {
      urlTemplate = AppConstants.tileUrlTemplate;
    }

    // If CARTO template is used with an API key, ensure key parameter is present
    if (urlTemplate.contains('cartocdn.com') &&
        AppConstants.tileApiKey.isNotEmpty &&
        !urlTemplate.contains('{apiKey}') &&
        !urlTemplate.contains('key=')) {
      urlTemplate = urlTemplate.contains('?')
          ? '$urlTemplate&key={apiKey}'
          : '$urlTemplate?key={apiKey}';
    }

    return TileLayer(
      urlTemplate: urlTemplate,
      additionalOptions: additionalOptions,
      maxZoom: 19,
      userAgentPackageName: 'com.territoryrunner.app',
      tileProvider: OfflineFirstTileProvider(
        headers: {'User-Agent': AppConstants.userAgent},
      ),
    );
  }

  /// Player & Rival Territory Multi-Polygons Layer
  static PolygonLayer buildPolygonLayer(
    List<Territory> territories, {
    String? highlightedTerritoryId,
    String? currentUserId,
    AppPalette palette = AppPalette.dark,
  }) {
    final List<Polygon> polygons = [];

    for (final territory in territories) {
      final double currentStrength = territory.computeCurrentStrength();
      // Strength shown as outline opacity (from 0.35 at 0% strength to 1.0 at 100%)
      final double outlineAlpha = (0.35 + 0.65 * (currentStrength / 100.0))
          .clamp(0.30, 1.0);
      final bool isHighlighted = territory.id == highlightedTerritoryId;
      final bool isRival =
          territory.color == AppColors.rival ||
          territory.id.contains('rival') ||
          (currentUserId != null &&
              territory.ownerId.isNotEmpty &&
              territory.ownerId != currentUserId);

      final Color borderColor;
      final Color fillColor;
      final double strokeWidth;
      final StrokePattern pattern;

      if (isHighlighted) {
        borderColor = palette.gold;
        fillColor = palette.gold.withValues(alpha: 0.35);
        strokeWidth = 3.0;
        pattern = const StrokePattern.solid();
      } else if (isRival) {
        borderColor = palette.territoryRivalBorder.withValues(
          alpha: outlineAlpha,
        );
        fillColor = palette.territoryRivalFill.withValues(
          alpha: (0.16 * (currentStrength / 100.0)).clamp(0.10, 0.24),
        );
        strokeWidth = 2.0;
        pattern = StrokePattern.dashed(segments: const [7.0, 4.0]);
      } else {
        borderColor = palette.territoryMineBorder.withValues(
          alpha: outlineAlpha,
        );
        fillColor = palette.territoryMineFill.withValues(
          alpha: (0.18 * (currentStrength / 100.0)).clamp(0.12, 0.28),
        );
        strokeWidth = 2.0;
        pattern = const StrokePattern.solid();
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
            pattern: pattern,
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

      final bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
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
    final List<List<int>> enclosingRings = List.generate(
      validRings.length,
      (_) => [],
    );

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
  static MarkerLayer buildTerritoryBadgesLayer(
    List<Territory> territories, {
    AppPalette palette = AppPalette.dark,
  }) {
    final List<Marker> badges = [];

    for (final territory in territories) {
      if (territory.polygon.length < 3) continue;
      final centroid = computeCentroid(territory.polygon);
      final currentStrength = territory.computeCurrentStrength();
      final isWeak = territory.isWeak();

      final Color badgeColor = isWeak
          ? palette.rival
          : (currentStrength >= 70 ? palette.mine : palette.warning);

      badges.add(
        Marker(
          point: centroid,
          width: 68,
          height: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: palette.surfaceGlass,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.8),
                width: 1.0,
              ),
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
                    color: palette.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
    AppPalette palette = AppPalette.dark,
  }) {
    return PolylineLayer(
      polylines: [
        // Live Rival Moving Breadcrumb Trails
        if (rivalBreadcrumbs != null)
          for (final entry in rivalBreadcrumbs.entries)
            if (entry.value.length >= 2)
              Polyline(
                points: entry.value,
                color: _resolveRivalColor(
                  entry.key,
                  activeRivalRunners,
                  palette: palette,
                ),
                strokeWidth: 2.0,
              ),
        // Local Runner Trail: Solid 2.5px Pacer Blue (accent), NO glow
        if (isRunActive && runCoordinates.length >= 2)
          Polyline(
            points: runCoordinates,
            color: palette.accent,
            strokeWidth: 2.5,
          ),
        // Enclosure Proximity Path
        if (currentEnclosurePath.length >= 2)
          Polyline(
            points: currentEnclosurePath,
            color: palette.info,
            strokeWidth: 2.0,
          ),
        // AI Suggested Route: Clean 2.5px line, NO glow
        if (suggestedRouteCoordinates != null &&
            suggestedRouteCoordinates.length >= 2)
          Polyline(
            points: suggestedRouteCoordinates,
            color: palette.accent.withValues(alpha: 0.6),
            strokeWidth: 2.5,
          ),
      ],
    );
  }

  /// Waypoint, live rival presence, and ghost runner marker layer
  static MarkerLayer buildMarkerLayer({
    required LatLng? currentLocation,
    required Map<String, RunnerPresenceEvent> activeRivalRunners,
    LatLng? ghostLocation,
    bool isBatterySaverActive = false,
    bool isReducedMotion = false,
    AppPalette palette = AppPalette.dark,
  }) {
    final List<Marker> markers = [];

    // Ghost Runner Marker: Neutral circular node with dashed ring, zero glow
    if (ghostLocation != null) {
      markers.add(
        Marker(
          point: ghostLocation,
          width: 32,
          height: 32,
          child: GhostRunnerMarkerWidget(
            isBatterySaverActive: isBatterySaverActive,
            isReducedMotion: isReducedMotion,
          ),
        ),
      );
    }

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
                color: palette.accent,
                border: Border.all(color: palette.bgDeep, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.onAccent,
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
      final rivalColor = getFactionColor(rival.faction, palette: palette);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rivalColor.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
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
                        style: TextStyle(
                          color: palette.textPrimary,
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

  /// Maps faction name to dedicated accent color
  static Color getFactionColor(
    String faction, {
    AppPalette palette = AppPalette.dark,
  }) {
    final lower = faction.toLowerCase();
    if (lower.contains('blue') ||
        lower.contains('cyan') ||
        lower.contains('contrast')) {
      return palette.info;
    }
    if (lower.contains('gold') ||
        lower.contains('amber') ||
        lower.contains('solar')) {
      return palette.gold;
    }
    return palette.rival;
  }

  static Color _resolveRivalColor(
    String userId,
    Map<String, RunnerPresenceEvent>? rivals, {
    AppPalette palette = AppPalette.dark,
  }) {
    if (rivals != null && rivals.containsKey(userId)) {
      return getFactionColor(rivals[userId]!.faction, palette: palette);
    }
    return palette.rival;
  }
}

class PolygonShell {
  final List<LatLng> outer;
  final List<List<LatLng>> holes = [];
  PolygonShell(this.outer);
}
