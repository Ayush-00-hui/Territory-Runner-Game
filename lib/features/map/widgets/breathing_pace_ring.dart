import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Breathing Pace Ring widget wrapping athlete velocity with intuitive peripheral visual guidance.
class BreathingPaceRing extends StatefulWidget {
  final double currentSpeedKmh;
  final double targetPaceMinPerKm;
  final Widget child;

  const BreathingPaceRing({
    super.key,
    required this.currentSpeedKmh,
    this.targetPaceMinPerKm = 5.5,
    required this.child,
  });

  @override
  State<BreathingPaceRing> createState() => _BreathingPaceRingState();
}

class _BreathingPaceRingState extends State<BreathingPaceRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = widget.currentSpeedKmh;

    final Color ringColor;
    final int cycleDurationMs;

    if (speed < 4.0) {
      // Stopped or walking
      ringColor = AppColors.textMuted;
      cycleDurationMs = 3000;
    } else if (speed > 13.5) {
      // Sprint
      ringColor = AppColors.accent;
      cycleDurationMs = 1000;
    } else {
      // Aerobic tempo target
      ringColor = AppColors.accent;
      cycleDurationMs = 2000;
    }

    if (_breatheController.duration?.inMilliseconds != cycleDurationMs) {
      _breatheController.duration = Duration(milliseconds: cycleDurationMs);
    }

    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, _) {
        final breath = _breatheController.value;
        final spread = 2.0 + (breath * 5.0);
        final alpha = 0.15 + (breath * 0.20);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: alpha),
                blurRadius: 14.0,
                spreadRadius: spread,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
