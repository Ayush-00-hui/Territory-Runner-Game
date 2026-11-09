import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/interval_workout.dart';
import '../../../models/run_log_entry.dart';
import '../../../models/runner_profile.dart';
import '../../../services/app_preferences.dart';
import '../../../services/elevation_splits_service.dart';
import '../../../services/gallery_saver_service.dart';
import '../../../ui/ui.dart';
import '../../coach/llm_coach_service.dart';
import '../../history/widgets/elevation_profile_chart.dart';
import '../../history/widgets/run_share_card_modal.dart';
import '../../history/widgets/splits_table.dart';
import '../../profile/widgets/body_details_sheet.dart';
import '../../profile/widgets/calorie_factors_sheet.dart';
import 'summary_coach_card.dart';
import 'summary_route_replay.dart';
import 'summary_stats_grid.dart';
import 'summary_victory_header.dart';

/// Modal bottom sheet presented upon completing a run session (Phase D4).
class SummarySheet extends StatefulWidget {
  final double distanceKm;
  final int durationSeconds;
  final int territoriesClaimed;
  final RunnerProfile profile;
  final LLMCoachService coachService;
  final List<LatLng>? routePoints;
  final List<RunSample>? samples;
  final double? areaSqMeters;
  final String? rejectionReason;
  final double elevationGainMeters;
  final String? ghostResult;
  final IntervalWorkoutPlan? workoutPlan;
  final List<WorkoutPhaseExecution>? workoutExecutions;

  const SummarySheet({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.territoriesClaimed,
    required this.profile,
    required this.coachService,
    this.routePoints,
    this.samples,
    this.areaSqMeters,
    this.rejectionReason,
    this.elevationGainMeters = 0.0,
    this.ghostResult,
    this.workoutPlan,
    this.workoutExecutions,
  });

