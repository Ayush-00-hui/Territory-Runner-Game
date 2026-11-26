import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/constants.dart';
import '../../../models/territory.dart';
import '../../../services/app_preferences.dart';
import '../../../services/exploration_service.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';
import '../controllers/map_run_controller.dart';
import 'map_layers.dart';

/// Fullscreen FlutterMap viewport rendering tiles, explored grid blocks, territories, paths, and markers.
class MapViewport extends StatefulWidget {
  final MapController mapController;
  final MapRunController controller;
  final ValueNotifier<List<Territory>> territoriesNotifier;

  const MapViewport({
    super.key,
    required this.mapController,
    required this.controller,
    required this.territoriesNotifier,
  });

  @override
  State<MapViewport> createState() => _MapViewportState();
}

class _MapViewportState extends State<MapViewport> {
  LatLngBounds? _visibleBounds;

  List<List<LatLng>> _exploredPolygons(LatLng fallbackCenter) {
    final bounds = _visibleBounds;
    final double minLat = bounds?.south ?? (fallbackCenter.latitude - 0.015);
    final double maxLat = bounds?.north ?? (fallbackCenter.latitude + 0.015);
    final double minLng = bounds?.west ?? (fallbackCenter.longitude - 0.015);
    final double maxLng = bounds?.east ?? (fallbackCenter.longitude + 0.015);

    return ExplorationService().getExploredCellPolygonsInBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final LatLng center =
        widget.controller.currentLocation ?? const LatLng(51.5074, -0.1278);

    return ListenableBuilder(
      listenable: Listenable.merge([
        AppPreferences().mapLayersNotifier,
        ExplorationService().revisionNotifier,
      ]),
      builder: (context, _) {
        final prefs = AppPreferences();
        final bool useLightTiles = isLight || prefs.highContrastMapLayer;
        final exploredPolygons = prefs.showExploredGridLayer
            ? _exploredPolygons(center)
            : const <List<LatLng>>[];

        return RepaintBoundary(
          child: FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.controller.currentLocation != null
                  ? 17.0
                  : 15.0,
              backgroundColor: palette.bgDeep,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                if (hasGesture && widget.controller.isCameraFollowLocked) {
                  widget.controller.setCameraFollow(false);
                }
                final nextBounds = camera.visibleBounds;
                if (_visibleBounds == null ||
                    (_visibleBounds!.center.latitude -
                                nextBounds.center.latitude)
                            .abs() >
                        0.002 ||
                    (_visibleBounds!.center.longitude -
                                nextBounds.center.longitude)
                            .abs() >
                        0.002) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _visibleBounds = nextBounds);
                    }
                  });
                }
              },
            ),
            children: [
              MapLayers.buildTileLayer(isLight: useLightTiles),
              if (prefs.showExploredGridLayer && exploredPolygons.isNotEmpty)
                MapLayers.buildExploredGridLayer(
                  exploredPolygons,
                  palette: palette,
                  highContrast: prefs.highContrastMapLayer,
                ),
              if (prefs.showTerritoriesLayer) ...[
                ValueListenableBuilder<List<Territory>>(
                  valueListenable: widget.territoriesNotifier,
                  builder: (context, territories, _) =>
                      MapLayers.buildPolygonLayer(
                        territories,
                        highlightedTerritoryId:
                            widget.controller.highlightedTerritoryId,
                        currentUserId: FirebaseService().currentUserId,
                        palette: palette,
                      ),
                ),
                ValueListenableBuilder<List<Territory>>(
                  valueListenable: widget.territoriesNotifier,
                  builder: (context, territories, _) =>
                      MapLayers.buildTerritoryBadgesLayer(
                        territories,
                        palette: palette,
                      ),
                ),
              ],
              ValueListenableBuilder<int>(
                valueListenable: widget.controller.runPathUpdateNotifier,
                builder: (context, _, child) => MapLayers.buildPolylineLayer(
                  isRunActive: widget.controller.isRunActive,
                  runCoordinates: widget.controller.runCoordinates,
                  currentEnclosurePath: widget.controller.runCoordinates,
                  suggestedRouteCoordinates:
                      widget.controller.activeSuggestedRoute?.polyline,
                  rivalBreadcrumbs: prefs.showRivalsLayer
                      ? widget.controller.rivalBreadcrumbs
                      : const {},
                  activeRivalRunners: prefs.showRivalsLayer
                      ? widget.controller.activeRivalRunners
                      : const {},
                  closureSnapPoint: widget.controller.nearestClosurePoint,
                  currentLocation: widget.controller.currentLocation,
                  palette: palette,
                ),
              ),
              ValueListenableBuilder<LatLng?>(
                valueListenable: widget.controller.liveLocationNotifier,
                builder: (context, loc, child) =>
                    ValueListenableBuilder<LatLng?>(
                      valueListenable: widget.controller.ghostLocationNotifier,
                      builder: (context, ghostLoc, _) =>
                          MapLayers.buildMarkerLayer(
                            currentLocation:
                                loc ?? widget.controller.currentLocation,
                            activeRivalRunners: prefs.showRivalsLayer
                                ? widget.controller.activeRivalRunners
                                : const {},
                            ghostLocation: ghostLoc,
                            closureSnapPoint: widget.controller.isRunActive
                                ? widget.controller.nearestClosurePoint
                                : null,
                            isBatterySaverActive:
                                widget.controller.isBatterySaverActive,
                            isReducedMotion:
                                MediaQuery.maybeOf(context)
                                    ?.disableAnimations ??
                                false,
                            palette: palette,
                          ),
                    ),
              ),
              if (AppConstants.tileAttribution.isNotEmpty)
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      AppConstants.tileAttribution,
                      prependCopyright: false,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
