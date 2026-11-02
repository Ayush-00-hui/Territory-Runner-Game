import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/constants.dart';
import '../../../models/territory.dart';
import '../../../ui/ui.dart';
import '../controllers/map_run_controller.dart';
import 'map_layers.dart';

/// Fullscreen FlutterMap viewport rendering tiles, territories, paths, and markers.
class MapViewport extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final LatLng center =
        controller.currentLocation ?? const LatLng(51.5074, -0.1278);

    return RepaintBoundary(
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: controller.currentLocation != null ? 17.0 : 15.0,
          backgroundColor: AppColors.bgDeep,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          MapLayers.buildTileLayer(),
          ValueListenableBuilder<List<Territory>>(
            valueListenable: territoriesNotifier,
            builder: (context, territories, _) => MapLayers.buildPolygonLayer(
              territories,
              highlightedTerritoryId: controller.highlightedTerritoryId,
            ),
          ),
          ValueListenableBuilder<List<Territory>>(
            valueListenable: territoriesNotifier,
            builder: (context, territories, _) =>
                MapLayers.buildTerritoryBadgesLayer(territories),
          ),
          ValueListenableBuilder<int>(
            valueListenable: controller.runPathUpdateNotifier,
            builder: (context, _, child) => MapLayers.buildPolylineLayer(
              isRunActive: controller.isRunActive,
              runCoordinates: controller.runCoordinates,
              currentEnclosurePath: controller.runCoordinates,
              suggestedRouteCoordinates:
                  controller.activeSuggestedRoute?.polyline,
              rivalBreadcrumbs: controller.rivalBreadcrumbs,
              activeRivalRunners: controller.activeRivalRunners,
            ),
          ),
          ValueListenableBuilder<LatLng?>(
            valueListenable: controller.liveLocationNotifier,
            builder: (context, loc, child) => MapLayers.buildMarkerLayer(
              currentLocation: loc ?? controller.currentLocation,
              activeRivalRunners: controller.activeRivalRunners,
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
  }
}
