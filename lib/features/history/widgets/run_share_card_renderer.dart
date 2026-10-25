import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../ui/ui.dart';
import 'run_share_card_painters.dart';

enum ShareCardTheme { athleticDark, cyberVanguard, stealth }

/// Public standalone 1080x1080 card renderer for social export and auto-save.
class RunShareCardRenderer {
  final double distanceKm;
  final int durationSeconds;
  final double areaSqMeters;
  final dynamic points;
  final String callsign;
  final DateTime capturedAt;
  final ShareCardTheme theme;

  const RunShareCardRenderer({
    required this.distanceKm,
    required this.durationSeconds,
    required this.areaSqMeters,
    required this.points,
    required this.callsign,
    required this.capturedAt,
    this.theme = ShareCardTheme.athleticDark,
  });

  List<LatLng> get _resolvedPoints {
    if (points is List<LatLng>) {
      return points as List<LatLng>;
    }
    return const [];
  }

  String _formatPace() {
    if (distanceKm <= 0) return "--'--\"";
    final double pace = (durationSeconds / 60.0) / distanceKm;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();
    return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"";
  }

  String _formatArea() {
    if (areaSqMeters >= 10000) {
      return '${(areaSqMeters / 1000000.0).toStringAsFixed(2)} KM²';
    }
    return '${areaSqMeters.toStringAsFixed(0)} M²';
  }

  String _formatDate() {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final dt = capturedAt;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute';
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final span = TextSpan(text: text, style: style);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, offset);
  }

  Future<Uint8List> render() async {
    const double targetSize = 1080.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, targetSize, targetSize),
    );

    Color cardBg;
    Color accentColor;
    bool hasGridOverlay;

    switch (theme) {
      case ShareCardTheme.athleticDark:
        cardBg = AppColors.bgDeep;
        accentColor = AppColors.accent;
        hasGridOverlay = false;
        break;
      case ShareCardTheme.cyberVanguard:
        cardBg = AppColors.bgElevated;
        accentColor = AppColors.rival;
        hasGridOverlay = true;
        break;
      case ShareCardTheme.stealth:
        cardBg = AppColors.surface;
        accentColor = AppColors.textPrimary;
        hasGridOverlay = false;
        break;
    }

    // 1. Background fill
    final bgPaint = Paint()..color = cardBg;
    canvas.drawRect(const Rect.fromLTWH(0, 0, targetSize, targetSize), bgPaint);

    // 2. Subtle cartographic grid if theme demands it
    if (hasGridOverlay) {
      final gridPainter = CartographicGridPainter(
        gridColor: accentColor.withValues(alpha: 0.08),
      );
      gridPainter.paint(canvas, const Size(targetSize, targetSize));
    }

    // 3. Draw outer card border
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 24, targetSize - 48, targetSize - 48),
        const Radius.circular(48),
      ),
      borderPaint,
    );

    // 4. Header Bar: Logo, App Title, and Run Pill
    _drawText(
      canvas,
      'TERRITORY RUNNER',
      const Offset(64, 64),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        fontFamily: 'Inter',
      ),
    );

    final pillRect = const Rect.fromLTWH(targetSize - 280, 56, 216, 44);
    final pillPaint = Paint()..color = accentColor.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(22)),
      pillPaint,
    );
    final pillBorder = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(22)),
      pillBorder,
    );

    _drawText(
      canvas,
      'Closed loop',
      const Offset(targetSize - 230, 68),
      TextStyle(
        color: accentColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    );

    // 5. Territory Map / Route Canvas (Center area: 900 x 520)
    canvas.save();
    canvas.translate(80, 150);
    final mapPainter = ShareCardMapPainter(
      points: _resolvedPoints,
      accentColor: accentColor,
    );
    mapPainter.paint(canvas, const Size(920, 500));
    canvas.restore();

    // 6. Callsign & Date Section
    _drawText(
      canvas,
      callsign.toUpperCase(),
      const Offset(64, 680),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        fontFamily: 'Inter',
      ),
    );

    _drawText(
      canvas,
      _formatDate(),
      const Offset(64, 735),
      TextStyle(
        color: AppColors.textMuted,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    );

    // 7. Stats Panel (Bottom Container: 952 x 180)
    final statsRect = const Rect.fromLTWH(64, 780, targetSize - 128, 170);
    final statsBg = Paint()..color = AppColors.bgDeep.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(statsRect, const Radius.circular(28)),
      statsBg,
    );
    final statsBorder = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(statsRect, const Radius.circular(28)),
      statsBorder,
    );

    // Three Stat Columns
    final double colWidth = (targetSize - 128) / 3.0;

    // Col 1: Distance
    _drawText(
      canvas,
      'DISTANCE',
      Offset(64 + colWidth * 0.5 - 45, 808),
      TextStyle(
        color: AppColors.textSecondary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    );
    _drawText(
      canvas,
      '${distanceKm.toStringAsFixed(2)} KM',
      Offset(64 + colWidth * 0.5 - 65, 846),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // Divider 1
    canvas.drawLine(
      Offset(64 + colWidth, 805),
      Offset(64 + colWidth, 925),
      Paint()
        ..color = AppColors.divider
        ..strokeWidth = 2.0,
    );

    // Col 2: Pace
    _drawText(
      canvas,
      'PACE',
      Offset(64 + colWidth * 1.5 - 28, 808),
      TextStyle(
        color: AppColors.textSecondary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    );
    _drawText(
      canvas,
      '${_formatPace()} /KM',
      Offset(64 + colWidth * 1.5 - 60, 846),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // Divider 2
    canvas.drawLine(
      Offset(64 + colWidth * 2, 805),
      Offset(64 + colWidth * 2, 925),
      Paint()
        ..color = AppColors.divider
        ..strokeWidth = 2.0,
    );

    // Col 3: Claimed Area
    _drawText(
      canvas,
      'CLAIMED',
      Offset(64 + colWidth * 2.5 - 42, 808),
      TextStyle(
        color: AppColors.textSecondary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    );
    _drawText(
      canvas,
      _formatArea(),
      Offset(64 + colWidth * 2.5 - 65, 846),
      TextStyle(
        color: accentColor,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // 8. Watermark Footer
    _drawText(
      canvas,
      'Server-verified territory • GPS spatial parity',
      const Offset(240, 990),
      TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.6),
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        fontFamily: 'Inter',
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, 1080);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to encode image to PNG byte data');
    }
    return byteData.buffer.asUint8List();
  }
}
