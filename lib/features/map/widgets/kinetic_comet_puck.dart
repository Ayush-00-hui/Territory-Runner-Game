import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Kinetic Comet GPS Puck with velocity-reactive core and directional heading arrow.
class KineticCometPuck extends StatefulWidget {
  final double currentSpeedKmh;
  final double? headingDegrees;
  final bool isBatterySaverActive;
  final bool isReducedMotion;

  const KineticCometPuck({
    super.key,
    required this.currentSpeedKmh,
    this.headingDegrees,
    this.isBatterySaverActive = false,
    this.isReducedMotion = false,
  });

  @override
  State<KineticCometPuck> createState() => _KineticCometPuckState();
}

class _KineticCometPuckState extends State<KineticCometPuck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!widget.isBatterySaverActive && !widget.isReducedMotion) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(KineticCometPuck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBatterySaverActive || widget.isReducedMotion) {
      if (_pulseController.isAnimating) _pulseController.stop();
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color based on velocity
    final Color paceColor;
    if (widget.currentSpeedKmh > 14.0) {
      paceColor = AppColors.accent; // High tempo sprint
    } else if (widget.currentSpeedKmh > 6.0) {
      paceColor = AppColors.info; // Aerobic base
    } else {
      paceColor = AppColors.warning; // Recovery / walk
    }

    final heading = widget.headingDegrees ?? 0.0;
    final headingRad = heading * (math.pi / 180.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = (widget.isBatterySaverActive || widget.isReducedMotion)
            ? 1.0
            : 1.0 + (_pulseController.value * 0.18);
        final haloAlpha =
            (widget.isBatterySaverActive || widget.isReducedMotion)
            ? 0.15
            : 0.12 + (_pulseController.value * 0.15);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Halo Bloom
            Container(
              width: 38.0 * scale,
              height: 38.0 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paceColor.withValues(alpha: haloAlpha),
              ),
            ),

            // Middle Translucent Ring
            Container(
              width: 24.0,
              height: 24.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: paceColor.withValues(alpha: 0.8),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: paceColor.withValues(alpha: 0.25),
                    blurRadius: 8.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
            ),

            // Inner Core Puck
            Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paceColor,
              ),
            ),

            // Directional Heading Indicator Notch
            if (widget.headingDegrees != null && widget.currentSpeedKmh > 1.5)
              Transform.rotate(
                angle: headingRad,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 3.0,
                    height: 5.0,
                    margin: const EdgeInsets.only(top: 2.0),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
