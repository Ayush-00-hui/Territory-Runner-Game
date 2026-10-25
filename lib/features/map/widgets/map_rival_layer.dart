import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/ws_events.dart';
import '../../../ui/ui.dart';

/// FlutterMap Layer rendering active rival runners and their dynamic trails.
class MapRivalLayer extends StatelessWidget {
  final Map<String, RunnerPresenceEvent> activeRivalRunners;
  final Map<String, List<LatLng>> rivalBreadcrumbs;
  final void Function(String rivalId)? onRivalTapped;

  const MapRivalLayer({
    super.key,
    required this.activeRivalRunners,
    required this.rivalBreadcrumbs,
    this.onRivalTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (activeRivalRunners.isEmpty && rivalBreadcrumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    final polylines = <Polyline>[];
    for (final entry in rivalBreadcrumbs.entries) {
      if (entry.value.length >= 2) {
        polylines.add(
          Polyline(
            points: entry.value,
            strokeWidth: 3.5,
            color: AppColors.rival.withValues(alpha: 0.65),
          ),
        );
      }
    }

    final markers = <Marker>[];
    for (final runner in activeRivalRunners.values) {
      markers.add(
        Marker(
          point: runner.position,
          width: 60,
          height: 60,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onRivalTapped?.call(runner.userId),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.rival, width: 1.0),
                  ),
                  child: Text(
                    runner.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.rival,
                    border: Border.all(color: AppColors.textPrimary, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.rival.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.flash_on_rounded, size: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}
