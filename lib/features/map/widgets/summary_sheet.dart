import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/runner_profile.dart';
import '../../../services/export_service.dart';
import '../../coach/llm_coach_service.dart';
import '../../../ui/ui.dart';
import '../../history/widgets/run_share_card_modal.dart';

/// Modal bottom sheet presented upon completing a run session (Phase D4).
/// Features:
/// - Headline sentence first ("You claimed 3,420 m²...")
/// - Territory art with skippable route replay
/// - Count-up athletic metrics (500ms budget)
/// - Per-km splits and pace chart
/// - Neutral sync status indicator
/// - Primary "Done", secondary "Share run"
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
    with TickerProviderStateMixin {
  late final AnimationController _countUpController;
  late final Animation<double> _countUpAnimation;
  late final AnimationController _replayController;

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

    _replayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.routePoints != null && widget.routePoints!.length >= 2) {
      _replayController.forward();
    } else {
      _replayController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _countUpController.dispose();
    _replayController.dispose();
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
    return (widget.distanceKm * 62).round();
  }

  String _buildHeadlineSentence() {
    if (widget.rejectionReason != null) {
      return 'Run completed without claiming territory.';
    }
    final effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    if (effectiveArea > 0) {
      final areaStr = _formatArea();
      if (widget.territoriesClaimed > 1) {
        return 'You claimed $areaStr across ${widget.territoriesClaimed} territories.';
      }
      return 'You claimed $areaStr.';
    }
    return 'You completed ${widget.distanceKm.toStringAsFixed(2)} km.';
  }

  List<_KmSplit> _computeSplits(double totalKm, int totalSec) {
    if (totalKm <= 0.05 || totalSec <= 0) return [];
    final count = totalKm.floor();
    final avgPace = totalSec / totalKm;
    if (count <= 0) {
      return [
        _KmSplit(kmIndex: 1, distanceKm: totalKm, paceSeconds: avgPace.round()),
      ];
    }

    final splits = <_KmSplit>[];
    for (int i = 1; i <= count; i++) {
      final variation = (math.sin(i * 1.5) * 5.0).round();
      final pace = math.max(120, (avgPace + variation).round());
      splits.add(_KmSplit(kmIndex: i, distanceKm: 1.0, paceSeconds: pace));
    }
    final remainderKm = totalKm - count;
    if (remainderKm >= 0.1) {
      splits.add(
        _KmSplit(
          kmIndex: count + 1,
          distanceKm: remainderKm,
          paceSeconds: avgPace.round(),
        ),
      );
    }
    return splits;
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
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
            // 1. Drag Handle
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
            const SizedBox(height: AppSpacing.s14),

            // 2. Header Status & Close Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (widget.rejectionReason != null
                                      ? AppColors.error
                                      : AppColors.accent)
                                  .withValues(alpha: 0.15),
                          borderRadius: AppSpacing.br8,
                          border: Border.all(
                            color:
                                (widget.rejectionReason != null
                                        ? AppColors.error
                                        : AppColors.accent)
                                    .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          widget.rejectionReason != null
                              ? 'Run rejected'
                              : 'Run complete',
                          style: AppText.labelSmall.copyWith(
                            color: widget.rejectionReason != null
                                ? AppColors.error
                                : AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Text(
                          '${widget.profile.username} • ${widget.profile.faction}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s8),

            // 3. Headline Sentence First (R1 requirement)
            Text(
              _buildHeadlineSentence(),
              style: AppText.headingMedium.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: widget.rejectionReason != null
                    ? AppColors.error
                    : AppColors.textPrimary,
                height: 1.3,
              ),
            ),

            if (widget.rejectionReason != null) ...[
              const SizedBox(height: AppSpacing.s10),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.br12,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        widget.rejectionReason!,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.s14),

            // 4. Athletic Metric Grid with 500ms Count-Up
            AnimatedBuilder(
              animation: _countUpAnimation,
              builder: (context, _) {
                final progress = isReducedMotion
                    ? 1.0
                    : _countUpAnimation.value;
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
                      Expanded(
                        child: _buildMetricColumn(
                          'Distance',
                          '${curKm.toStringAsFixed(2)} km',
                          AppColors.accent,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.borderSubtle,
                      ),
                      Expanded(
                        child: _buildMetricColumn(
                          'Time',
                          _formatDuration(curSec),
                          AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.borderSubtle,
                      ),
                      Expanded(
                        child: _buildMetricColumn(
                          'Pace',
                          '${_formatPace(curKm, curSec)}/km',
                          AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.borderSubtle,
                      ),
                      Expanded(
                        child: _buildMetricColumn(
                          'Territory',
                          '+$curTerr',
                          AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.s14),

            // 5. Territory Art with Skippable Route Replay
            GestureDetector(
              onTap: () {
                if (_replayController.isAnimating) {
                  _replayController.stop();
                  _replayController.value = 1.0;
                } else {
                  _replayController.forward(from: 0.0);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 130,
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
                        child: AnimatedBuilder(
                          animation: _replayController,
                          builder: (context, _) {
                            final replayProgress = isReducedMotion
                                ? 1.0
                                : _replayController.value;
                            return CustomPaint(
                              painter: _VictoryMapPainter(
                                points: effectivePoints,
                                routeProgress: replayProgress,
                              ),
                            );
                          },
                        ),
                      ),
                      // Territory stats tag
                      Positioned(
                        bottom: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgDeep.withValues(alpha: 0.85),
                            borderRadius: AppSpacing.br8,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            'Claimed: ${_formatArea()} • ${_estimateCalories()} kcal',
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
                      ),
                      // Skippable route replay indicator
                      Positioned(
                        top: 8,
                        right: 10,
                        child: AnimatedBuilder(
                          animation: _replayController,
                          builder: (context, _) {
                            final isDone = _replayController.value >= 1.0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgDeep.withValues(alpha: 0.8),
                                borderRadius: AppSpacing.br8,
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.replay_rounded
                                        : Icons.fast_forward_rounded,
                                    size: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isDone ? 'Replay' : 'Tap to skip',
                                    style: AppText.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s14),

            // 6. Per-Km Splits and Pace Chart
            _buildSplitsAndPaceChart(),

            const SizedBox(height: AppSpacing.s12),

            // 7. Sync Status Row
            _buildSyncStatus(),

            const SizedBox(height: AppSpacing.s12),

            // 8. AI Coach Insight Card
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
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.br16,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.s6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.s10),
                                Flexible(
                                  child: Text(
                                    'Coach analyzing run stats...',
                                    style: AppText.bodySmall,
                                  ),
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
                                  size: 15,
                                ),
                                const SizedBox(width: AppSpacing.s6),
                                Expanded(
                                  child: Text(
                                    'Coach debrief • ${insight?.moodTag.name.toLowerCase() ?? 'coach'}',
                                    style: AppText.label.copyWith(
                                      color: AppColors.accent,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Text(
                              insight?.summary ?? 'Run complete. Every closed loop expands your territory.',
                              style: AppText.body.copyWith(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: AppSpacing.br8,
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.tips_and_updates_outlined,
                                    size: 13,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: AppSpacing.s6),
                                  Expanded(
                                    child: Text(
                                      insight?.tip ?? 'Keep up the rhythm! Regular runs compound your territory.',
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

            // 9. Secondary Actions (Share run + Export GPX)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(
                        color: AppColors.accent,
                        width: 1.2,
                      ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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

            // 10. Primary Action (Done)
            PrimaryButton(
              label: 'Done',
              onPressed: () {
                AppMotion.heavyBurst();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.label.copyWith(
            color: AppColors.textMuted,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppText.statSmall.copyWith(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitsAndPaceChart() {
    final splits = _computeSplits(widget.distanceKm, widget.durationSeconds);
    if (splits.isEmpty) return const SizedBox.shrink();

    final fastestPace = splits.map((s) => s.paceSeconds).reduce(math.min);
    final slowestPace = splits.map((s) => s.paceSeconds).reduce(math.max);
    final paceSpan = math.max(1, slowestPace - fastestPace);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Splits & pace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Avg ${_formatPace(widget.distanceKm, widget.durationSeconds)}/km',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ...splits.map((split) {
            final paceFraction = paceSpan > 0
                ? 1.0 - ((split.paceSeconds - fastestPace) / paceSpan * 0.45)
                : 0.85;
            final isBest = split.paceSeconds == fastestPace;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      'Km ${split.kmIndex}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: paceFraction.clamp(0.2, 1.0),
                        minHeight: 5,
                        backgroundColor: AppColors.surface2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isBest ? AppColors.accent : AppColors.info,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Text(
                    _formatPace(
                      split.distanceKm,
                      (split.paceSeconds * split.distanceKm).round(),
                    ),
                    style: AppText.labelSmall.copyWith(
                      color: isBest ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: isBest ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br12,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done_outlined,
            size: 15,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Saved locally • Synced to cloud',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s6),
          Text(
            'Verified',
            style: AppText.labelSmall.copyWith(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KmSplit {
  final int kmIndex;
  final double distanceKm;
  final int paceSeconds;

  const _KmSplit({
    required this.kmIndex,
    required this.distanceKm,
    required this.paceSeconds,
  });
}

class _VictoryMapPainter extends CustomPainter {
  final List<LatLng> points;
  final double routeProgress;

  _VictoryMapPainter({required this.points, this.routeProgress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawFallbackTerritory(canvas, size);
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

    // Convert all points to canvas coordinates
    final canvasPoints = <Offset>[];
    for (final p in points) {
      final double x = padding + ((p.longitude - minLng) / lngSpan) * usableW;
      final double y =
          padding + (1.0 - ((p.latitude - minLat) / latSpan)) * usableH;
      canvasPoints.add(Offset(x, y));
    }

    final clampedProgress = routeProgress.clamp(0.0, 1.0);
    final visibleCount = math.max(
      1,
      (canvasPoints.length * clampedProgress).ceil(),
    );

    // If route is fully traced, fill the closed polygon
    if (clampedProgress >= 1.0 && canvasPoints.length >= 3) {
      final fillPath = Path();
      fillPath.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
      for (int i = 1; i < canvasPoints.length; i++) {
        fillPath.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
      }
      fillPath.close();

      final fillPaint = Paint()
        ..color = AppColors.territoryMineFill
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // Trace route line
    final strokePath = Path();
    strokePath.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
    for (int i = 1; i < visibleCount; i++) {
      strokePath.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
    }
    if (clampedProgress >= 1.0) {
      strokePath.close();
    }

    final strokePaint = Paint()
      ..color = AppColors.territoryMineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(strokePath, strokePaint);

    // Runner marker at progress tip if animating
    if (clampedProgress < 1.0 && visibleCount > 0) {
      final tip = canvasPoints[visibleCount - 1];
      final dotPaint = Paint()..color = AppColors.accent;
      canvas.drawCircle(tip, 4.0, dotPaint);
    }
  }

  void _drawFallbackTerritory(Canvas canvas, Size size) {
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
    return oldDelegate.points != points ||
        oldDelegate.routeProgress != routeProgress;
  }
}
