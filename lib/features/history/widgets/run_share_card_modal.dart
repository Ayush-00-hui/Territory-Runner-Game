import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/territory.dart';
import '../../../services/export_service.dart';
import '../../../ui/ui.dart';

enum ShareCardTheme {
  athleticDark,
  cyberVanguard,
  stealth,
}

/// Strava / Nike Run Club style story/square card generator for social sharing.
class RunShareCardModal extends StatefulWidget {
  final double distanceKm;
  final int durationSeconds;
  final double areaSqMeters;
  final List<LatLng> points;
  final String callsign;
  final String faction;
  final DateTime capturedAt;

  const RunShareCardModal({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.areaSqMeters,
    required this.points,
    required this.callsign,
    required this.faction,
    required this.capturedAt,
  });

  static Future<void> show({
    required BuildContext context,
    required double distanceKm,
    required int durationSeconds,
    required double areaSqMeters,
    required List<LatLng> points,
    required String callsign,
    required String faction,
    DateTime? capturedAt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => RunShareCardModal(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        areaSqMeters: areaSqMeters,
        points: points,
        callsign: callsign,
        faction: faction,
        capturedAt: capturedAt ?? DateTime.now(),
      ),
    );
  }

  @override
  State<RunShareCardModal> createState() => _RunShareCardModalState();
}

class _RunShareCardModalState extends State<RunShareCardModal> {
  final GlobalKey _cardKey = GlobalKey();
  ShareCardTheme _selectedTheme = ShareCardTheme.athleticDark;
  bool _isExporting = false;
  String? _exportSuccessMessage;
  String? _exportErrorMessage;

  String _formatPace() {
    if (widget.distanceKm <= 0) return "--'--\"";
    final double pace = (widget.durationSeconds / 60.0) / widget.distanceKm;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();
    return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"";
  }

  String _formatArea() {
    if (widget.areaSqMeters >= 10000) {
      return '${(widget.areaSqMeters / 1000000.0).toStringAsFixed(2)} KM²';
    }
    return '${widget.areaSqMeters.toStringAsFixed(0)} M²';
  }

  String _formatDate() {
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dt = widget.capturedAt;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute';
  }

