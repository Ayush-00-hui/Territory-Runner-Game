import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../services/app_preferences.dart';
import '../../../services/elevation_splits_service.dart';
import '../../../ui/ui.dart';

/// Interactive elevation profile chart drawn with a high-performance CustomPainter.
///
/// Features:
/// - Flat area fill to baseline, hairline axes, zero glow.
/// - Scrubbing along the profile to inspect altitude/grade and synchronize route replay marker.
/// - Min/max elevation and cumulative gain/loss chips.
/// - Graceful empty state when altitude data is missing or low quality.
class ElevationProfileChart extends StatefulWidget {
  final ElevationProfileData profileData;
  final ValueChanged<ElevationPoint?>? onScrub;
  final double height;

  const ElevationProfileChart({
    super.key,
    required this.profileData,
    this.onScrub,
    this.height = 140.0,
  });

  @override
  State<ElevationProfileChart> createState() => _ElevationProfileChartState();
}

class _ElevationProfileChartState extends State<ElevationProfileChart> {
  ElevationPoint? _activeScrubPoint;

  void _handleScrubUpdate(Offset localPosition, double width) {
    if (widget.profileData.points.isEmpty || width <= 0) return;

    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    final points = widget.profileData.points;
    final targetIndex = ((points.length - 1) * ratio).round().clamp(
      0,
      points.length - 1,
    );
    final point = points[targetIndex];

    setState(() {
      _activeScrubPoint = point;
    });

    widget.onScrub?.call(point);
  }

  void _handleScrubEnd() {
    // Keep last scrub position or let user tap to dismiss
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profileData.hasValidAltitude ||
        widget.profileData.points.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.br16,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.terrain_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                widget.profileData.unavailableReason ?? 'Elevation chart unavailable: this run does not contain altitude data.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final data = widget.profileData;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Stats Row: Gain, Loss, Min, Max
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.formattedGain,
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  const Icon(
                    Icons.trending_down_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.formattedLoss,
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Text(
                'Min ${data.formattedMinAltitude} • Max ${data.formattedMaxAltitude}',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s10),

          // 2. Active Scrub Banner (if scrubbing)
          if (_activeScrubPoint != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgDeep,
                borderRadius: AppSpacing.br8,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDistance(
                      _activeScrubPoint!.distanceMeters,
                      data.unit,
                    ),
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatAltitude(
                      _activeScrubPoint!.altitudeMeters,
                      data.unit,
                    ),
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatGrade(_activeScrubPoint!.grade),
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],

          // 3. CustomPainter Elevation Chart
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) =>
                    _handleScrubUpdate(details.localPosition, w),
                onHorizontalDragUpdate: (details) =>
                    _handleScrubUpdate(details.localPosition, w),
                onHorizontalDragEnd: (_) => _handleScrubEnd(),
                onTapDown: (details) =>
                    _handleScrubUpdate(details.localPosition, w),
                child: Semantics(
                  label: 'Elevation profile chart. Drag across to scrub along the route.',
                  child: SizedBox(
                    width: w,
                    height: widget.height,
                    child: CustomPaint(
                      painter: _ElevationChartPainter(
                        data: data,
                        scrubPoint: _activeScrubPoint,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDistance(double distanceM, DistanceUnit unit) {
    if (unit == DistanceUnit.imperial) {
      final miles = distanceM / 1609.344;
      return '${miles.toStringAsFixed(2)} mi';
    }
    final km = distanceM / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  String _formatAltitude(double altM, DistanceUnit unit) {
    if (unit == DistanceUnit.imperial) {
      final feet = (altM * 3.28084).round();
      return '$feet ft';
    }
    return '${altM.round()} m';
  }

  String _formatGrade(double grade) {
    final pct = grade * 100.0;
    final sign = pct > 0 ? '+' : (pct < 0 ? '' : '');
    return '$sign${pct.toStringAsFixed(1)}% grade';
  }
}

class _ElevationChartPainter extends CustomPainter {
  final ElevationProfileData data;
  final ElevationPoint? scrubPoint;

  _ElevationChartPainter({required this.data, this.scrubPoint});

  @override
  void paint(Canvas canvas, Size size) {
    final points = data.points;
    if (points.isEmpty) return;

    final w = size.width;
    final h = size.height;

    const topPadding = 12.0;
    const bottomPadding = 18.0;
    final usableH = math.max(10.0, h - topPadding - bottomPadding);

    double minAlt = data.minAltitudeMeters;
    double maxAlt = data.maxAltitudeMeters;
    if ((maxAlt - minAlt).abs() < 1.0) {
      minAlt -= 2.0;
      maxAlt += 2.0;
    }
    final altSpan = maxAlt - minAlt;

    // 1. Draw Hairline Grid Lines & Labels
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Top hairline (max)
    canvas.drawLine(Offset(0, topPadding), Offset(w, topPadding), gridPaint);
    // Mid hairline
    final midY = topPadding + (usableH / 2.0);
    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    // Baseline hairline
    final baseY = topPadding + usableH;
    canvas.drawLine(Offset(0, baseY), Offset(w, baseY), gridPaint);

    // 2. Draw Distance / Altitude Hairline Axis Text
    _drawText(
      canvas,
      data.formattedMaxAltitude,
      Offset(2, topPadding - 10),
      AppColors.textMuted,
    );
    _drawText(
      canvas,
      data.formattedMinAltitude,
      Offset(2, baseY + 3),
      AppColors.textMuted,
    );

    final totalDist = points.last.distanceMeters;
    final distLabel = data.unit == DistanceUnit.imperial
        ? '${(totalDist / 1609.344).toStringAsFixed(1)} mi'
        : '${(totalDist / 1000.0).toStringAsFixed(1)} km';
    _drawText(canvas, '0', Offset(w * 0.02, baseY + 3), AppColors.textMuted);
    _drawText(
      canvas,
      distLabel,
      Offset(w - 38, baseY + 3),
      AppColors.textMuted,
    );

    // 3. Build Elevation Curve & Flat Fill Path
    final path = ui.Path();
    final fillPath = ui.Path();

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = totalDist > 0
          ? (p.distanceMeters / totalDist) * w
          : (i / (points.length - 1)) * w;
      final yNorm = (p.altitudeMeters - minAlt) / altSpan;
      final y = baseY - (yNorm * usableH);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, baseY);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, baseY);
    fillPath.close();

    // Draw Flat Fill (NO glow)
    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw Curve Stroke (Hairline/1.5dp, zero glow)
    final strokePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // 4. Draw Scrub Indicator (if active)
    if (scrubPoint != null) {
      final scrubX = totalDist > 0
          ? (scrubPoint!.distanceMeters / totalDist) * w
          : 0.0;
      final scrubYNorm = (scrubPoint!.altitudeMeters - minAlt) / altSpan;
      final scrubY = baseY - (scrubYNorm * usableH);

      final scrubLinePaint = Paint()
        ..color = AppColors.textSecondary
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(scrubX, topPadding),
        Offset(scrubX, baseY),
        scrubLinePaint,
      );

      final dotPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      final dotRingPaint = Paint()
        ..color = AppColors.bgDeep
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(scrubX, scrubY), 4.5, dotPaint);
      canvas.drawCircle(Offset(scrubX, scrubY), 4.5, dotRingPaint);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 9.0,
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ElevationChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.scrubPoint != scrubPoint;
  }
}
