import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/territory.dart';
import '../../../ui/ui.dart';
import 'run_share_card_modal.dart';

class HistoryRunCard extends StatelessWidget {
  final Territory territory;
  final String callsign;
  final String faction;
  final VoidCallback? onTap;

  const HistoryRunCard({
    super.key,
    required this.territory,
    required this.callsign,
    required this.faction,
    this.onTap,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute';
    } else if (diff.inDays <= 1) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
  }

  double _estimateDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    const distance = Distance();
    double meters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      meters += distance(points[i], points[i + 1]);
    }
    // Add closure
    meters += distance(points.last, points.first);
    return meters / 1000.0;
  }

  void _showDetailModal(BuildContext context) {
    final areaDisplay = territory.areaSqMeters >= 10000
        ? '${(territory.areaSqMeters / 1000000.0).toStringAsFixed(3)} km²'
        : '${territory.areaSqMeters.toStringAsFixed(0)} m²';
    final estimatedKm = _estimateDistanceKm(territory.polygon);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s24,
              AppSpacing.s20,
              AppSpacing.s24,
              MediaQuery.paddingOf(ctx).bottom + AppSpacing.s24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Run dossier',
                      style: AppText.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatDate(territory.capturedAt),
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),

                // Large Map Preview
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.br20,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: ClipRRect(
                    borderRadius: AppSpacing.br20,
                    child: CustomPaint(
                      painter: _HistoryPolygonPainter(
                        points: territory.polygon,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.s16),

                // Metric details
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.br16,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _metricRow('Claimed territory', areaDisplay),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _metricRow(
                        'Estimated distance',
                        '${estimatedKm.toStringAsFixed(2)} km',
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _metricRow(
                        'Polygon coordinates',
                        '${territory.polygon.length} GPS points',
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _metricRow(
                        'Verification',
                        territory.isPendingReview
                            ? 'Pending Review'
                            : 'Verified territory ✓',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.br16,
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text(
                          'Share run',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          RunShareCardModal.show(
                            context: context,
                            distanceKm: estimatedKm,
                            durationSeconds: (estimatedKm * 330)
                                .round(), // Realistic pace proxy
                            areaSqMeters: territory.areaSqMeters,
                            points: territory.polygon,
                            callsign: callsign,
                            faction: faction,
                            capturedAt: territory.capturedAt,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Done',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppText.label.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: AppText.bodyBold.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaDisplay = territory.areaSqMeters >= 10000
        ? '${(territory.areaSqMeters / 1000000.0).toStringAsFixed(2)} km²'
        : '${territory.areaSqMeters.toStringAsFixed(0)} m²';
    final estimatedKm = _estimateDistanceKm(territory.polygon);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.br20,
        child: InkWell(
          borderRadius: AppSpacing.br20,
          onTap: () {
            AppMotion.lightTick();
            if (onTap != null) {
              onTap!();
            } else {
              _showDetailModal(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Row(
              children: [
                // Mini polygon vector preview
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppSpacing.br14,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: ClipRRect(
                    borderRadius: AppSpacing.br14,
                    child: CustomPaint(
                      painter: _HistoryPolygonPainter(
                        points: territory.polygon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s14),

                // Territory details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Closed loop',
                              overflow: TextOverflow.ellipsis,
                              style: AppText.headingSmall.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            _formatDate(territory.capturedAt),
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: AppSpacing.br8,
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '+$areaDisplay claimed',
                              style: AppText.label.copyWith(
                                color: AppColors.accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '${estimatedKm.toStringAsFixed(2)} km • ${territory.polygon.length} pts',
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Share icon action
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  tooltip: 'Share Card',
                  onPressed: () {
                    AppMotion.lightTick();
                    RunShareCardModal.show(
                      context: context,
                      distanceKm: estimatedKm,
                      durationSeconds: (estimatedKm * 330).round(),
                      areaSqMeters: territory.areaSqMeters,
                      points: territory.polygon,
                      callsign: callsign,
                      faction: faction,
                      capturedAt: territory.capturedAt,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPolygonPainter extends CustomPainter {
  final List<LatLng> points;

  _HistoryPolygonPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final p = Paint()
        ..color = AppColors.borderSubtle
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        p,
      );
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        p,
      );
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

    const double padding = 8.0;
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

    final fillPaint = Paint()
      ..color = AppColors.territoryMineFill
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    if (points.isNotEmpty) {
      final p0 = points.first;
      final double x0 = padding + ((p0.longitude - minLng) / lngSpan) * usableW;
      final double y0 =
          padding + (1.0 - ((p0.latitude - minLat) / latSpan)) * usableH;

      final dotBorder = Paint()
        ..color = AppColors.bgDeep
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x0, y0), 4, dotBorder);

      final dotPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x0, y0), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPolygonPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
