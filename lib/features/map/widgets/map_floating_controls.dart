import 'package:flutter/material.dart';

import 'map_controls_rail.dart';
import 'sos_shield_button.dart';

/// Ergonomic Floating Controls (Dynamically anchored above measured HUD height)
class MapFloatingControls extends StatelessWidget {
  final bool isLeftHanded;
  final double bottomOffset;
  final bool isCameraLocked;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenLayers;
  final VoidCallback onRecenter;
  final VoidCallback onTriggerSos;

  const MapFloatingControls({
    super.key,
    required this.isLeftHanded,
    required this.bottomOffset,
    required this.isCameraLocked,
    required this.onOpenTools,
    required this.onOpenLayers,
    required this.onRecenter,
    required this.onTriggerSos,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Thumb Controls Rail (Tools, Layers, Recenter)
        Positioned(
          left: isLeftHanded ? 16 : null,
          right: isLeftHanded ? null : 16,
          bottom: bottomOffset,
          child: MapControlsRail(
            isCameraLocked: isCameraLocked,
            onOpenTools: onOpenTools,
            onOpenLayers: onOpenLayers,
            onRecenter: onRecenter,
          ),
        ),

        // Isolated Safety SOS Shield Button (Mirrored away from thumb rail)
        Positioned(
          left: isLeftHanded ? null : 16,
          right: isLeftHanded ? 16 : null,
          bottom: bottomOffset,
          child: SosShieldButton(
            onTriggerSos: onTriggerSos,
          ),
        ),
      ],
    );
  }
}
