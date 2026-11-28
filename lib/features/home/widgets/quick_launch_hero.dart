import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/run_log_entry.dart';
import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../services/app_preferences.dart';
import '../../../services/run_log_service.dart';
import '../../../ui/ui.dart';
import '../../coach/pace_prediction_service.dart';

/// Performance-first Home Hero Card featuring real daily goal progress or quiet goal setup,
/// active streak + AI target pill, zero fake numbers, and the primary Start Run action.
class QuickLaunchHero extends StatelessWidget {
  final RunnerProfile? profile;
  final List<Territory> territories;
  final VoidCallback? onStartRun;
  final bool isActive;

  const QuickLaunchHero({
    super.key,
    this.profile,
    this.territories = const [],
    this.onStartRun,
    this.isActive = true,
  });

  /// Computes real running distance in kilometers completed today, preferring
  /// the authoritative non-simulated [RunLogService] when open.
  double _computeTodayKm(List<RunLogEntry> runs) {
    final now = DateTime.now();
    if (RunLogService().isBoxOpen && runs.isNotEmpty) {
      double realKm = 0.0;
      for (final r in runs) {
        if (!r.simulated &&
            r.startedAt.year == now.year &&
            r.startedAt.month == now.month &&
            r.startedAt.day == now.day) {
          realKm += r.distanceM / 1000.0;
        }
      }
      if (realKm > 0 || territories.isEmpty) {
        return realKm;
      }
    }

    double totalKm = 0.0;
    const distance = Distance();

    for (final t in territories) {
      if (t.capturedAt.year == now.year &&
          t.capturedAt.month == now.month &&
          t.capturedAt.day == now.day) {
        if (t.polygon.length >= 2) {
          double meters = 0.0;
          for (int i = 0; i < t.polygon.length - 1; i++) {
            meters += distance(t.polygon[i], t.polygon[i + 1]);
          }
          meters += distance(t.polygon.last, t.polygon.first);
          totalKm += meters / 1000.0;
        }
      }
    }
    return totalKm;
  }

  void _showGoalPicker(BuildContext context, double? currentGoal) {
    double? selectedGoal = currentGoal ?? 5.0;

    AppSheet.show(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return AppSheet(
            title: 'Daily distance goal',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set an athletic target for your daily runs. Your goal ring advances with real completed routes.',
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [3.0, 5.0, 8.0, 10.0].map((km) {
                    final isSel = selectedGoal == km;
                    return AppChip(
                      label:
                          '${km.toStringAsFixed(km.truncateToDouble() == km ? 0 : 1)} km',
                      isSelected: isSel,
                      onTap: () {
                        setSheetState(() => selectedGoal = km);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.s24),
                PrimaryButton(
                  label: 'Save goal',
                  onPressed: () {
                    AppPreferences().setDailyGoalKm(selectedGoal);
                    Navigator.pop(sheetCtx);
                  },
                ),
                if (currentGoal != null && currentGoal > 0) ...[
                  const SizedBox(height: AppSpacing.s8),
                  SecondaryButton(
                    label: 'Clear daily goal',
                    onPressed: () {
                      AppPreferences().setDailyGoalKm(null);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppPreferences().dailyGoalKmNotifier,
        RunLogService().runsNotifier,
      ]),
      builder: (context, _) {
        final goalTargetKm = AppPreferences().dailyGoalKmNotifier.value;
        final List<RunLogEntry> runs = RunLogService().isBoxOpen
            ? RunLogService().runsNotifier.value
            : const [];
        final double todayKm = _computeTodayKm(runs);
        final bool hasGoal = goalTargetKm != null && goalTargetKm > 0;
        final double goalProgress = hasGoal
            ? (todayKm / goalTargetKm).clamp(0.0, 1.0)
            : 0.0;

        final int activeStreak = RunLogService().isBoxOpen
            ? RunLogService().computeActiveStreakDays(overrideRuns: runs)
            : math.max(0, profile?.currentStreak ?? 0);
        final pastRuns = PacePredictionService.pastRunsFromLog(runs);
        final prediction = PacePredictionService().predictTarget(
          profile ?? RunnerProfile(id: 'local', username: 'Runner'),
          recentRuns: pastRuns,
        );

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasGoal) ...[
                // Real Today's Goal Ring
                InkWell(
                  onTap: () => _showGoalPicker(context, goalTargetKm),
                  borderRadius: AppRadius.br16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ProgressRing(
                          progress: goalProgress,
                          size: 58,
                          strokeWidth: 5.5,
                          progressColor: AppColors.accent,
                          trackColor: AppColors.surface2,
                          center: Text(
                            '${(goalProgress * 100).round()}%',
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily goal', style: AppText.labelSmall),
                              const SizedBox(height: AppSpacing.s2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      todayKm.toStringAsFixed(1),
                                      style: AppText.displaySmall.copyWith(
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s4),
                                    Text(
                                      '/ ${goalTargetKm.toStringAsFixed(1)} km',
                                      style: AppText.statUnit,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          'Edit',
                          style: AppText.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Quiet "Set a goal" row when no goal is configured
                InkWell(
                  onTap: () => _showGoalPicker(context, null),
                  borderRadius: AppRadius.br12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s14,
                      vertical: AppSpacing.s10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadius.br12,
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.track_changes_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.s10),
                        Expanded(
                          child: Text(
                            'Daily distance goal',
                            style: AppText.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          'Set a goal',
                          style: AppText.labelMedium.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s12),

              // Compact Streak + AI Target Pill Row (maintains above-the-fold CTA)
              Row(
                children: [
                  if (activeStreak > 0) ...[
                    StreakFlameWidget(streakDays: activeStreak, iconSize: 14),
                    const SizedBox(width: AppSpacing.s8),
                  ],
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        AppPreferences().setDailyGoalKm(
                          prediction.targetDistanceKm,
                        );
                        AppToast.show(
                          context,
                          'Daily goal set to ${prediction.targetDistanceKm.toStringAsFixed(1)} km',
                        );
                      },
                      borderRadius: AppRadius.brFull,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s10,
                          vertical: AppSpacing.s4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentContainer,
                          borderRadius: AppRadius.brFull,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: AppSpacing.s4),
                            Flexible(
                              child: Text(
                                '${prediction.isColdStart ? "Target" : "AI target"}: ${prediction.targetDistanceKm.toStringAsFixed(1)} km @ ${prediction.paceFormatted}',
                                style: AppText.micro.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s14),

              // Primary CTA Button
              PrimaryButton(
                label: 'Start run',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  onStartRun?.call();
                },
              ),
              const SizedBox(height: AppSpacing.s8),

              // Motivation subtext
              Text(
                'Run closed loops to claim territory on foot.',
                textAlign: TextAlign.center,
                style: AppText.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
