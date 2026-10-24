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
        _RailCircleButton(
          icon: Icons.tune_rounded,
          tooltip: 'Run tools',
          semanticLabel: 'Open run tools sheet: goals, pacer and routes',
          onTap: () {
            AppMotion.selectionTick();
            onOpenTools();
          },
        ),
        const SizedBox(height: AppSpacing.s10),

        // 2. Map Layers Button
        _RailCircleButton(
          icon: Icons.layers_rounded,
          tooltip: 'Map layers',
          semanticLabel: 'Select map style and overlays',
          onTap: () {
            AppMotion.selectionTick();
            onOpenLayers();
          },
        ),
        const SizedBox(height: AppSpacing.s10),

        // 3. Recenter / Camera Lock Button
        _RailCircleButton(
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
          onTap: () {
            AppMotion.lightTick();
            onRecenter();
          },
        ),
      ],
    );
  }
}

class _RailCircleButton extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RailCircleButton({
    required this.icon,
    this.iconColor,
    required this.tooltip,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  State<_RailCircleButton> createState() => _RailCircleButtonState();
}

class _RailCircleButtonState extends State<_RailCircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isReduced = AppMotion.isReducedMotion(context);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: (_isPressed && !isReduced) ? 0.94 : 1.0,
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.easeOut,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _isPressed
                    ? AppColors.surface2
                    : AppColors.surfaceGlass,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isPressed
                      ? AppColors.accent
                      : AppColors.borderSubtle,
                  width: 1.0,
                ),
                boxShadow: AppElevation.floating,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: widget.iconColor ?? AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
