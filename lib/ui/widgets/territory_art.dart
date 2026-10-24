import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';
import '../../models/territory.dart';

/// Reusable, offline-ready vector territory art.
/// Renders flat polygon silhouettes of the user's real territories,
/// a faint cartographic contour/grid motif, and optional area count-up.
/// Works with zero network or tile dependencies.
class TerritoryArt extends StatefulWidget {
  final List<List<LatLng>> polygons;
  final List<List<LatLng>> rivalPolygons;
  final List<LatLng>? routePath;
  final double? totalAreaSqm;
  final String? subtitle;
  final bool showAreaCountUp;
  final bool isThumbnail;
  final double height;
  final double? width;
  final VoidCallback? onTap;

  const TerritoryArt({
    super.key,
    this.polygons = const [],
    this.rivalPolygons = const [],
    this.routePath,
    this.totalAreaSqm,
    this.subtitle,
    this.showAreaCountUp = false,
    this.isThumbnail = false,
    this.height = 200,
    this.width,
    this.onTap,
  });

  /// Factory helper from Territory models
  factory TerritoryArt.fromTerritories({
    Key? key,
    required List<Territory> territories,
    List<Territory> rivalTerritories = const [],
    List<LatLng>? routePath,
    double? totalAreaSqm,
    String? subtitle,
    bool showAreaCountUp = false,
    bool isThumbnail = false,
    double height = 200,
    double? width,
    VoidCallback? onTap,
  }) {
    final myPolys = territories.map((t) => t.polygon).toList();
    final rivalPolys = rivalTerritories.map((t) => t.polygon).toList();
    final calculatedArea = totalAreaSqm ??
        territories.fold<double>(0.0, (acc, t) => acc + t.areaSqMeters);

    return TerritoryArt(
      key: key,
      polygons: myPolys,
      rivalPolygons: rivalPolys,
      routePath: routePath,
      totalAreaSqm: calculatedArea,
      subtitle: subtitle,
      showAreaCountUp: showAreaCountUp,
      isThumbnail: isThumbnail,
      height: height,
      width: width,
      onTap: onTap,
    );
  }

  @override
  State<TerritoryArt> createState() => _TerritoryArtState();
}

