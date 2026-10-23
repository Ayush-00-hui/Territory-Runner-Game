import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/runner_profile.dart';
import '../../../services/export_service.dart';
import '../../coach/llm_coach_service.dart';
import '../../../ui/ui.dart';
import '../../history/widgets/run_share_card_modal.dart';

/// Modal bottom sheet presented upon completing a run session.
/// Redesigned as a high-impact post-run victory card with athletic stat grid,
/// AI Coach debrief card, territory map vector thumbnail, and share card export.
class SummarySheet extends StatefulWidget {
  final double distanceKm;
  final int durationSeconds;
  final int territoriesClaimed;
  final RunnerProfile profile;
  final LLMCoachService coachService;
  final List<LatLng>? routePoints;
  final double? areaSqMeters;
  final String? rejectionReason;

  const SummarySheet({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.territoriesClaimed,
    required this.profile,
    required this.coachService,
    this.routePoints,
    this.areaSqMeters,
    this.rejectionReason,
  });

  static Future<void> show({
    required BuildContext context,
    required double distanceKm,
    required int durationSeconds,
    required int territoriesClaimed,
    required RunnerProfile profile,
    required LLMCoachService coachService,
    List<LatLng>? routePoints,
    double? areaSqMeters,
    String? rejectionReason,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SummarySheet(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        territoriesClaimed: territoriesClaimed,
        profile: profile,
        coachService: coachService,
        routePoints: routePoints,
        areaSqMeters: areaSqMeters,
        rejectionReason: rejectionReason,
      ),
    );
  }

  @override
  State<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<SummarySheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countUpController;
  late final Animation<double> _countUpAnimation;

  @override
  void initState() {
    super.initState();
    _countUpController = AnimationController(
      vsync: this,
      duration: AppMotion.countUp,
    );
    _countUpAnimation = CurvedAnimation(
      parent: _countUpController,
      curve: AppMotion.easeOut,
    );
    _countUpController.forward();
  }

  @override
  void dispose() {
    _countUpController.dispose();
    super.dispose();
  }

  String _formatPace(double km, int durationSeconds) {
    if (km <= 0.05 || durationSeconds < 5) return "--'--\"";
    final double pace = (durationSeconds / 60.0) / km;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();
    return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"";
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int sec = seconds % 60;
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int remainingMins = minutes % 60;
      return '${hours}h ${remainingMins.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatArea() {
    final double effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    if (effectiveArea >= 10000) {
      return '${(effectiveArea / 1000000.0).toStringAsFixed(2)} km²';
    }
    return '${effectiveArea.toStringAsFixed(0)} m²';
  }

  int _estimateCalories() {
    // Athletic benchmark: ~62 kcal per km for average runner
    return (widget.distanceKm * 62).round();
  }

