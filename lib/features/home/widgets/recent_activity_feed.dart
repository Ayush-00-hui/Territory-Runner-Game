import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/run_log_entry.dart';
import '../../../models/territory.dart';
import '../../../services/app_preferences.dart';
import '../../../services/run_log_service.dart';
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
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }

  void _showRunDetail(BuildContext context, Territory territory) {
    final areaDisplay = territory.areaSqMeters >= 10000
        ? '${(territory.areaSqMeters / 1000000.0).toStringAsFixed(3)} km²'
        : '${territory.areaSqMeters.toStringAsFixed(0)} m²';

    AppSheet.show(
      context: context,
      builder: (ctx) => AppSheet(
        title: 'Run summary',
        subtitle: _formatDate(territory.capturedAt),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Map Preview
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.br16,
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.br16,
                child: CustomPaint(
                  painter: _MiniPolygonPainter(points: territory.polygon),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s16),

            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.br16,
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: Column(
                children: [
                  _metricRow('Claimed area', areaDisplay),
                  const Divider(color: AppColors.borderSubtle, height: 16),
                  _metricRow(
                    'Loop segments',
                    '${territory.polygons.length} connected',
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 16),
                  _metricRow(
                    'Status',
                    territory.isPendingReview
                        ? 'Pending review'
                        : 'Verified territory',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Share card',
                    icon: Icons.share_rounded,
                    onPressed: () {
                      Navigator.pop(ctx);
                      final profile = TerritoryService().getProfile();
                      const distance = Distance();
                      double meters = 0.0;
                      for (int i = 0; i < territory.polygon.length - 1; i++) {
                        meters += distance(
                          territory.polygon[i],
                          territory.polygon[i + 1],
                        );
                      }
                      if (territory.polygon.length > 2) {
                        meters += distance(
                          territory.polygon.last,
                          territory.polygon.first,
                        );
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
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.labelSmall),
        Text(value, style: AppText.bodyBold),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final rem = mins % 60;
      return '${hrs}h ${rem}m';
    }
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  String _runTitle(RunLogEntry entry) {
    if (entry.title != null && entry.title!.trim().isNotEmpty) {
      return entry.title!.trim();
    }
    if (entry.claimedAreaSqM > 0) return 'Closed loop';
    if (entry.activityType == 'walking') return 'Territory walk';
    if (entry.activityType == 'cycling') return 'Explore ride';
    return 'Outdoor run';
  }

  void _showRunEntryDetail(
    BuildContext context,
    RunLogEntry entry,
    List<LatLng> routePoints,
  ) {
    final km = entry.distanceM / 1000.0;
    final areaDisplay = AppPreferences().formatArea(entry.claimedAreaSqM);

    AppSheet.show(
      context: context,
      builder: (ctx) => AppSheet(
        title: _runTitle(entry),
        subtitle: _formatDate(entry.startedAt),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.br16,
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.br16,
                child: CustomPaint(
                  painter: _MiniPolygonPainter(
                    points: routePoints,
                    closePath: entry.claimedAreaSqM > 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.br16,
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: Column(
                children: [
                  _metricRow('Distance', '${km.toStringAsFixed(2)} km'),
                  const Divider(color: AppColors.borderSubtle, height: 16),
                  _metricRow(
                    'Moving time',
                    _formatDuration(entry.movingSeconds),
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 16),
                  _metricRow(
                    'Claimed area',
                    entry.claimedAreaSqM > 0 ? areaDisplay : 'Open route',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Share card',
                    icon: Icons.share_rounded,
                    onPressed: () {
                      Navigator.pop(ctx);
                      final profile = TerritoryService().getProfile();
                      RunShareCardModal.show(
                        context: context,
                        distanceKm: km,
                        durationSeconds: entry.movingSeconds,
                        areaSqMeters: entry.claimedAreaSqM,
                        points: routePoints,
                        callsign: profile.username,
                        faction: profile.faction,
                        capturedAt: entry.startedAt,
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RunLogEntry>>(
      valueListenable: RunLogService().runsNotifier,
      builder: (context, _, _) {
        final realRuns = RunLogService().isBoxOpen
            ? RunLogService()
                  .getAllRuns()
                  .where((r) => !r.simulated)
                  .take(5)
                  .toList()
            : const <RunLogEntry>[];

        if (realRuns.isNotEmpty) {
          return Column(
            children: realRuns.map((entry) {
              final routePoints = entry.samples
                  .map((s) => LatLng(s.lat, s.lng))
                  .toList(growable: false);
              final double km = entry.distanceM / 1000.0;
              final bool hasArea = entry.claimedAreaSqM > 0;
              final String badgeText = hasArea
                  ? '+${AppPreferences().formatArea(entry.claimedAreaSqM)}'
                  : '${km.toStringAsFixed(2)} km';

              return AppCard(
                padding: EdgeInsets.zero,
                onTap: () => _showRunEntryDetail(context, entry, routePoints),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  child: Row(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: AppRadius.br12,
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.br12,
                          child: CustomPaint(
                            painter: _MiniPolygonPainter(
                              points: routePoints,
                              closePath: hasArea,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    _runTitle(entry),
                                    style: AppText.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  _formatDate(entry.startedAt),
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentContainer,
                                    borderRadius: AppRadius.br8,
                                    border: Border.all(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: AppText.micro.copyWith(
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Flexible(
                                  child: Text(
                                    '${km.toStringAsFixed(1)} km · ${_formatDuration(entry.movingSeconds)}',
                                    style: AppText.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
              );
            }).toList(),
          );
        }

        if (territories.isEmpty) {
          return AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: EmptyState(
              icon: Icons.directions_run_rounded,
              title: 'No runs yet',
              message: 'Lace up your shoes and run a closed loop to claim territory.',
              actionLabel: 'Start run',
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

            return AppCard(
              padding: EdgeInsets.zero,
              onTap: () {
                _showRunDetail(context, territory);
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s14),
                child: Row(
                  children: [
                    // Mini polygon preview container
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: AppRadius.br12,
                        border: Border.all(
                          color: AppColors.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.br12,
                        child: CustomPaint(
                          painter: _MiniPolygonPainter(
                            points: territory.polygon,
                          ),
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
                              Flexible(
                                child: Text(
                                  'Closed loop',
                                  style: AppText.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                _formatDate(territory.capturedAt),
                                style: AppText.caption,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentContainer,
                                  borderRadius: AppRadius.br8,
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '+$areaDisplay',
                                  style: AppText.micro.copyWith(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Flexible(
                                child: Text(
                                  '${territory.polygon.length} pts',
                                  style: AppText.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
            );
          }).toList(),
        );
      },
    );
  }
}

class _MiniPolygonPainter extends CustomPainter {
  final List<LatLng> points;
  final bool closePath;

  _MiniPolygonPainter({required this.points, this.closePath = true});

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
    final double drawW = size.width - 2 * padding;
    final double drawH = size.height - 2 * padding;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = padding + ((p.longitude - minLng) / lngSpan) * drawW;
      final y =
          size.height - (padding + ((p.latitude - minLat) / latSpan) * drawH);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (closePath) {
      path.close();

      // Fill with territoryMineFill
      final fillPaint = Paint()
        ..color = AppColors.territoryMineFill
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Stroke with solid accent border
    final strokePaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniPolygonPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.closePath != closePath;
}
