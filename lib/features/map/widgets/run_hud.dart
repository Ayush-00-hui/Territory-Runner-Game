import 'package:flutter/material.dart';

import '../../../models/run_goal.dart';
import '../../../services/ghost_runner_service.dart';
import '../../../services/interval_workout_service.dart';
import '../../../ui/ui.dart';
import 'interval_workout_banner.dart';
import 'run_hud_closure_bar.dart';
import 'run_hud_controls_bar.dart';
import 'run_hud_expanded_drawer.dart';
import 'run_hud_metrics_card.dart';

/// Strava / Nike Run Club Grade Live Metrics HUD Obsidian Glass Card.
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
  final int? stepCount;
  final bool isStepCountEstimated;
  final double grade;
  final double elevationGainMeters;
  final double cadenceSpm;
  final double? strideLengthMeters;
  final double? distanceToClosureMeters;
  final double? proximityToClosure;
  final String? targetPace;
  final RunGoal? runGoal;
  final double currentAreaSqm;
  final VoidCallback? onOpenGoalSelector;
  final VoidCallback? onToggleAmoledSaver;
  final bool isBatterySaverActive;
  final bool isSearchingGps;
  final ValueNotifier<GhostTelemetry?>? ghostTelemetryNotifier;
  final ValueNotifier<IntervalWorkoutSnapshot?>? workoutSnapshotNotifier;
  final VoidCallback? onSkipWorkoutPhase;
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
    this.stepCount,
    this.isStepCountEstimated = true,
    this.grade = 0.0,
    this.elevationGainMeters = 0.0,
    this.cadenceSpm = 0.0,
    this.strideLengthMeters,
    this.distanceToClosureMeters,
    this.proximityToClosure,
    this.targetPace,
    this.runGoal,
    this.currentAreaSqm = 0.0,
    this.onOpenGoalSelector,
    this.onToggleAmoledSaver,
    this.isBatterySaverActive = false,
    this.isSearchingGps = false,
    this.ghostTelemetryNotifier,
    this.workoutSnapshotNotifier,
    this.onSkipWorkoutPhase,
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
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
            color: palette.surfaceGlass,
            borderRadius: AppSpacing.br28,
            border: Border.all(
              color: widget.isAutoPaused
                  ? palette.warning.withValues(alpha: 0.6)
                  : (isNearClosure ? palette.accent : palette.borderSubtle),
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
                        color: palette.borderSubtle,
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
                  label: 'Run tracking auto-paused. Moving speed dropped below 2.5 kilometers per hour.',
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.warning.withValues(alpha: 0.16),
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(color: palette.warning, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_filled_rounded,
                          color: palette.warning,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Text(
                          'Auto-paused • Speed < 2.5 km/h',
                          style: TextStyle(
                            color: palette.warning,
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
                      color: palette.surface2,
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(color: palette.borderSubtle, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Text(
                          'Finding GPS...',
                          style: TextStyle(
                            color: palette.textSecondary,
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

              // Ghost Runner Live Pacing Chip
              if (widget.isRunActive &&
                  widget.ghostTelemetryNotifier != null) ...[
                ValueListenableBuilder<GhostTelemetry?>(
                  valueListenable: widget.ghostTelemetryNotifier!,
                  builder: (context, ghost, _) {
                    if (ghost == null) return const SizedBox.shrink();
                    return _GhostHudChip(telemetry: ghost);
                  },
                ),
              ],

              // Workout Interval Banner
              if (widget.isRunActive &&
                  widget.workoutSnapshotNotifier != null) ...[
                ValueListenableBuilder<IntervalWorkoutSnapshot?>(
                  valueListenable: widget.workoutSnapshotNotifier!,
                  builder: (context, workout, _) {
                    if (workout == null) return const SizedBox.shrink();
                    return IntervalWorkoutBanner(
                      snapshot: workout,
                      onSkipPhase: widget.onSkipWorkoutPhase ?? () {},
                    );
                  },
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
                isStepCountEstimated: widget.isStepCountEstimated,
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
                grade: widget.grade,
                elevationGainMeters: widget.elevationGainMeters,
                cadenceSpm: widget.cadenceSpm,
                strideLengthMeters: widget.strideLengthMeters,
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

class _GhostHudChip extends StatelessWidget {
  final GhostTelemetry telemetry;

  const _GhostHudChip({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color tint;
    if (telemetry.isOffRoute) {
      tint = palette.warning;
    } else if (telemetry.isRunnerAhead) {
      tint = palette.accent;
    } else {
      tint = palette.textSecondary;
    }

    final diffText = telemetry.statusText;

    return Semantics(
      liveRegion: true,
      label: 'Ghost runner: $diffText',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s10),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: palette.surface2,
          borderRadius: AppSpacing.brFull,
          border: Border.all(
            color: telemetry.isOffRoute
                ? palette.warning.withValues(alpha: 0.6)
                : palette.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              telemetry.isOffRoute
                  ? Icons.warning_amber_rounded
                  : Icons.directions_run_rounded,
              size: 13,
              color: tint,
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              telemetry.statusText,
              style: TextStyle(
                color: tint,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
