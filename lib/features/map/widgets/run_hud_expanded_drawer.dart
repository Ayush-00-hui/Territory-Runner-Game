import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Collapsible extended metrics drawer revealing average pace, moving time, active area,
/// elevation gain, current incline/grade, and cadence.
class RunHudExpandedDrawer extends StatelessWidget {
  final bool isExpanded;
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final double currentAreaSqm;
  final double grade;
  final double elevationGainMeters;
  final double cadenceSpm;
  final double? strideLengthMeters;

  const RunHudExpandedDrawer({
    super.key,
    required this.isExpanded,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.currentAreaSqm,
    this.grade = 0.0,
    this.elevationGainMeters = 0.0,
    this.cadenceSpm = 0.0,
    this.strideLengthMeters,
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

  String _calculateAvgPace(double km, int seconds) {
    if (km <= 0.05 || seconds < 5) return "--'--\"";
    final double paceSecondsPerKm = seconds / km;
    if (paceSecondsPerKm > 3600) return "--'--\"";
    final int pMin = (paceSecondsPerKm ~/ 60).clamp(0, 59);
    final int pSec = (paceSecondsPerKm.round() % 60).clamp(0, 59);
    return "$pMin'${pSec.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final gradePct = grade * 100.0;
    final gradeString =
        '${gradePct > 0 ? '+' : ''}${gradePct.toStringAsFixed(1)}%';

    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: isExpanded
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s10),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br14,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Avg pace | Moving time | Active area
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Avg pace', style: AppText.labelSmall),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _calculateAvgPace(
                                    distanceKm,
                                    movingSeconds > 0
                                        ? movingSeconds
                                        : elapsedSeconds,
                                  ),
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Moving time',
                                style: AppText.labelSmall,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatDuration(movingSeconds),
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Active area',
                                style: AppText.labelSmall,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  currentAreaSqm > 0
                                      ? '${(currentAreaSqm / 10000).toStringAsFixed(1)} ha'
                                      : '0.0 ha',
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 12,
                                    color: AppColors.accent,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s8),
                    const Divider(color: AppColors.borderSubtle, height: 1),
                    const SizedBox(height: AppSpacing.s8),

                    // Row 2: Elev Gain | Grade | Cadence / Stride
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Elev gain',
                                style: AppText.labelSmall,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '+${elevationGainMeters.toStringAsFixed(0)} m',
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Grade', style: AppText.labelSmall),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  gradeString,
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 12,
                                    color: grade.abs() >= 0.05
                                        ? AppColors.warning
                                        : AppColors.textPrimary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Cadence', style: AppText.labelSmall),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  cadenceSpm > 0
                                      ? '${cadenceSpm.toStringAsFixed(0)} spm'
                                      : '-- spm',
                                  style: AppText.bodyBold.copyWith(
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
      crossFadeState: isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: AppMotion.duration(context, AppMotion.standard),
    );
  }
}
