import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../ui/ui.dart';

/// Interactive skippable route replay card with territory art for SummarySheet.
class SummaryRouteReplay extends StatelessWidget {
  final List<LatLng> routePoints;
  final double effectiveArea;
  final int calories;
  final AnimationController replayController;

  const SummaryRouteReplay({
    super.key,
    required this.routePoints,
    required this.effectiveArea,
    required this.calories,
    required this.replayController,
  });

  String _formatArea(double area) {
    if (area >= 10000) {
      return '${(area / 1000000.0).toStringAsFixed(2)} km²';
    }
    return '${area.toStringAsFixed(0)} m²';
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = AppMotion.shouldReduceMotion(context);

    return Semantics(
      label: 'Territory map art showing your completed run loop. Tap to skip or replay.',
      button: true,
      child: GestureDetector(
        onTap: () {
          AppMotion.selectionTick();
          if (replayController.value < 1.0) {
            replayController.animateTo(1.0, duration: AppMotion.fast);
          } else {
            replayController.forward(from: 0.0);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: AppSpacing.br16,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: replayController,
                  builder: (context, _) {
                    final replayProgress = isReducedMotion ? 1.0 : replayController.value;
                    return CustomPaint(
                      painter: VictoryMapPainter(
                        points: routePoints,
                        routeProgress: replayProgress,
                      ),
                    );
                  },
                ),
              ),
              // Territory stats tag
              Positioned(
                bottom: 8,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withValues(alpha: 0.85),
                    borderRadius: AppSpacing.br8,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    'Claimed: ${_formatArea(effectiveArea)} • $calories kcal',
                    style: AppText.label.copyWith(
                      color: AppColors.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              // Skippable route replay indicator
              Positioned(
                top: 8,
                right: 10,
                child: AnimatedBuilder(
                  animation: replayController,
                  builder: (context, _) {
                    final isDone = replayController.value >= 1.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withValues(alpha: 0.8),
                        borderRadius: AppSpacing.br8,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDone ? Icons.replay_rounded : Icons.fast_forward_rounded,
                            size: 11,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isDone ? 'Replay' : 'Tap to skip',
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VictoryMapPainter extends CustomPainter {
  final List<LatLng> points;
  final double routeProgress;

  VictoryMapPainter({required this.points, this.routeProgress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawFallbackTerritory(canvas, size);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final double latSpan = math.max(maxLat - minLat, 0.0001);
    final double lngSpan = math.max(maxLng - minLng, 0.0001);

    const double padding = 12.0;
    final double usableW = size.width - 2 * padding;
    final double usableH = size.height - 2 * padding;

    final canvasPoints = <Offset>[];
    for (final p in points) {
      final double x = padding + ((p.longitude - minLng) / lngSpan) * usableW;
      final double y = padding + (1.0 - ((p.latitude - minLat) / latSpan)) * usableH;
      canvasPoints.add(Offset(x, y));
    }

    final clampedProgress = routeProgress.clamp(0.0, 1.0);
    final visibleCount = math.max(1, (canvasPoints.length * clampedProgress).ceil());

    if (clampedProgress >= 1.0 && canvasPoints.length >= 3) {
      final fillPath = Path();
      fillPath.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
      for (int i = 1; i < canvasPoints.length; i++) {
        fillPath.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
      }
      fillPath.close();

      final fillPaint = Paint()
        ..color = AppColors.territoryMineFill
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    final strokePath = Path();
    strokePath.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
    for (int i = 1; i < visibleCount; i++) {
      strokePath.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
    }
    if (clampedProgress >= 1.0) {
      strokePath.close();
    }

    final strokePaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(strokePath, strokePaint);

    if (clampedProgress < 1.0 && visibleCount > 0) {
      final tip = canvasPoints[visibleCount - 1];
      final dotPaint = Paint()..color = AppColors.accent;
      canvas.drawCircle(tip, 4.0, dotPaint);
    }
  }

  void _drawFallbackTerritory(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.32;

    final path = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final fillPaint = Paint()
      ..color = AppColors.territoryMineFill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant VictoryMapPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.routeProgress != routeProgress;
  }
}
