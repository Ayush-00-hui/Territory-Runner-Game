import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/run_log_entry.dart';
import '../../../models/territory.dart';
import '../../../services/app_preferences.dart';
import '../../../services/elevation_splits_service.dart';
import '../../../ui/ui.dart';
import '../../profile/widgets/calorie_factors_sheet.dart';
import 'elevation_profile_chart.dart';
import 'run_share_card_modal.dart';
import 'splits_table.dart';

class HistoryRunCard extends StatelessWidget {
  final RunLogEntry? run;
  final Territory? territory;
  final String callsign;
  final String faction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const HistoryRunCard({
    super.key,
    this.run,
    this.territory,
    required this.callsign,
    required this.faction,
    this.onTap,
    this.onDelete,
  }) : assert(
         run != null || territory != null,
         'Either run or territory must be provided',
       );

  DateTime get _effectiveDate => run?.startedAt ?? territory!.capturedAt;

  double get _effectiveDistanceKm => run != null
      ? (run!.distanceM / 1000.0)
      : _estimateDistanceKm(territory!.polygon);

  int get _effectiveDurationSeconds =>
      run?.movingSeconds ?? (_effectiveDistanceKm * 330).round();

  double get _effectiveAreaSqm =>
      run?.claimedAreaSqM ?? territory!.areaSqMeters;

  List<LatLng> get _effectivePoints {
    if (run != null) {
      return run!.samples.map((s) => LatLng(s.lat, s.lng)).toList();
    }
    return territory!.polygon;
  }