  @override
  Widget build(BuildContext context) {
    final effectivePoints = widget.routePoints ?? [];
    final effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    final isReducedMotion = AppMotion.shouldReduceMotion(context);
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      AppSpacing.s16,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        bottomInset + AppSpacing.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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

          // Header row with Victory or Rejection Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          (widget.rejectionReason != null
                                  ? AppColors.error
                                  : AppColors.accent)
                              .withValues(alpha: 0.15),
                      borderRadius: AppSpacing.br12,
                      border: Border.all(
                        color:
                            (widget.rejectionReason != null
                                    ? AppColors.error
                                    : AppColors.accent)
                                .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      widget.rejectionReason != null
                          ? Icons.cancel_outlined
                          : Icons.emoji_events_rounded,
                      color: widget.rejectionReason != null
                          ? AppColors.error
                          : AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.rejectionReason != null
                            ? 'Run rejected'
                            : 'Run complete',
                        style: AppText.headingSmall.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.rejectionReason != null
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.profile.username} • ${widget.profile.faction}',
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          if (widget.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: AppSpacing.br12,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rejection reason',
                          style: AppText.labelSmall.copyWith(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.rejectionReason!,
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.s16),

          // High Impact 4-Metric Athletic Grid with 500ms Count-Up
          AnimatedBuilder(
            animation: _countUpAnimation,
            builder: (context, _) {
              final progress = isReducedMotion ? 1.0 : _countUpAnimation.value;
              final double curKm = widget.distanceKm * progress;
              final int curSec = (widget.durationSeconds * progress).round();
              final int curTerr = (widget.territoriesClaimed * progress)
                  .round();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br20,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricColumn(
                      'Distance',
                      '${curKm.toStringAsFixed(2)} km',
                      AppColors.accent,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderSubtle,
                    ),
                    _buildMetricColumn(
                      'Time',
                      _formatDuration(curSec),
                      AppColors.textPrimary,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderSubtle,
                    ),
                    _buildMetricColumn(
                      'Pace',
                      '${_formatPace(curKm, curSec)}/km',
                      AppColors.textPrimary,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderSubtle,
                    ),
                    _buildMetricColumn(
                      'Territory',
                      '+$curTerr',
                      AppColors.accent,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.s14),

          // Territory Map Thumbnail
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: ClipRRect(
              borderRadius: AppSpacing.br16,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _VictoryMapPainter(points: effectivePoints),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withValues(alpha: 0.8),
                        borderRadius: AppSpacing.br8,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        'Claimed: ${_formatArea()} • ${_estimateCalories()} kcal',
                        style: AppText.label.copyWith(
                          color: AppColors.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.s14),

          // AI Coach Insight Card
          FutureBuilder<CoachInsight>(
            future: widget.coachService.generateRunInsight(
              distanceKm: widget.distanceKm,
              durationSeconds: widget.durationSeconds,
              hexesClaimed: widget.territoriesClaimed,
              profile: widget.profile,
            ),
            builder: (context, snapshot) {
              final insight = snapshot.data;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br16,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.s8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                              SizedBox(width: AppSpacing.s12),
                              Text(
                                'AI coach analyzing run stats...',
                                style: AppText.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: AppColors.accent,
                                size: 16,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                'AI coach debrief • ${insight?.moodTag.name.toLowerCase() ?? 'coach'}',
                                style: AppText.label.copyWith(
                                  color: AppColors.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Text(
                            insight?.summary ?? 'Run complete. Every closed loop expands your territory.',
                            style: AppText.body.copyWith(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: AppSpacing.br10,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.tips_and_updates_outlined,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.s6),
                                Expanded(
                                  child: Text(
                                    insight?.tip ?? 'Keep up the rhythm! Regular runs compound territory sovereignty.',
                                    style: AppText.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.s16),

          // Secondary Actions Row (Share run + Export GPX)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br16,
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Share run',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  onPressed: () {
                    AppMotion.lightTick();
                    RunShareCardModal.show(
                      context: context,
                      distanceKm: widget.distanceKm,
                      durationSeconds: widget.durationSeconds,
                      areaSqMeters: effectiveArea,
                      points: effectivePoints,
                      callsign: widget.profile.username,
                      faction: widget.profile.faction,
                      capturedAt: DateTime.now(),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br14,
                    ),
                  ),
                  icon: const Icon(
                    Icons.file_download_outlined,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  label: const Text(
                    'Export GPX',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  onPressed: () async {
                    AppMotion.lightTick();
                    await ExportService().exportAndShareGpx(
                      runTitle: 'Territory Run - ${widget.profile.username}',
                      coordinates: effectivePoints,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s12),

          // Primary Done Action Button (At the very bottom, above system gesture area)
          PrimaryButton(
            label: 'Done',
            onPressed: () {
              AppMotion.heavyBurst();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.label.copyWith(
            color: AppColors.textMuted,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppText.statSmall.copyWith(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _VictoryMapPainter extends CustomPainter {
  final List<LatLng> points;

  _VictoryMapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawFallbackConquest(canvas, size);
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

    const double padding = 10.0;
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
  }

  void _drawFallbackConquest(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.32;

    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final fillPaint = Paint()
      ..color = AppColors.territoryMineFill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _VictoryMapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
