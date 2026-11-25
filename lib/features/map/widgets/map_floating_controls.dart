import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
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
          child: SosShieldButton(onTriggerSos: onTriggerSos),
        ),

        // Prominent Recenter Pill Button when camera is panned away
        if (!isCameraLocked)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomOffset,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRecenter,
                  borderRadius: BorderRadius.circular(24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: AppColors.accent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recenter',
                          style: AppText.bodyBold.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
