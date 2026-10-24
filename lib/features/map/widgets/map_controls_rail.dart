import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Ergonomic 48 dp Thumb-zone control rail for the map screen.
/// Hosts the primary navigation actions:
/// 1. [Tools] (Secondary sheet for Route planner, Goals, Pacer, Battery saver, Offline maps)
/// 2. [Layers] (Map style, overlays, and satellite view)
/// 3. [Recenter] (Auto-follow lock & GPS camera centering)
class MapControlsRail extends StatelessWidget {
  final VoidCallback onOpenTools;
  final VoidCallback onOpenLayers;
  final VoidCallback onRecenter;
  final bool isCameraLocked;

  const MapControlsRail({
    super.key,
    required this.onOpenTools,
    required this.onOpenLayers,
    required this.onRecenter,
    this.isCameraLocked = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Tools Button
        AppIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Run tools',
          semanticLabel: 'Open run tools sheet: goals, pacer and routes',
          onTap: onOpenTools,
        ),
        const SizedBox(height: AppSpacing.s10),

        // 2. Map Layers Button
        AppIconButton(
          icon: Icons.layers_rounded,
          tooltip: 'Map layers',
          semanticLabel: 'Select map style and overlays',
          onTap: onOpenLayers,
        ),
        const SizedBox(height: AppSpacing.s10),

        // 3. Recenter / Camera Lock Button
        AppIconButton(
          icon: isCameraLocked
              ? Icons.my_location_rounded
              : Icons.pan_tool_rounded,
          iconColor: isCameraLocked
              ? AppColors.accent
              : AppColors.textSecondary,
          tooltip: isCameraLocked ? 'Recenter map' : 'Lock camera follow',
          semanticLabel: isCameraLocked
              ? 'Recenter map on your position'
              : 'Lock camera to follow your movement',
          onTap: onRecenter,
        ),
      ],
    );
  }
}
