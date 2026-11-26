import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Signature Territory Runner vector crest: a faceted closed-loop polygon shield
/// enclosing a forward-striding route chevron and apex GPS beacon node.
class TerritoryBrandMark extends StatelessWidget {
  final double size;
  final bool showContainer;
  final double loopProgress;

  const TerritoryBrandMark({
    super.key,
    this.size = 48.0,
    this.showContainer = true,
    this.loopProgress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final child = CustomPaint(
      size: Size.square(size),
      painter: _TerritoryBrandMarkPainter(loopProgress: loopProgress),
    );
    if (!showContainer) return child;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.72),
          painter: _TerritoryBrandMarkPainter(loopProgress: loopProgress),
        ),
      ),
    );
  }
}

class _TerritoryBrandMarkPainter extends CustomPainter {
  final double loopProgress;

  _TerritoryBrandMarkPainter({required this.loopProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.44;
    final t = loopProgress.clamp(0.0, 1.0);

    Offset pt(double nx, double ny) => Offset(c.dx + nx * r, c.dy + ny * r);

    // 1. Concentric topographic radar arcs
    final arcPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.22 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width * 0.025)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 1.08),
      -math.pi * 0.85,
      math.pi * 0.65,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 1.08),
      math.pi * 0.15,
      math.pi * 0.65,
      false,
      arcPaint,
    );

    // 2. Faceted Closed-Loop Shield Polygon
    final poly = [
      pt(0.0, -0.84),
      pt(0.74, -0.46),
      pt(0.66, 0.36),
      pt(0.0, 0.86),
      pt(-0.66, 0.36),
      pt(-0.74, -0.46),
    ];

    final fullPath = Path()..moveTo(poly.first.dx, poly.first.dy);
    for (int i = 1; i < poly.length; i++) {
      fullPath.lineTo(poly[i].dx, poly[i].dy);
    }
    fullPath.close();

    if (t > 0.25) {
      final fillAlpha = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      canvas.drawPath(
        fullPath,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.16 * fillAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    final borderPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * 0.075)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (t >= 0.999) {
      canvas.drawPath(fullPath, borderPaint);
    } else if (t > 0.0) {
      for (final metric in fullPath.computeMetrics()) {
        final partial = metric.extractPath(0, metric.length * t);
        canvas.drawPath(partial, borderPaint);
      }
    }

    // 3. Dynamic forward-striding trail inside shield
    final strideT = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    if (strideT > 0.0) {
      final stridePath = Path()
        ..moveTo(pt(-0.36, 0.24).dx, pt(-0.36, 0.24).dy)
        ..lineTo(pt(-0.08, -0.04).dx, pt(-0.08, -0.04).dy)
        ..lineTo(pt(0.06, 0.16).dx, pt(0.06, 0.16).dy)
        ..lineTo(pt(0.38, -0.28).dx, pt(0.38, -0.28).dy);

      final stridePaint = Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, size.width * 0.08)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (final metric in stridePath.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * strideT),
          stridePaint,
        );
      }
    }

    // 4. Locked apex GPS beacon node
    final apex = pt(0.0, -0.84);
    final nodeRadius = math.max(2.2, size.width * 0.095);
    canvas.drawCircle(
      apex,
      nodeRadius * 1.15,
      Paint()..color = AppColors.bgDeep,
    );
    canvas.drawCircle(
      apex,
      nodeRadius * 0.95,
      Paint()..color = AppColors.accent,
    );
    canvas.drawCircle(
      apex,
      nodeRadius * 0.55,
      Paint()..color = AppColors.textPrimary,
    );
    canvas.drawCircle(
      apex,
      nodeRadius * 0.25,
      Paint()..color = AppColors.bgDeep,
    );
  }

  @override
  bool shouldRepaint(covariant _TerritoryBrandMarkPainter oldDelegate) =>
      oldDelegate.loopProgress != loopProgress;
}
