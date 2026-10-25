import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Primary Distance, Time, Pace and Secondary Metrics Card for RunHud.
class RunHudMetricsCard extends StatelessWidget {
  final bool isRunActive;
  final bool isAutoPaused;
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final String splitPace;
  final String? targetPace;
  final double currentSpeedKmh;
  final double satelliteAccuracyMeters;
  final int stepCount;
  final int territoriesClaimed;
  final VoidCallback onToggleExpanded;

  const RunHudMetricsCard({
    super.key,
    required this.isRunActive,
    required this.isAutoPaused,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.splitPace,
    this.targetPace,
    required this.currentSpeedKmh,
    required this.satelliteAccuracyMeters,
    required this.stepCount,
    required this.territoriesClaimed,
    required this.onToggleExpanded,
  });

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSteps(int steps) {
    final str = steps.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return str.replaceAll(reg, ',');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Core Metric Readouts: Distance | Time | Pace
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Distance', style: AppText.labelSmall),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isRunActive ? distanceKm.toStringAsFixed(2) : '0.00',
                          style: AppText.statHero.copyWith(
                            fontSize: 32,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        const Text('km', style: AppText.labelAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Moving Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Time', style: AppText.labelSmall),
                      if (isRunActive && !isAutoPaused) ...[
                        const SizedBox(width: AppSpacing.s4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isRunActive
                          ? _formatDuration(movingSeconds > 0 ? movingSeconds : elapsedSeconds)
                          : '00:00',
                      style: AppText.timer.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pace
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pace', style: AppText.labelSmall),
                      if (targetPace != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: AppSpacing.br8,
                          ),
                          child: Text(
                            'P: $targetPace',
                            style: AppText.labelSmall.copyWith(color: AppColors.info, fontSize: 8.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isRunActive ? splitPace : "--'--\"",
                      style: AppText.statHero.copyWith(
                        fontSize: 26,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s12),

        // Secondary Telemetry Row (Tap to expand/collapse extended metrics)
        GestureDetector(
          onTap: onToggleExpanded,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s10,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br14,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed_rounded, color: AppColors.info, size: 14),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '${currentSpeedKmh.toStringAsFixed(1)} km/h',
                          style: AppText.bodyBold.copyWith(
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.rival, size: 14),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '+${(distanceKm * 65.0).round()} kcal',
                          style: AppText.bodyBold.copyWith(
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.satellite_alt_rounded,
                          color: satelliteAccuracyMeters <= 10.0
                              ? AppColors.accent
                              : (satelliteAccuracyMeters <= 30.0 ? AppColors.warning : AppColors.rival),
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          satelliteAccuracyMeters > 50.0
                              ? 'No GPS'
                              : '±${satelliteAccuracyMeters.toStringAsFixed(0)}m',
                          style: AppText.bodySmall.copyWith(
                            fontSize: 11,
                            color: satelliteAccuracyMeters <= 10.0
                                ? AppColors.textSecondary
                                : (satelliteAccuracyMeters <= 30.0 ? AppColors.warning : AppColors.rival),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Semantics(
                      label: 'estimated',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_walk_rounded, color: AppColors.accent, size: 14),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            '${_formatSteps(stepCount)} steps',
                            style: AppText.bodyBold.copyWith(
                              fontSize: 11,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.accent, size: 14),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '$territoriesClaimed claimed',
                          style: AppText.bodyBold.copyWith(
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
