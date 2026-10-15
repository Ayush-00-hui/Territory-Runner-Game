import 'package:flutter/material.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/motion/motion.dart';

/// Strava / Nike Run Club Grade Live Telemetry HUD Obsidian Glass Card.
/// Wrapped in a [RepaintBoundary] to isolate metric updates from map redraws.
class RunHud extends StatelessWidget {
  final bool isRunActive;
  final bool isAutoPaused;
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final String splitPace;
  final double currentSpeedKmh;
  final double satelliteAccuracyMeters;
  final int territoriesClaimed;
  final VoidCallback onToggleRun;
  final VoidCallback onSealShape;
  final VoidCallback onFinishRun;

  const RunHud({
    super.key,
    required this.isRunActive,
    required this.isAutoPaused,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.splitPace,
    required this.currentSpeedKmh,
    required this.satelliteAccuracyMeters,
    required this.territoriesClaimed,
    required this.onToggleRun,
    required this.onSealShape,
    required this.onFinishRun,
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s16, AppSpacing.s14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: AppSpacing.br28,
          border: Border.all(
            color: isAutoPaused ? AppColors.warning.withValues(alpha: 0.6) : AppColors.border,
            width: 1.2,
          ),
          boxShadow: AppSpacing.hudShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Auto-Pause Banner
            if (isAutoPaused && isRunActive) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: AppSpacing.brFull,
                  border: Border.all(color: AppColors.warning, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle_filled_rounded, color: AppColors.warning, size: 14),
                    SizedBox(width: AppSpacing.s6),
                    Text(
                      'AUTO-PAUSED • MOVING SPEED < 1.5 KM/H',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Core Strava Metric Readouts: Distance | Time | Split Pace
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Massive Distance (Tabular Oswald)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DISTANCE', style: AppText.label),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isRunActive ? distanceKm.toStringAsFixed(2) : '0.00',
                          style: AppText.statLarge.copyWith(fontSize: 30),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        const Text('KM', style: AppText.labelAccent),
                      ],
                    ),
                  ],
                ),

                // Moving Time (Tabular Oswald)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('TIME', style: AppText.label),
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
                    Text(
                      isRunActive
                          ? _formatDuration(movingSeconds > 0 ? movingSeconds : elapsedSeconds)
                          : '00:00',
                      style: AppText.timer,
                    ),
                  ],
                ),

                // Instantaneous Split Pace (Tabular Oswald)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('AVG PACE', style: AppText.label),
                    const SizedBox(height: 2),
                    Text(
                      isRunActive ? splitPace : "--'--\"",
                      style: AppText.statLarge.copyWith(fontSize: 24),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s12),

            // Secondary Telemetry Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppSpacing.br14,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, color: AppColors.info, size: 14),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        '${currentSpeedKmh.toStringAsFixed(1)} km/h',
                        style: AppText.bodyBold.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.secondary, size: 14),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        '+${(distanceKm * 65.0).round()} kcal',
                        style: AppText.bodyBold.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.satellite_alt_rounded, color: AppColors.accent, size: 14),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        '±${satelliteAccuracyMeters.toStringAsFixed(0)}m',
                        style: AppText.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.accentSecondary, size: 14),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        '$territoriesClaimed territories',
                        style: AppText.bodyBold.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s14),

            // Bottom Action Controls: Seal Shape | Giant Action Play/Pause | Finish
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left "SEAL SHAPE" manual trigger
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      AppMotion.mediumTick();
                      onSealShape();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A2BE2).withValues(alpha: 0.22),
                        borderRadius: AppSpacing.br16,
                        border: Border.all(color: const Color(0xFF8A2BE2), width: 1.5),
                        boxShadow: AppSpacing.neonGlow(const Color(0xFF8A2BE2), blur: 8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, color: AppColors.info, size: 16),
                          SizedBox(width: AppSpacing.s4),
                          Flexible(
                            child: Text(
                              'SEAL SHAPE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.6,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.s8),

                // Center Giant Glowing Play/Pause Action Button
                GestureDetector(
                  onTap: () {
                    AppMotion.heavyBurst();
                    onToggleRun();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      boxShadow: AppSpacing.neonGlow(AppColors.accent, blur: 18, spread: 2),
                    ),
                    child: Center(
                      child: Icon(
                        isRunActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 34,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.s8),

                // Right Finish Button
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      AppMotion.lightTick();
                      onFinishRun();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: isRunActive ? AppColors.rival.withValues(alpha: 0.2) : AppColors.surface2,
                        borderRadius: AppSpacing.br16,
                        border: Border.all(
                          color: isRunActive ? AppColors.rival : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isRunActive ? Icons.stop_rounded : Icons.lock_outline_rounded,
                            color: isRunActive ? AppColors.rival : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Flexible(
                            child: Text(
                              isRunActive ? 'FINISH' : 'LOCKED',
                              style: TextStyle(
                                color: isRunActive ? AppColors.rival : Colors.white70,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.6,
                              ),
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
          ],
        ),
      ),
    );
  }
}
