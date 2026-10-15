import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../models/territory.dart';
import '../../../ui/ui.dart';
import '../../gameplay/territory_service.dart';
import '../../history/widgets/run_share_card_modal.dart';

class RecentActivityFeed extends StatelessWidget {
  final List<Territory> territories;
  final VoidCallback? onStartRun;

  const RecentActivityFeed({
    super.key,
    required this.territories,
    this.onStartRun,
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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }

  void _showRunDetail(BuildContext context, Territory territory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final areaDisplay = territory.areaSqMeters >= 10000
            ? '${(territory.areaSqMeters / 1000000.0).toStringAsFixed(3)} km²'
            : '${territory.areaSqMeters.toStringAsFixed(0)} m²';

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CONQUEST SUMMARY',
                    style: AppText.label.copyWith(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    _formatDate(territory.capturedAt),
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Large Map Preview
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br20,
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: AppSpacing.br20,
                  child: CustomPaint(
                    painter: _MiniPolygonPainter(points: territory.polygon),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.s16),

              Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br16,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _metricRow('CLAIMED AREA', areaDisplay),
                    const Divider(color: AppColors.border, height: 16),
                    _metricRow('POLYGON SECTORS', '${territory.polygons.length} Contiguous'),
                    const Divider(color: AppColors.border, height: 16),
                    _metricRow('SECURITY STATUS', territory.isPendingReview ? 'Pending Review' : 'Verified Sovereign ✓'),
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
                        side: const BorderSide(color: AppColors.accent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('SHARE CARD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final profile = TerritoryService().getProfile();
                        const distance = Distance();
                        double meters = 0.0;
                        for (int i = 0; i < territory.polygon.length - 1; i++) {
                          meters += distance(territory.polygon[i], territory.polygon[i + 1]);
                        }
                        if (territory.polygon.length > 2) {
                          meters += distance(territory.polygon.last, territory.polygon.first);
                        }
                        final km = meters / 1000.0;

                        RunShareCardModal.show(
                          context: context,
                          distanceKm: km,
                          durationSeconds: (km * 330).round(),
                          areaSqMeters: territory.areaSqMeters,
                          points: territory.polygon,
                          callsign: profile.username,
                          faction: profile.faction,
                          capturedAt: territory.capturedAt,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'DISMISS',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 11)),
        Text(value, style: AppText.bodyBold.copyWith(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (territories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.br24,
          border: Border.all(color: AppColors.border),
        ),
        child: EmptyState(
          icon: Icons.directions_run_rounded,
          title: 'No Conquests Yet',
          message: 'Lace up your shoes and run a closed loop to claim sovereign territory.',
          actionLabel: 'START FIRST RUN',
          onAction: onStartRun,
        ),
      );
    }

    final recentItems = territories.reversed.take(5).toList();

    return Column(
      children: recentItems.map((territory) {
        final areaDisplay = territory.areaSqMeters >= 10000
            ? '${(territory.areaSqMeters / 1000000.0).toStringAsFixed(2)} km²'
            : '${territory.areaSqMeters.toStringAsFixed(0)} m²';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.br20,
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: AppSpacing.br20,
            child: InkWell(
              borderRadius: AppSpacing.br20,
              onTap: () {
                AppMotion.lightTick();
                _showRunDetail(context, territory);
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s14),
                child: Row(
                  children: [
                    // Mini polygon preview container
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: AppSpacing.br14,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: AppSpacing.br14,
                        child: CustomPaint(
                          painter: _MiniPolygonPainter(points: territory.polygon),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),

                    // Run info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SOVEREIGN LOOP',
                                style: AppText.headingSmall.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: AppSpacing.br8,
                                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '+$areaDisplay CLAIMED',
                                  style: AppText.label.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                '${territory.polygon.length} pts',
                                style: AppText.bodySmall.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MiniPolygonPainter extends CustomPainter {
  final List<LatLng> points;

  _MiniPolygonPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      // Draw grid placeholder
      final p = Paint()
        ..color = Colors.white10
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
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
      final double y = padding + (1.0 - ((p.latitude - minLat) / latSpan)) * usableH;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Glowing waypoint dot at start point
    if (points.isNotEmpty) {
      final p0 = points.first;
      final double x0 = padding + ((p0.longitude - minLng) / lngSpan) * usableW;
      final double y0 = padding + (1.0 - ((p0.latitude - minLat) / latSpan)) * usableH;

      final dotGlow = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x0, y0), 5, dotGlow);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x0, y0), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPolygonPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