  static Future<void> show({
    required BuildContext context,
    required double distanceKm,
    required int durationSeconds,
    required int territoriesClaimed,
    required RunnerProfile profile,
    required LLMCoachService coachService,
    List<LatLng>? routePoints,
    List<RunSample>? samples,
    double? areaSqMeters,
    String? rejectionReason,
    double elevationGainMeters = 0.0,
    String? ghostResult,
    IntervalWorkoutPlan? workoutPlan,
    List<WorkoutPhaseExecution>? workoutExecutions,
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
        samples: samples,
        areaSqMeters: areaSqMeters,
        rejectionReason: rejectionReason,
        elevationGainMeters: elevationGainMeters,
        ghostResult: ghostResult,
        workoutPlan: workoutPlan,
        workoutExecutions: workoutExecutions,
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
  final ValueNotifier<LatLng?> _scrubPointNotifier = ValueNotifier<LatLng?>(
    null,
  );
  bool _reminderManuallyDismissed = false;

  bool get _shouldShowBodyReminder {
    if (_reminderManuallyDismissed) return false;
    final prefs = AppPreferences();
    if (prefs.hasBodyProfile) return false;
    final profile = prefs.bodyProfile;
    if (profile == null) return false;
    if (profile.reminderDismissed) return false;
    return profile.skippedRunCount >= 3;
  }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoSaveRunCard();
    });
  }

  void _triggerAutoSaveRunCard() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;
      final route = widget.routePoints;
      if (route == null || route.length < 3) return;
      if (!AppPreferences().isAutoSaveCardEnabled) return;

      final effectiveArea =
          widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
      final renderer = RunShareCardRenderer(
        distanceKm: widget.distanceKm,
        durationSeconds: widget.durationSeconds,
        areaSqMeters: effectiveArea,
        points: route,
        callsign: widget.profile.username.isNotEmpty
            ? widget.profile.username
            : 'RUNNER',
        capturedAt: DateTime.now(),
        theme: ShareCardTheme.athleticDark,
      );

      final pngBytes = await renderer.render();
      final result = await GallerySaverService().savePng(pngBytes);
      if (result.success) {
        AppToast.showGlobal(
          result.message,
          icon: Icons.check_circle_rounded,
          type: AppToastType.success,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countUpController.dispose();
    _replayController.dispose();
    _scrubPointNotifier.dispose();
    super.dispose();
  }

  String _formatArea() {
    final double effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    if (effectiveArea >= 10000) {
      return '${(effectiveArea / 1000000.0).toStringAsFixed(2)} km²';
    }
    return '${effectiveArea.toStringAsFixed(0)} m²';
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

  @override
  Widget build(BuildContext context) {
    final effectivePoints = widget.routePoints ?? [];
    final effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      AppSpacing.s16,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;
    final calories = AppPreferences().estimateCalories(
      distanceKm: widget.distanceKm,
      durationMinutes: widget.durationSeconds > 0
          ? widget.durationSeconds / 60.0
          : null,
      elevationGainMeters: widget.elevationGainMeters,
    );
    final quantile = AppPreferences().estimateQuantileCalories(
      distanceKm: widget.distanceKm,
      durationMinutes: widget.durationSeconds > 0
          ? widget.durationSeconds / 60.0
          : null,
      elevationGainMeters: widget.elevationGainMeters,
    );
    final activeWeightKg = AppPreferences().bodyWeightKg ?? 70.0;
    final profileData = ElevationSplitsService().computeProfile(
      samples:
          widget.samples ??
          effectivePoints.asMap().entries.map((e) {
            final tMs = widget.durationSeconds > 0 && effectivePoints.length > 1
                ? ((widget.durationSeconds * 1000) *
                          (e.key / (effectivePoints.length - 1)))
                      .round()
                : e.key * 1000;
            return RunSample(
              timeOffsetMs: tMs,
              lat: e.value.latitude,
              lng: e.value.longitude,
            );
          }).toList(),
      unit: AppPreferences().unit,
    );

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
            // 1. Victory Header
            SummaryVictoryHeader(
              headline: _buildHeadlineSentence(),
              rejectionReason: widget.rejectionReason,
              profile: widget.profile,
              onClose: () => Navigator.pop(context),
            ),

            if (widget.ghostResult != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Semantics(
                label: 'Ghost runner comparison: ${widget.ghostResult}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppRadius.br16,
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_run_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          widget.ghostResult!,
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (widget.workoutExecutions != null &&
                widget.workoutExecutions!.isNotEmpty) ...[
              _WorkoutPhasesSummaryCard(
                plan: widget.workoutPlan,
                executions: widget.workoutExecutions!,
              ),
            ],

            const SizedBox(height: AppSpacing.s16),

            // 2. Animated Metrics Grid & Splits
            SummaryStatsGrid(
              distanceKm: widget.distanceKm,
              durationSeconds: widget.durationSeconds,
              territoriesClaimed: widget.territoriesClaimed,
              effectiveArea: effectiveArea,
              countUpAnimation: _countUpAnimation,
            ),

            const SizedBox(height: AppSpacing.s14),

            // 3. Route Replay & Territory Art
            SummaryRouteReplay(
              routePoints: effectivePoints,
              effectiveArea: effectiveArea,
              calories: calories,
              replayController: _replayController,
              scrubNotifier: _scrubPointNotifier,
            ),

            const SizedBox(height: AppSpacing.s14),

            // 3b. Elevation Profile
            ElevationProfileChart(
              profileData: profileData,
              onScrub: (pt) => _scrubPointNotifier.value = pt?.latLng,
            ),

            const SizedBox(height: AppSpacing.s14),

            // 3c. Real Splits Table
            SplitsTable(splits: profileData.splits, unit: profileData.unit),

            const SizedBox(height: AppSpacing.s14),

            // 3d. Honest Calorie Range Card
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.rival,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          AppPreferences().formatCalories(calories),
                          style: AppText.statSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Likely between ${quantile.p10Kcal.round()} and ${quantile.p90Kcal.round()} kcal',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Based on ${activeWeightKg.toStringAsFixed(0)} kg, ${widget.distanceKm.toStringAsFixed(1)} km${widget.elevationGainMeters > 0 ? ", +${widget.elevationGainMeters.toStringAsFixed(0)} m climb" : ""}',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  InkWell(
                    onTap: () => CalorieFactorsSheet.show(
                      context: context,
                      weightKg: activeWeightKg,
                      distanceKm: widget.distanceKm,
                      durationSeconds: widget.durationSeconds,
                      elevationGainMeters: widget.elevationGainMeters,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.touchTarget,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'How we estimate this',
                              style: AppText.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
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
                ],
              ),
            ),

            if (_shouldShowBodyReminder) ...[
              const SizedBox(height: AppSpacing.s14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            'Personalize calorie estimates',
                            style: AppText.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            AppPreferences().dismissBodyDetailsReminder();
                            setState(() => _reminderManuallyDismissed = true);
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'Calorie burn is currently calculated for a standard 70 kg reference adult. Add your body details on this phone for personalized estimates.',
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s10),
                    Row(
                      children: [
                        SecondaryButton(
                          label: 'Set details',
                          icon: Icons.person_outline_rounded,
                          isFullWidth: false,
                          height: 48,
                          onPressed: () {
                            BodyDetailsSheet.show(
                              context: context,
                              onSaved: () {
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        SecondaryButton(
                          label: 'Keep default',
                          isFullWidth: false,
                          height: 48,
                          onPressed: () {
                            AppPreferences().dismissBodyDetailsReminder();
                            setState(() => _reminderManuallyDismissed = true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.s14),

            // 4. AI Coach Card & Actions
            SummaryCoachCard(
              distanceKm: widget.distanceKm,
              durationSeconds: widget.durationSeconds,
              territoriesClaimed: widget.territoriesClaimed,
              effectiveArea: effectiveArea,
              routePoints: effectivePoints,
              profile: widget.profile,
              coachService: widget.coachService,
              onDone: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutPhasesSummaryCard extends StatelessWidget {
  final IntervalWorkoutPlan? plan;
  final List<WorkoutPhaseExecution> executions;

  const _WorkoutPhasesSummaryCard({this.plan, required this.executions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  plan?.name ?? 'Interval workout',
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${executions.length} phases',
                style: AppText.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Phase',
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Planned',
                  textAlign: TextAlign.right,
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Actual',
                  textAlign: TextAlign.right,
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.s8),
          ...executions.map((e) {
            final phaseColor = e.phase.type.color;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Semantics(
                label:
                    '${e.phase.name}. Planned ${e.phase.formattedTarget}, actual ${e.formattedActualDuration}${e.isSkipped ? ', skipped' : ''}.',
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: phaseColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        e.phase.name,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.phase.formattedTarget,
                        textAlign: TextAlign.right,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.isSkipped
                            ? '${e.formattedActualDuration} (skip)'
                            : e.formattedActualDuration,
                        textAlign: TextAlign.right,
                        style: AppText.bodySmall.copyWith(
                          color: e.isSkipped
                              ? AppColors.warning
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
