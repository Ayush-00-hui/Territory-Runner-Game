import 'package:flutter/material.dart';

import '../../../models/run_goal.dart';
import '../../../ui/ui.dart';
import 'run_hud_closure_bar.dart';
import 'run_hud_controls_bar.dart';
import 'run_hud_expanded_drawer.dart';
import 'run_hud_metrics_card.dart';

/// Strava / Nike Run Club Grade Live Telemetry HUD Obsidian Glass Card.
/// Wrapped in a [RepaintBoundary] to isolate metric updates from map redraws.
class RunHud extends StatefulWidget {
  final bool isRunActive;
  final bool isAutoPaused;
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final String splitPace;
  final double currentSpeedKmh;
  final double satelliteAccuracyMeters;
  final int territoriesClaimed;
  final int stepCount;
  final double? distanceToClosureMeters;
  final double? proximityToClosure;
  final String? targetPace;
  final RunGoal? runGoal;
  final double currentAreaSqm;
  final VoidCallback? onOpenGoalSelector;
  final VoidCallback? onToggleAmoledSaver;
  final bool isBatterySaverActive;
  final bool isSearchingGps;
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
    this.stepCount = 0,
    this.distanceToClosureMeters,
    this.proximityToClosure,
    this.targetPace,
    this.runGoal,
    this.currentAreaSqm = 0.0,
    this.onOpenGoalSelector,
    this.onToggleAmoledSaver,
    this.isBatterySaverActive = false,
    this.isSearchingGps = false,
    required this.onToggleRun,
    required this.onSealShape,
    required this.onFinishRun,
  });

  @override
  State<RunHud> createState() => _RunHudState();
}

class _RunHudState extends State<RunHud> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    AppMotion.selectionTick();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double proximity = (widget.proximityToClosure ?? 0.0).clamp(0.0, 1.0);
    final bool isNearClosure = proximity >= 0.75;

    return RepaintBoundary(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0.0;
          if (v < -150 && !_isExpanded) {
            _toggleExpanded();
          } else if (v > 150 && _isExpanded) {
            _toggleExpanded();
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s10,
            AppSpacing.s16,
            AppSpacing.s14,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: AppSpacing.br28,
            border: Border.all(
              color: widget.isAutoPaused
                  ? AppColors.warning.withValues(alpha: 0.6)
                  : (isNearClosure ? AppColors.accent : AppColors.borderSubtle),
              width: isNearClosure ? 1.5 : 1.0,
            ),
            boxShadow: AppElevation.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle Indicator Pill
              GestureDetector(
                onTap: _toggleExpanded,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: AppSpacing.brFull,
                      ),
                    ),
                  ),
                ),
              ),

              // Auto-Pause Banner
              if (widget.isAutoPaused && widget.isRunActive) ...[
                Semantics(
                  liveRegion: true,
                  label: 'Run tracking auto-paused. Moving speed dropped below 1.8 kilometers per hour.',
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.16),
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(color: AppColors.warning, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_filled_rounded,
                          color: AppColors.warning,
                          size: 14,
                        ),
                        SizedBox(width: AppSpacing.s6),
                        Text(
                          'Auto-paused • Speed < 1.8 km/h',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Finding GPS Inline Status
              if (widget.isRunActive &&
                  !widget.isAutoPaused &&
                  (widget.satelliteAccuracyMeters > 30.0 ||
                      widget.isSearchingGps)) ...[
                Semantics(
                  liveRegion: true,
                  label: 'Finding GPS satellite signal',
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.accent,
                          ),
                        ),
                        SizedBox(width: AppSpacing.s6),
                        Text(
                          'Finding GPS...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Closure and Goal Bar
              RunHudClosureBar(
                isRunActive: widget.isRunActive,
                distanceKm: widget.distanceKm,
                elapsedSeconds: widget.elapsedSeconds,
                movingSeconds: widget.movingSeconds,
                distanceToClosureMeters: widget.distanceToClosureMeters,
                proximityToClosure: widget.proximityToClosure,
                runGoal: widget.runGoal,
                currentAreaSqm: widget.currentAreaSqm,
                onOpenGoalSelector: widget.onOpenGoalSelector,
              ),

              // Metrics Card
              RunHudMetricsCard(
                isRunActive: widget.isRunActive,
                isAutoPaused: widget.isAutoPaused,
                distanceKm: widget.distanceKm,
                elapsedSeconds: widget.elapsedSeconds,
                movingSeconds: widget.movingSeconds,
                splitPace: widget.splitPace,
                targetPace: widget.targetPace,
                currentSpeedKmh: widget.currentSpeedKmh,
                satelliteAccuracyMeters: widget.satelliteAccuracyMeters,
                stepCount: widget.stepCount,
                territoriesClaimed: widget.territoriesClaimed,
                onToggleExpanded: _toggleExpanded,
              ),

              // Extended Drawer
              RunHudExpandedDrawer(
                isExpanded: _isExpanded,
                distanceKm: widget.distanceKm,
                elapsedSeconds: widget.elapsedSeconds,
                movingSeconds: widget.movingSeconds,
                currentAreaSqm: widget.currentAreaSqm,
              ),

              const SizedBox(height: AppSpacing.s14),

              // Controls Bar
              RunHudControlsBar(
                isRunActive: widget.isRunActive,
                isNearClosure: isNearClosure,
                closureDist: widget.distanceToClosureMeters,
                onToggleRun: widget.onToggleRun,
                onSealShape: widget.onSealShape,
                onFinishRun: widget.onFinishRun,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
