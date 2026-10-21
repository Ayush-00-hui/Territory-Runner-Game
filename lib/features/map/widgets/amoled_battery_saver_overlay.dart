import 'package:flutter/material.dart';

import '../../../models/run_goal.dart';
import '../../../ui/ui.dart';

/// Pure Black (0xFF000000) AMOLED Low-Power Screen Overlay for long endurance runs.
/// Drastically conserves battery on OLED/AMOLED displays while keeping live metrics visible.
class AmoledBatterySaverOverlay extends StatelessWidget {
  final double distanceKm;
  final int elapsedSeconds;
  final String splitPace;
  final double currentSpeedKmh;
  final RunGoal? runGoal;
  final VoidCallback onWake;

  const AmoledBatterySaverOverlay({
    super.key,
    required this.distanceKm,
    required this.elapsedSeconds,
    required this.splitPace,
    required this.currentSpeedKmh,
    this.runGoal,
    required this.onWake,
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
    return Semantics(
      label: 'Endurance Battery Saver Mode active. Double tap anywhere on screen to wake map view.',
      child: GestureDetector(
        onDoubleTap: () {
          AppMotion.mediumTick();
          onWake();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black, // Pure black turns off OLED pixels
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s24,
                vertical: AppSpacing.s20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s10,
                          vertical: AppSpacing.s4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: AppSpacing.brFull,
                          border: Border.all(
                            color: AppColors.accent,
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.battery_charging_full_rounded,
                              color: AppColors.accent,
                              size: 14,
                            ),
                            SizedBox(width: AppSpacing.s4),
                            Text(
                              'Battery saver active',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Wake Map View',
                        icon: const Icon(
                          Icons.fullscreen_exit_rounded,
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                        onPressed: onWake,
                      ),
                    ],
                  ),

                  // Center Telemetry Numbers
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Elapsed Time
                      Text(
                        _formatDuration(elapsedSeconds),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 64,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                          letterSpacing: -1.0,
                        ),
                      ),
                      const Text(
                        'Duration',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.s32),

                      // Distance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            distanceKm.toStringAsFixed(2),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 54,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          const Text(
                            'km',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.s24),

                      // Pace & Speed Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                splitPace.isNotEmpty ? splitPace : "--'--\"",
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Current pace',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: AppColors.border,
                          ),
                          Column(
                            children: [
                              Text(
                                '${currentSpeedKmh.toStringAsFixed(1)} km/h',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Speed',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (runGoal != null && runGoal!.isActive) ...[
                        const SizedBox(height: AppSpacing.s24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s14,
                            vertical: AppSpacing.s6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: AppSpacing.brFull,
                            border: Border.all(
                              color: AppColors.gold,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            runGoal!.title,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Bottom Prompt
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        'Double-tap anywhere to wake map',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