  int get _effectiveCalories {
    if (run?.calories != null) return run!.calories!;
    return AppPreferences().estimateCalories(
      distanceKm: _effectiveDistanceKm,
      durationMinutes: _effectiveDurationSeconds > 0
          ? _effectiveDurationSeconds / 60.0
          : null,
    );
  }

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
    final areaDisplay = _effectiveAreaSqm >= 10000
        ? '${(_effectiveAreaSqm / 1000000.0).toStringAsFixed(3)} km²'
        : '${_effectiveAreaSqm.toStringAsFixed(0)} m²';
    final distKm = _effectiveDistanceKm;
    final estimatedCalories = _effectiveCalories;
    final quantile = AppPreferences().estimateQuantileCalories(
      distanceKm: distKm,
      durationMinutes: _effectiveDurationSeconds > 0
          ? _effectiveDurationSeconds / 60.0
          : null,
    );
    final profileData = ElevationSplitsService().computeProfile(
      samples:
          run?.samples ??
          _effectivePoints.asMap().entries.map((e) {
            final tMs =
                _effectiveDurationSeconds > 0 && _effectivePoints.length > 1
                ? ((_effectiveDurationSeconds * 1000) *
                          (e.key / (_effectivePoints.length - 1)))
                      .round()
                : e.key * 1000;
            return RunSample(
              timeOffsetMs: tMs,
              lat: e.value.latitude,
              lng: e.value.longitude,
            );
          }).toList(),
      unit: AppPreferences().unit,
      cacheKey: run?.id,
    );
    final scrubNotifier = ValueNotifier<LatLng?>(null);

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
                      style: AppText.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onDelete != null)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            tooltip: 'Delete run',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmDelete(context);
                            },
                          ),
                        Text(
                          _formatDate(_effectiveDate),
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
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
                    child: ValueListenableBuilder<LatLng?>(
                      valueListenable: scrubNotifier,
                      builder: (context, scrubPt, _) {
                        return CustomPaint(
                          painter: _HistoryPolygonPainter(
                            points: _effectivePoints,
                            scrubPoint: scrubPt,
                          ),
                        );
                      },
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
                      _metricRow('Distance', '${distKm.toStringAsFixed(2)} km'),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _metricRow(
                        'Calories',
                        '${AppPreferences().formatCalories(estimatedCalories)} (${quantile.displayRange})',
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Calorie model',
                            style: AppText.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'How we estimate this calories',
                            child: GestureDetector(
                              onTap: () {
                                CalorieFactorsSheet.show(
                                  context: context,
                                  distanceKm: distKm,
                                  durationSeconds: _effectiveDurationSeconds,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: AppSpacing.touchTarget,
                                  minWidth: AppSpacing.touchTarget,
                                ),
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'How we estimate this',
                                      style: AppText.caption.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s4),
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _metricRow(
                        'Track points',
                        '${_effectivePoints.length} GPS points',
                      ),
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _metricRow(
                        'Verification',
                        (run != null
                            ? (run!.syncStatus == 'synced'
                                  ? 'Verified run ✓'
                                  : 'Saved locally')
                            : (territory?.isPendingReview == false
                                  ? 'Verified territory ✓'
                                  : 'Pending Review')),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s16),

                // Elevation Profile Chart
                ElevationProfileChart(
                  profileData: profileData,
                  onScrub: (pt) => scrubNotifier.value = pt?.latLng,
                ),

                const SizedBox(height: AppSpacing.s16),

                // Real Splits Table
                SplitsTable(splits: profileData.splits, unit: profileData.unit),

                const SizedBox(height: AppSpacing.s20),

                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Share run',
                        icon: Icons.share_rounded,
                        onPressed: () {
                          Navigator.pop(ctx);
                          RunShareCardModal.show(
                            context: context,
                            distanceKm: distKm,
                            durationSeconds: _effectiveDurationSeconds,
                            areaSqMeters: _effectiveAreaSqm,
                            points: _effectivePoints,
                            callsign: callsign,
                            faction: faction,
                            capturedAt: _effectiveDate,
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.br16,
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Delete run?',
          style: AppText.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently remove this run from your local history.',
          style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppText.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brFull),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.bodyBold.copyWith(
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaDisplay = _effectiveAreaSqm >= 10000
        ? '${(_effectiveAreaSqm / 1000000.0).toStringAsFixed(2)} km²'
        : '${_effectiveAreaSqm.toStringAsFixed(0)} m²';
    final distKm = _effectiveDistanceKm;
    final cardCalories = _effectiveCalories;

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
                      painter: _HistoryPolygonPainter(points: _effectivePoints),
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
                              run != null
                                  ? (run!.claimedAreaSqM > 0
                                        ? 'Closed loop'
                                        : '${run!.activityType.toUpperCase()} RUN')
                                  : 'Closed loop',
                              overflow: TextOverflow.ellipsis,
                              style: AppText.labelLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            _formatDate(_effectiveDate),
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Wrap(
                        spacing: AppSpacing.s6,
                        runSpacing: AppSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: AppRadius.br8,
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '+$areaDisplay claimed',
                              style: AppText.labelSmall.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '${distKm.toStringAsFixed(2)} km • ${AppPreferences().formatCalories(cardCalories)}',
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textSecondary,
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
                    RunShareCardModal.show(
                      context: context,
                      distanceKm: distKm,
                      durationSeconds: _effectiveDurationSeconds,
                      areaSqMeters: _effectiveAreaSqm,
                      points: _effectivePoints,
                      callsign: callsign,
                      faction: faction,
                      capturedAt: _effectiveDate,
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
  final LatLng? scrubPoint;

  _HistoryPolygonPainter({required this.points, this.scrubPoint});

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

    if (scrubPoint != null) {
      final double sx =
          padding + ((scrubPoint!.longitude - minLng) / lngSpan) * usableW;
      final double sy =
          padding +
          (1.0 - ((scrubPoint!.latitude - minLat) / latSpan)) * usableH;
      final scrubOffset = Offset(sx, sy);

      final markerFill = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      final markerRing = Paint()
        ..color = AppColors.bgDeep
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(scrubOffset, 6.0, markerFill);
      canvas.drawCircle(scrubOffset, 6.0, markerRing);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPolygonPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.scrubPoint != scrubPoint;
  }
}
