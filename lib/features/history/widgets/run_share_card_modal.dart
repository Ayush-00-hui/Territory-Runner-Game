import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/territory.dart';
import '../../../services/export_service.dart';
import '../../../services/gallery_saver_service.dart';
import '../../../ui/ui.dart';
import 'run_share_card_actions.dart';
import 'run_share_card_export_dialog.dart';
import 'run_share_card_preview.dart';
import 'run_share_card_renderer.dart';
import 'run_share_card_theme_selector.dart';

export 'run_share_card_actions.dart';
export 'run_share_card_export_dialog.dart';
export 'run_share_card_painters.dart';
export 'run_share_card_preview.dart';
export 'run_share_card_renderer.dart';
export 'run_share_card_theme_selector.dart';

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

  /// Renders a true 1080x1080 PNG image of the share card
  Future<Uint8List> _renderTrue1080pCard() {
    return RunShareCardRenderer(
      distanceKm: widget.distanceKm,
      durationSeconds: widget.durationSeconds,
      areaSqMeters: widget.areaSqMeters,
      points: widget.points,
      callsign: widget.callsign,
      capturedAt: widget.capturedAt,
      theme: _selectedTheme,
    ).render();
  }

  /// Exports the card: renders true 1080x1080 PNG, writes to file, and opens system share sheet
  Future<void> _exportCard() async {
    setState(() {
      _isExporting = true;
      _exportSuccessMessage = null;
      _exportErrorMessage = null;
    });

    try {
      final Uint8List pngBytes = await _renderTrue1080pCard();
      final tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/territory_run_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('File was not written to storage');
      }

      final xFile = XFile(filePath, mimeType: 'image/png');
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text:
              'Claimed ${widget.callsign}\'s territory on Territory Runner! #TerritoryRunner',
        ),
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportSuccessMessage =
              'Share Card ready! 1080x1080 PNG rendered (${(pngBytes.lengthInBytes / 1024).toStringAsFixed(0)} KB)';
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

  /// Saves the true 1080x1080 PNG to the device gallery
  Future<void> _saveCardToGallery() async {
    setState(() {
      _isExporting = true;
      _exportSuccessMessage = null;
      _exportErrorMessage = null;
    });

    try {
      final Uint8List pngBytes = await _renderTrue1080pCard();
      final result = await GallerySaverService().savePng(pngBytes);

      if (mounted) {
        setState(() {
          _isExporting = false;
          if (result.success) {
            _exportSuccessMessage = result.message;
          } else {
            _exportErrorMessage = result.message;
          }
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
                    'Share run',
                    style: AppText.headingSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Export 1080x1080 run card for Strava & social',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Theme selector pills
          RunShareCardThemeSelector(
            selectedTheme: _selectedTheme,
            onThemeChanged: (theme) => setState(() => _selectedTheme = theme),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Preview
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: RunShareCardPreview(
                distanceKm: widget.distanceKm,
                durationSeconds: widget.durationSeconds,
                areaSqMeters: widget.areaSqMeters,
                points: widget.points,
                callsign: widget.callsign,
                capturedAt: widget.capturedAt,
                theme: _selectedTheme,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Notification Banners
          if (_exportSuccessMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: AppSpacing.br12,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
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
          if (_exportErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: AppSpacing.br12,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
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

          // Actions
          RunShareCardActions(
            isExporting: _isExporting,
            onShareCard: _exportCard,
            onSaveToGallery: _saveCardToGallery,
            onExportGpx: () async {
              await ExportService().exportAndShareGpx(
                runTitle: 'Territory Run - ${widget.callsign}',
                coordinates: widget.points,
              );
            },
            onExportGeoJson: () async {
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
            onExportMlTrace: () => showMlDebugExportDialog(
              context,
              callsign: widget.callsign,
              points: widget.points,
              distanceKm: widget.distanceKm,
              durationSeconds: widget.durationSeconds,
            ),
          ),
        ],
      ),
    );
  }
}