class _TerritoryArtState extends State<TerritoryArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.countUp,
    );
    _countAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppMotion.easeOut,
    );
    if (widget.showAreaCountUp && (widget.totalAreaSqm ?? 0) > 0) {
      _animController.forward();
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant TerritoryArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totalAreaSqm != oldWidget.totalAreaSqm &&
        widget.showAreaCountUp &&
        (widget.totalAreaSqm ?? 0) > 0) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatArea(double sqm) {
    if (sqm >= 1000000) {
      return (sqm / 1000000.0).toStringAsFixed(2);
    }
    return sqm.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatUnit(double sqm) {
    return sqm >= 1000000 ? 'km²' : 'm²';
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.polygons.isEmpty &&
        widget.rivalPolygons.isEmpty &&
        (widget.routePath == null || widget.routePath!.isEmpty);

    final content = ClipRRect(
      borderRadius: widget.isThumbnail ? AppRadius.br8 : AppRadius.br16,
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: widget.isThumbnail ? AppColors.surface2 : AppColors.surface,
          borderRadius:
              widget.isThumbnail ? AppRadius.br8 : AppRadius.br16,
          border: Border.all(
            color: widget.isThumbnail
                ? AppColors.border
                : AppColors.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            // 1. Vector Map Canvas
            Positioned.fill(
              child: CustomPaint(
                painter: _TerritoryArtPainter(
                  polygons: widget.polygons,
                  rivalPolygons: widget.rivalPolygons,
                  routePath: widget.routePath,
                  isEmpty: isEmpty,
                  isThumbnail: widget.isThumbnail,
                ),
              ),
            ),

            // 2. Telemetry Readout Overlay (for Hero / Summary cards)
            if (!widget.isThumbnail && (widget.totalAreaSqm != null || widget.subtitle != null))
              Positioned(
                left: AppSpacing.s16,
                bottom: AppSpacing.s14,
                child: AnimatedBuilder(
                  animation: _countAnimation,
                  builder: (context, _) {
                    final targetArea = widget.totalAreaSqm ?? 0.0;
                    final displayArea = targetArea * _countAnimation.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.totalAreaSqm != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _formatArea(displayArea),
                                style: AppText.displaySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                _formatUnit(targetArea),
                                style: AppText.statUnit.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            widget.subtitle!,
                            style: AppText.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: () {
          AppMotion.lightTick();
          widget.onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}

class _TerritoryArtPainter extends CustomPainter {
  final List<List<LatLng>> polygons;
  final List<List<LatLng>> rivalPolygons;
  final List<LatLng>? routePath;
  final bool isEmpty;
  final bool isThumbnail;

  _TerritoryArtPainter({
    required this.polygons,
    required this.rivalPolygons,
    required this.routePath,
    required this.isEmpty,
    required this.isThumbnail,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle background cartographic contour/grid motif
    _drawGridMotif(canvas, size);

    if (isEmpty) {
      _drawEmptyStateGuide(canvas, size);
      return;
    }

    // 2. Compute bounding box across all active points
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    void extendBounds(LatLng pt) {
      minLat = math.min(minLat, pt.latitude);
      maxLat = math.max(maxLat, pt.latitude);
      minLng = math.min(minLng, pt.longitude);
      maxLng = math.max(maxLng, pt.longitude);
    }

    for (final poly in polygons) {
      for (final pt in poly) {
        extendBounds(pt);
      }
    }
    for (final poly in rivalPolygons) {
      for (final pt in poly) {
        extendBounds(pt);
      }
    }
    if (routePath != null) {
      for (final pt in routePath!) {
        extendBounds(pt);
      }
    }

    if (maxLat <= minLat || maxLng <= minLng) {
      _drawEmptyStateGuide(canvas, size);
      return;
    }

    // Canvas padding to prevent clipping
    final pad = isThumbnail ? 8.0 : 20.0;
    final drawWidth = size.width - pad * 2;
    final drawHeight = size.height - pad * 2;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;

    // Maintain aspect ratio with geographic cos(latitude) adjustment
    final midLat = (minLat + maxLat) / 2.0;
    final cosFactor = math.cos(midLat * math.pi / 180.0).abs();
    final effectiveLngSpan = lngSpan * cosFactor;

    final scaleX = drawWidth / (effectiveLngSpan > 0 ? effectiveLngSpan : 0.001);
    final scaleY = drawHeight / (latSpan > 0 ? latSpan : 0.001);
    final scale = math.min(scaleX, scaleY);

    Offset project(LatLng pt) {
      final x = pad + (drawWidth - effectiveLngSpan * scale) / 2 +
          (pt.longitude - minLng) * cosFactor * scale;
      final y = pad + (drawHeight - latSpan * scale) / 2 +
          (maxLat - pt.latitude) * scale;
      return Offset(x, y);
    }

    // 3. Paint Rival Territories (Dashed Steel Blue)
    final rivalFillPaint = Paint()
      ..color = AppColors.territoryRivalFill
      ..style = PaintingStyle.fill;
    final rivalBorderPaint = Paint()
      ..color = AppColors.territoryRivalBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final poly in rivalPolygons) {
      if (poly.length < 3) continue;
      final path = Path();
      final p0 = project(poly.first);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < poly.length; i++) {
        final pi = project(poly[i]);
        path.lineTo(pi.dx, pi.dy);
      }
      path.close();
      canvas.drawPath(path, rivalFillPaint);
      _drawDashedPath(canvas, path, rivalBorderPaint);
    }

    // 4. Paint Friendly Territories (Solid Moss)
    final mineFillPaint = Paint()
      ..color = AppColors.territoryMineFill
      ..style = PaintingStyle.fill;
    final mineBorderPaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final poly in polygons) {
      if (poly.length < 3) continue;
      final path = Path();
      final p0 = project(poly.first);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < poly.length; i++) {
        final pi = project(poly[i]);
        path.lineTo(pi.dx, pi.dy);
      }
      path.close();
      canvas.drawPath(path, mineFillPaint);
      canvas.drawPath(path, mineBorderPaint);
    }

    // 5. Paint Running Trail / Route Path (if present)
    if (routePath != null && routePath!.length >= 2) {
      final trailPaint = Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = isThumbnail ? 2.0 : 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final trailPath = Path();
      final startPt = project(routePath!.first);
      trailPath.moveTo(startPt.dx, startPt.dy);
      for (int i = 1; i < routePath!.length; i++) {
        final pt = project(routePath![i]);
        trailPath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(trailPath, trailPaint);

      // Start / Current location dot
      final headPt = project(routePath!.last);
      final dotPaint = Paint()..color = AppColors.accent;
      canvas.drawCircle(headPt, isThumbnail ? 2.5 : 4.0, dotPaint);
    }
  }

  void _drawGridMotif(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1.0;

    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawEmptyStateGuide(Canvas canvas, Size size) {
    // Subtle dotted loop contour indicating uncaptured land
    final guidePaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.28;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.4)));

    _drawDashedPath(canvas, path, guidePaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final extractLen = math.min(dashWidth, metric.length - distance);
        final extractPath = metric.extractPath(distance, distance + extractLen);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TerritoryArtPainter oldDelegate) {
    return oldDelegate.polygons != polygons ||
        oldDelegate.rivalPolygons != rivalPolygons ||
        oldDelegate.routePath != routePath ||
        oldDelegate.isEmpty != isEmpty;
  }
}
