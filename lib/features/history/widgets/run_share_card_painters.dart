import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../ui/ui.dart';

class ShareCardMapPainter extends CustomPainter {
  final List<LatLng> points;
  final Color accentColor;

  ShareCardMapPainter({required this.points, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawDemoLoop(canvas, size);
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

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final double x = padding + ((p.longitude - minLng) / lngSpan) * usableW;
      final double y =
          padding + (1.0 - ((p.latitude - minLat) / latSpan)) * usableH;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill territory
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Sharp solid stroke, NO glow
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Origin node with clean dark border, NO glow
    if (points.isNotEmpty) {
      final p0 = points.first;
      final double x0 = padding + ((p0.longitude - minLng) / lngSpan) * usableW;
      final double y0 =
          padding + (1.0 - ((p0.latitude - minLat) / latSpan)) * usableH;

      canvas.drawCircle(Offset(x0, y0), 4.5, Paint()..color = AppColors.bgDeep);
      canvas.drawCircle(Offset(x0, y0), 3.0, Paint()..color = accentColor);
    }
  }

  void _drawDemoLoop(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.38;

    final path = Path();
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
    canvas.drawCircle(
      Offset(cx + r, cy),
      4,
      Paint()..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(covariant ShareCardMapPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accentColor != accentColor;
  }
}

class CartographicGridPainter extends CustomPainter {
  final Color gridColor;

  CartographicGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    const double step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CartographicGridPainter oldDelegate) => false;
}
