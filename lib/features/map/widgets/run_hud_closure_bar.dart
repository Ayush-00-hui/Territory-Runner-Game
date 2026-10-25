import 'package:flutter/material.dart';

import '../../../models/run_goal.dart';
import '../../../ui/ui.dart';

/// Renders the Campaign Goal Progress Banner and Enclosure Proximity Meter.
class RunHudClosureBar extends StatelessWidget {
  final bool isRunActive;
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final double? distanceToClosureMeters;
  final double? proximityToClosure;
  final RunGoal? runGoal;
  final double currentAreaSqm;
  final VoidCallback? onOpenGoalSelector;

  const RunHudClosureBar({
    super.key,
    required this.isRunActive,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.movingSeconds,
    this.distanceToClosureMeters,
    this.proximityToClosure,
    this.runGoal,
    this.currentAreaSqm = 0.0,
    this.onOpenGoalSelector,
  });

  @override
  Widget build(BuildContext context) {
    final double proximity = (proximityToClosure ?? 0.0).clamp(0.0, 1.0);
    final double? closureDist = distanceToClosureMeters;
    final bool isNearClosure = proximity >= 0.75;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Active Campaign Goal Progress Banner
        if (runGoal != null && runGoal!.isActive) ...[
          Semantics(
            button: true,
            label: 'Run goal: ${runGoal!.title}. Tap to configure.',
            child: GestureDetector(
              onTap: onOpenGoalSelector,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.br12,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.flag_rounded,
                                  color: AppColors.gold,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  runGoal!.title,
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              runGoal!.formatRemaining(
                                currentDistanceKm: distanceKm,
                                currentDurationSeconds: movingSeconds > 0
                                    ? movingSeconds
                                    : elapsedSeconds,
                                currentAreaSqm: currentAreaSqm,
                              ),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 9.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: AppSpacing.br8,
                      child: LinearProgressIndicator(
                        value: runGoal!
                            .computeProgress(
                              currentDistanceKm: distanceKm,
                              currentDurationSeconds: movingSeconds > 0
                                  ? movingSeconds
                                  : elapsedSeconds,
                              currentAreaSqm: currentAreaSqm,
                            )
                            .clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppColors.surface2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Enclosure Proximity Meter (appears when actively recording a loop)
        if (isRunActive && closureDist != null && closureDist > 0) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s10),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s6,
            ),
            decoration: BoxDecoration(
              color: (isNearClosure ? AppColors.accent : AppColors.surface2)
                  .withValues(alpha: 0.18),
              borderRadius: AppSpacing.br12,
              border: Border.all(
                color: isNearClosure ? AppColors.accent : AppColors.border,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.all_inclusive_rounded,
                  color: isNearClosure ? AppColors.accent : AppColors.info,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isNearClosure
                                    ? 'Ready to close loop'
                                    : 'Loop proximity',
                                style: AppText.labelSmall.copyWith(
                                  color: isNearClosure
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${closureDist.round()} m to start',
                                style: AppText.labelSmall.copyWith(
                                  color: isNearClosure
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: AppSpacing.br8,
                        child: LinearProgressIndicator(
                          value: proximity,
                          minHeight: 5,
                          backgroundColor: AppColors.surface2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isNearClosure ? AppColors.accent : AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
