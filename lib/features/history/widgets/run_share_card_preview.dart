import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../ui/ui.dart';
import 'run_share_card_painters.dart';
import 'run_share_card_renderer.dart';

/// Preview widget for the 1080x1080 share card inside the modal bottom sheet.
class RunShareCardPreview extends StatelessWidget {
  final double distanceKm;
  final int durationSeconds;
  final double areaSqMeters;
  final List<LatLng> points;
  final String callsign;
  final DateTime capturedAt;
  final ShareCardTheme theme;

  const RunShareCardPreview({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.areaSqMeters,
    required this.points,
    required this.callsign,
    required this.capturedAt,
    required this.theme,
  });

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

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    Color accentColor;
    Color borderColor;
    bool hasGridOverlay;

    switch (theme) {
      case ShareCardTheme.athleticDark:
        cardBg = AppColors.bgDeep;
        accentColor = AppColors.accent;
        borderColor = AppColors.border;
        hasGridOverlay = false;
        break;
      case ShareCardTheme.cyberVanguard:
        cardBg = AppColors.bgElevated;
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
        boxShadow: AppElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.br24,
        child: Stack(
          children: [
            // Background subtle grid if cyber theme
            if (hasGridOverlay)
              Positioned.fill(
                child: CustomPaint(
                  painter: CartographicGridPainter(
                    gridColor: accentColor.withValues(alpha: 0.08),
                  ),
                ),
              ),

            // Territory route path painter in center
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 140),
                child: CustomPaint(
                  painter: ShareCardMapPainter(
                    points: points,
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
                                  fontWeight: FontWeight.w700,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: AppSpacing.br8,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Closed loop',
                          style: AppText.label.copyWith(
                            color: accentColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
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
                              callsign.toUpperCase(),
                              style: AppText.headingMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgDeep.withValues(alpha: 0.75),
                          borderRadius: AppSpacing.br16,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                'DISTANCE',
                                '${distanceKm.toStringAsFixed(2)} KM',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 26,
                              color: AppColors.divider,
                            ),
                            Expanded(
                              child: _buildStatItem(
                                'PACE',
                                '${_formatPace()} /KM',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 26,
                              color: AppColors.divider,
                            ),
                            Expanded(
                              child: _buildStatItem(
                                'CLAIMED',
                                _formatArea(),
                              ),
                            ),
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

  Widget _buildStatItem(String label, String value) {
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
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
