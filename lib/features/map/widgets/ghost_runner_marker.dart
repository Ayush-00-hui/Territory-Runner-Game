import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/theme/app_palette.dart';

/// Neutral athletic marker with a dashed ring representing the historical ghost runner.
/// Zero glow, tokens only, respects battery saver and reduced motion.
class GhostRunnerMarkerWidget extends StatelessWidget {
  final bool isBatterySaverActive;
  final bool isReducedMotion;

  const GhostRunnerMarkerWidget({
    super.key,
    this.isBatterySaverActive = false,
    this.isReducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Ghost runner position',
      child: RepaintBoundary(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CustomPaint(
            painter: _GhostMarkerPainter(
              ringColor: palette.textMuted.withValues(alpha: 0.85),
              centerColor: palette.surface2,
              borderColor: palette.textSecondary,
              pipColor: palette.textPrimary,
              isBatterySaver: isBatterySaverActive,
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostMarkerPainter extends CustomPainter {
  final Color ringColor;
  final Color centerColor;
  final Color borderColor;
  final Color pipColor;
  final bool isBatterySaver;

  _GhostMarkerPainter({
    required this.ringColor,
    required this.centerColor,
    required this.borderColor,
    required this.pipColor,
    required this.isBatterySaver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 1.5;
    const innerRadius = 6.0;

    // 1. Dashed circular ring (neutral, hairline, NO glow)
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isBatterySaver) {
      // Solid simplified ring under battery saver
      canvas.drawCircle(center, outerRadius, ringPaint);
    } else {
      // Crisp 16-segment dashed ring
      const numDashes = 16;
      const anglePerDash = (2 * math.pi) / numDashes;
      const dashAngle = anglePerDash * 0.55;

      for (int i = 0; i < numDashes; i++) {
        final startAngle = i * anglePerDash;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerRadius),
          startAngle,
          dashAngle,
          false,
          ringPaint,
        );
      }
    }

    // 2. Neutral center dot with crisp border
    final fillPaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, innerRadius, fillPaint);
    canvas.drawCircle(center, innerRadius, strokePaint);

    // 3. Crisp inner pip
    final pipPaint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0, pipPaint);
  }

  @override
  bool shouldRepaint(covariant _GhostMarkerPainter oldDelegate) {
    return oldDelegate.ringColor != ringColor ||
        oldDelegate.centerColor != centerColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.pipColor != pipColor ||
        oldDelegate.isBatterySaver != isBatterySaver;
  }
}
