import 'package:flutter/material.dart';

import '../../../models/interval_workout.dart';
import '../../../services/interval_workout_service.dart';
import '../../../ui/ui.dart';

/// Large high-contrast athletic HUD banner displaying active interval workout phase.
/// Includes remaining countdown/distance, phase type color bar, and 48dp skip phase target.
class IntervalWorkoutBanner extends StatelessWidget {
  final IntervalWorkoutSnapshot snapshot;
  final VoidCallback onSkipPhase;

  const IntervalWorkoutBanner({
    super.key,
    required this.snapshot,
    required this.onSkipPhase,
  });

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.currentPhase;
    final phaseColor = phase.type.color;
    final bannerCopy = snapshot.bannerText;

    return Semantics(
      liveRegion: true,
      label:
          'Interval phase: $bannerCopy. Step ${snapshot.phaseIndex + 1} of ${snapshot.totalPhases}.',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppRadius.br16,
          border: Border.all(
            color: phaseColor.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar Line
            LinearProgressIndicator(
              value: snapshot.progressFraction,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
              minHeight: 3.5,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                AppSpacing.s8,
                AppSpacing.s8,
                AppSpacing.s8,
              ),
              child: Row(
                children: [
                  // Phase Type Icon Badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        phase.type == WorkoutPhaseType.run
                            ? Icons.directions_run_rounded
                            : Icons.directions_walk_rounded,
                        size: 18,
                        color: phaseColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),

                  // Large High-Contrast Title & Step Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bannerCopy,
                          style: const TextStyle(
                            fontFamily: AppText.fontFamily,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.5,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Step ${snapshot.phaseIndex + 1} of ${snapshot.totalPhases} • ${snapshot.plan.name}',
                          style: AppText.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Skip Phase Action Target (>= 48x48dp touch target)
                  Semantics(
                    button: true,
                    label: 'Skip to next interval phase',
                    child: InkWell(
                      onTap: onSkipPhase,
                      borderRadius: AppRadius.brFull,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Skip',
                              style: AppText.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.skip_next_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