  /// Renders a true 1080x1080 PNG image of the share card
  Future<Uint8List> _renderTrue1080pCard() async {
    const double targetSize = 1080.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, targetSize, targetSize));

    Color cardBg;
    Color accentColor;
    bool hasGridOverlay;

    switch (_selectedTheme) {
      case ShareCardTheme.athleticDark:
        cardBg = AppColors.bgDeep;
        accentColor = AppColors.accent;
        hasGridOverlay = false;
        break;
      case ShareCardTheme.cyberVanguard:
        cardBg = const Color(0xFF080D14);
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

    // 2. Subtle Cyber Grid if theme demands it
    if (hasGridOverlay) {
      final gridPainter = _CyberGridPainter(gridColor: accentColor.withValues(alpha: 0.08));
      gridPainter.paint(canvas, const Size(targetSize, targetSize));
    }

    // 3. Draw outer card border
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 24, targetSize - 48, targetSize - 48), const Radius.circular(48)),
      borderPaint,
    );

    // 4. Header Bar: Logo, App Title, and Sovereign Run Badge
    _drawText(
      canvas,
      'TERRITORY RUNNER',
      const Offset(64, 64),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        fontFamily: 'Inter',
      ),
    );

    // Sovereign Run Pill
    final pillRect = const Rect.fromLTWH(targetSize - 280, 56, 216, 44);
    final pillPaint = Paint()..color = accentColor.withValues(alpha: 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(22)), pillPaint);
    final pillBorder = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(22)), pillBorder);

    _drawText(
      canvas,
      'SOVEREIGN RUN',
      const Offset(targetSize - 250, 68),
      TextStyle(
        color: accentColor,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        fontFamily: 'Inter',
      ),
    );

    // 5. Territory Map / Route Canvas (Center area: 900 x 520)
    canvas.save();
    canvas.translate(80, 150);
    final mapPainter = _ShareCardMapPainter(
      points: widget.points,
      accentColor: accentColor,
    );
    mapPainter.paint(canvas, const Size(920, 500));
    canvas.restore();

    // 6. Callsign & Date Section
    _drawText(
      canvas,
      widget.callsign.toUpperCase(),
      const Offset(64, 680),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 44,
        fontWeight: FontWeight.w900,
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
    canvas.drawRRect(RRect.fromRectAndRadius(statsRect, const Radius.circular(28)), statsBg);
    final statsBorder = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(statsRect, const Radius.circular(28)), statsBorder);

    // Three Stat Columns
    final double colWidth = (targetSize - 128) / 3.0;

    // Col 1: Distance
    _drawText(
      canvas,
      'DISTANCE',
      Offset(64 + colWidth * 0.5 - 45, 808),
      TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
    );
    _drawText(
      canvas,
      '${widget.distanceKm.toStringAsFixed(2)} KM',
      Offset(64 + colWidth * 0.5 - 65, 846),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        fontFamily: 'Inter',
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // Divider 1
    canvas.drawLine(Offset(64 + colWidth, 805), Offset(64 + colWidth, 925), Paint()..color = AppColors.divider..strokeWidth = 2.0);

    // Col 2: Pace
    _drawText(
      canvas,
      'PACE',
      Offset(64 + colWidth * 1.5 - 28, 808),
      TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
    );
    _drawText(
      canvas,
      '${_formatPace()} /KM',
      Offset(64 + colWidth * 1.5 - 60, 846),
      TextStyle(
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        fontFamily: 'Inter',
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // Divider 2
    canvas.drawLine(Offset(64 + colWidth * 2, 805), Offset(64 + colWidth * 2, 925), Paint()..color = AppColors.divider..strokeWidth = 2.0);

    // Col 3: Claimed Area
    _drawText(
      canvas,
      'CLAIMED',
      Offset(64 + colWidth * 2.5 - 42, 808),
      TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
    );
    _drawText(
      canvas,
      _formatArea(),
      Offset(64 + colWidth * 2.5 - 65, 846),
      TextStyle(
        color: accentColor,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        fontFamily: 'Inter',
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    // 8. Watermark Footer
    _drawText(
      canvas,
      'SERVER-AUTHORITATIVE TERRITORY CONQUEST • POSTGIS SPATIAL PARITY',
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

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final span = TextSpan(text: text, style: style);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, offset);
  }

  /// Exports the card: renders true 1080x1080 PNG, writes to file, and opens system share sheet
  Future<void> _exportCard() async {
    setState(() {
      _isExporting = true;
      _exportSuccessMessage = null;
      _exportErrorMessage = null;
    });

    AppMotion.heavyBurst();

    try {
      final Uint8List pngBytes = await _renderTrue1080pCard();
      final tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/territory_conquest_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      // Verify file was genuinely created on disk
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('File was not written to storage');
      }

      // Open system share sheet
      final xFile = XFile(filePath, mimeType: 'image/png');
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Claimed ${widget.callsign}\'s territory on Territory Runner! #TerritoryRunner',
        ),
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportSuccessMessage = 'Share Card ready! 1080x1080 PNG rendered (${(pngBytes.lengthInBytes / 1024).toStringAsFixed(0)} KB)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportErrorMessage = 'Failed to generate share card: $e';
        });
      }
    }
  }

  /// Saves the true 1080x1080 PNG to the device documents storage
  Future<void> _saveCardToDevice() async {
    setState(() {
      _isExporting = true;
      _exportSuccessMessage = null;
      _exportErrorMessage = null;
    });

    AppMotion.mediumTick();

    try {
      final Uint8List pngBytes = await _renderTrue1080pCard();
      final docDir = await getApplicationDocumentsDirectory();
      final String filePath = '${docDir.path}/territory_card_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('File write verification failed');
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportSuccessMessage = 'Saved 1080x1080 PNG to storage: ${file.path.split(Platform.pathSeparator).last} (${(pngBytes.lengthInBytes / 1024).toStringAsFixed(0)} KB)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportErrorMessage = 'Failed to save card: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        MediaQuery.paddingOf(context).bottom + AppSpacing.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHARE CONQUEST',
                    style: AppText.headingSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Export Strava-ready 1080x1080 victory artwork',
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),

          // Theme selector pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildThemePill(ShareCardTheme.athleticDark, 'ATHLETIC DARK'),
                const SizedBox(width: AppSpacing.s8),
                _buildThemePill(ShareCardTheme.cyberVanguard, 'CYBER NEON'),
                const SizedBox(width: AppSpacing.s8),
                _buildThemePill(ShareCardTheme.stealth, 'STEALTH'),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s16),

          // The Captured Share Card Container Preview
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: _buildShareCardWidget(),
            ),
          ),

          const SizedBox(height: AppSpacing.s16),

          // Success notification banner if exported
          if (_exportSuccessMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: AppSpacing.br12,
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _exportSuccessMessage!,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],

          // Error notification banner if failure occurs
          if (_exportErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: AppSpacing.br12,
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _exportErrorMessage!,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],

          // Export and Save Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  label: _isExporting ? 'GENERATING 1080P...' : 'GENERATE & EXPORT CARD',
                  icon: Icons.share_rounded,
                  onPressed: _isExporting ? null : _exportCard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br12),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.accent),
                    label: Text(
                      'SAVE PNG',
                      style: AppText.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: _isExporting ? null : _saveCardToDevice,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br12),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 16, color: AppColors.accent),
                    label: const Text('EXPORT GPX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () async {
                      await ExportService().exportAndShareGpx(
                        runTitle: 'Territory Run - ${widget.callsign}',
                        coordinates: widget.points,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br12),
                    ),
                    icon: const Icon(Icons.polyline_rounded, size: 16, color: AppColors.info),
                    label: const Text('EXPORT GEOJSON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () async {
                      await ExportService().exportAndShareGeoJson(
                        territories: [
                          Territory(
                            id: 'run_share_${DateTime.now().millisecondsSinceEpoch}',
                            ownerId: widget.callsign,
                            polygon: widget.points,
                            capturedAt: widget.capturedAt,
                            color: AppColors.accent,
                            areaSqMeters: widget.areaSqMeters,
                          ),
                        ],
                        runTrack: widget.points,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemePill(ShareCardTheme theme, String label) {
    final isSelected = _selectedTheme == theme;
    return GestureDetector(
      onTap: () {
        AppMotion.lightTick();
        setState(() {
          _selectedTheme = theme;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: AppSpacing.brFull,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildShareCardWidget() {
    Color cardBg;
    Color accentColor;
    Color borderColor;
    bool hasGridOverlay;

    switch (_selectedTheme) {
      case ShareCardTheme.athleticDark:
        cardBg = AppColors.bgDeep;
        accentColor = AppColors.accent;
        borderColor = AppColors.border;
        hasGridOverlay = false;
        break;
      case ShareCardTheme.cyberVanguard:
        cardBg = const Color(0xFF080D14);
        accentColor = AppColors.rival;
        borderColor = AppColors.rival.withValues(alpha: 0.4);
        hasGridOverlay = true;
        break;
      case ShareCardTheme.stealth:
        cardBg = AppColors.surface;
        accentColor = AppColors.textPrimary;
        borderColor = AppColors.borderSubtle;
        hasGridOverlay = false;
        break;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340, minHeight: 350),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppSpacing.br24,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.br24,
        child: Stack(
          children: [
            // Background subtle grid if cyber theme
            if (hasGridOverlay)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CyberGridPainter(gridColor: accentColor.withValues(alpha: 0.08)),
                ),
              ),

            // Territory route path painter in center
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 140),
                child: CustomPaint(
                  painter: _ShareCardMapPainter(
                    points: widget.points,
                    accentColor: accentColor,
                  ),
                ),
              ),
            ),

            // Content Overlay
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top branding bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'TERRITORY RUNNER',
                                style: AppText.label.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: AppSpacing.br8,
                          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'SOVEREIGN RUN',
                          style: AppText.label.copyWith(
                            color: accentColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom athlete and run stats section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Runner Callout
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.callsign.toUpperCase(),
                              style: AppText.headingMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(),
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // High impact athletic 3-stat strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bgDeep.withValues(alpha: 0.75),
                          borderRadius: AppSpacing.br16,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildStatItem('DISTANCE', '${widget.distanceKm.toStringAsFixed(2)} KM', accentColor)),
                            Container(width: 1, height: 26, color: AppColors.divider),
                            Expanded(child: _buildStatItem('PACE', '${_formatPace()} /KM', accentColor)),
                            Container(width: 1, height: 26, color: AppColors.divider),
                            Expanded(child: _buildStatItem('CLAIMED', _formatArea(), accentColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color accent) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.label.copyWith(
            color: AppColors.textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppText.statSmall.copyWith(
            fontSize: 12.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ShareCardMapPainter extends CustomPainter {
  final List<LatLng> points;
  final Color accentColor;

  _ShareCardMapPainter({
    required this.points,
    required this.accentColor,
  });

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
      final double y = padding + (1.0 - ((p.latitude - minLat) / latSpan)) * usableH;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill territory
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Outer glow stroke
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Sharp stroke
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Glowing origin node
    if (points.isNotEmpty) {
      final p0 = points.first;
      final double x0 = padding + ((p0.longitude - minLng) / lngSpan) * usableW;
      final double y0 = padding + (1.0 - ((p0.latitude - minLat) / latSpan)) * usableH;

      canvas.drawCircle(Offset(x0, y0), 7, Paint()..color = accentColor.withValues(alpha: 0.4));
      canvas.drawCircle(Offset(x0, y0), 3.5, Paint()..color = Colors.white);
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
    canvas.drawCircle(Offset(cx + r, cy), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ShareCardMapPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accentColor != accentColor;
  }
}

class _CyberGridPainter extends CustomPainter {
  final Color gridColor;

  _CyberGridPainter({required this.gridColor});

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
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) => false;
}
