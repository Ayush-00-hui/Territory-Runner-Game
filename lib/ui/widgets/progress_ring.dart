import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../motion/motion.dart';

/// Performance-first Circular Progress Ring with animated sweep and RepaintBoundary.
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64.0,
    this.strokeWidth = 6.0,
    this.progressColor = AppColors.accent,
    this.trackColor = AppColors.surface2,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                duration: AppMotion.duration(context, AppMotion.countUp),
                curve: AppMotion.easeOut,
                builder: (context, value, _) {
                  return CustomPaint(
                    size: Size(size, size),
                    painter: _ProgressRingPainter(
                      progress: value,
                      strokeWidth: strokeWidth,
                      progressColor: progressColor,
                      trackColor: trackColor,
                    ),
                  );
                },
              ),
            ),
            ?center,
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Foreground Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
