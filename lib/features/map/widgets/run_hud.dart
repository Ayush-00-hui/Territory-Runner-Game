import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'hold_to_finish_button.dart';

import '../../../models/run_goal.dart';

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
  bool _isPlayPressed = false;
  bool _isSealPressed = false;

  void _toggleExpanded() {
    AppMotion.selectionTick();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

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
    final isRunActive = widget.isRunActive;
    final isAutoPaused = widget.isAutoPaused;
    final distanceKm = widget.distanceKm;
    final elapsedSeconds = widget.elapsedSeconds;
    final movingSeconds = widget.movingSeconds;
    final splitPace = widget.splitPace;
    final currentSpeedKmh = widget.currentSpeedKmh;
    final satelliteAccuracyMeters = widget.satelliteAccuracyMeters;
    final territoriesClaimed = widget.territoriesClaimed;
    final distanceToClosureMeters = widget.distanceToClosureMeters;
    final proximityToClosure = widget.proximityToClosure;
    final targetPace = widget.targetPace;
    final runGoal = widget.runGoal;
    final currentAreaSqm = widget.currentAreaSqm;
    final onOpenGoalSelector = widget.onOpenGoalSelector;
    final isSearchingGps = widget.isSearchingGps;
    final onToggleRun = widget.onToggleRun;
    final onSealShape = widget.onSealShape;
    final onFinishRun = widget.onFinishRun;

    final double proximity = (proximityToClosure ?? 0.0).clamp(0.0, 1.0);
    final double? closureDist = distanceToClosureMeters;
    final bool isNearClosure = proximity >= 0.75;
    final bool isReducedMotion = AppMotion.shouldReduceMotion(context);

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
              color: isAutoPaused
                  ? AppColors.warning.withValues(alpha: 0.6)
                  : (isNearClosure ? AppColors.accent : AppColors.borderSubtle),
              width: isNearClosure ? 1.5 : 1.0,
            ),
            boxShadow: AppElevation.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle Indicator Pill & Expand Gesture Target
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
              if (isAutoPaused && isRunActive) ...[
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

              // Finding GPS Inline Status (Quiet non-modal status)
              if (isRunActive &&
                  !isAutoPaused &&
                  (satelliteAccuracyMeters > 30.0 || isSearchingGps)) ...[
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

              // Active Campaign Goal Progress Banner
              if (runGoal != null && runGoal.isActive) ...[
                Semantics(
                  button: true,
                  label: 'Run goal: ${runGoal.title}. Tap to configure.',
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
                                        runGoal.title,
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
                                    runGoal.formatRemaining(
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
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
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
                              value: runGoal
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
                    color:
                        (isNearClosure ? AppColors.accent : AppColors.surface2)
                            .withValues(alpha: 0.18),
                    borderRadius: AppSpacing.br12,
                    border: Border.all(
                      color: isNearClosure
                          ? AppColors.accent
                          : AppColors.border,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: isNearClosure
                            ? AppColors.accent
                            : AppColors.info,
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
                                  isNearClosure
                                      ? AppColors.accent
                                      : AppColors.info,
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

              // Core Metric Readouts: Distance | Time | Pace
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance (Tabular Inter)
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
                                isRunActive
                                    ? distanceKm.toStringAsFixed(2)
                                    : '0.00',
                                style: AppText.statHero.copyWith(
                                  fontSize: 32,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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

                  // Moving Time (Tabular)
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
                                ? _formatDuration(
                                    movingSeconds > 0
                                        ? movingSeconds
                                        : elapsedSeconds,
                                  )
                                : '00:00',
                            style: AppText.timer.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pace (Tabular Inter)
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: AppSpacing.br8,
                                ),
                                child: Text(
                                  'P: $targetPace',
                                  style: AppText.labelSmall.copyWith(
                                    color: AppColors.info,
                                    fontSize: 8.5,
                                  ),
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

              const SizedBox(height: AppSpacing.s12),

              // Secondary Telemetry Row (Tap to expand/collapse extended metrics)
              GestureDetector(
                onTap: _toggleExpanded,
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
                              const Icon(
                                Icons.speed_rounded,
                                color: AppColors.info,
                                size: 14,
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                '${currentSpeedKmh.toStringAsFixed(1)} km/h',
                                style: AppText.bodyBold.copyWith(
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: AppColors.rival,
                                size: 14,
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                '+${(distanceKm * 65.0).round()} kcal',
                                style: AppText.bodyBold.copyWith(
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
                                    : (satelliteAccuracyMeters <= 30.0
                                          ? AppColors.warning
                                          : AppColors.rival),
                                size: 14,
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                satelliteAccuracyMeters > 50.0
                                    ? 'GPS LOST'
                                    : '±${satelliteAccuracyMeters.toStringAsFixed(0)}m',
                                style: AppText.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: satelliteAccuracyMeters <= 10.0
                                      ? AppColors.textSecondary
                                      : (satelliteAccuracyMeters <= 30.0
                                            ? AppColors.warning
                                            : AppColors.rival),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                color: AppColors.accent,
                                size: 14,
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                '$territoriesClaimed territories',
                                style: AppText.bodyBold.copyWith(
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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

              // Extended Telemetry Section (Revealed via swipe-up or tap)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s10),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppSpacing.br14,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Avg pace',
                                      style: AppText.labelSmall,
                                    ),
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
                        ),
                      )
                    : const SizedBox.shrink(),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppMotion.duration(context, AppMotion.standard),
              ),

              const SizedBox(height: AppSpacing.s14),

              // Bottom Action Controls: Seal Shape | Giant Action Play/Pause | Accidental-Tap Protected Hold-To-Finish
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left "SEAL SHAPE" manual trigger
                  Flexible(
                    child: Semantics(
                      button: true,
                      label: 'Seal territory shape',
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _isSealPressed = true),
                        onTapUp: (_) => setState(() => _isSealPressed = false),
                        onTapCancel: () =>
                            setState(() => _isSealPressed = false),
                        onTap: () {
                          AppMotion.mediumTick();
                          onSealShape();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedScale(
                          scale: (_isSealPressed && !isReducedMotion)
                              ? 0.96
                              : 1.0,
                          duration: AppMotion.fast,
                          curve: AppMotion.easeOut,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s10,
                              vertical: AppSpacing.s12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppSpacing.br16,
                              border: Border.all(
                                color: isNearClosure
                                    ? AppColors.accent
                                    : AppColors.borderSubtle,
                                width: isNearClosure ? 1.5 : 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  color: isNearClosure
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: AppSpacing.s4),
                                const Flexible(
                                  child: Text(
                                    'Close loop',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.s8),

                  // Center Confident Matte Play/Pause Action Button
                  Semantics(
                    button: true,
                    label: isRunActive
                        ? 'Pause run tracking'
                        : 'Start run tracking',
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _isPlayPressed = true),
                      onTapUp: (_) => setState(() => _isPlayPressed = false),
                      onTapCancel: () => setState(() => _isPlayPressed = false),
                      onTap: () {
                        AppMotion.heavyBurst();
                        onToggleRun();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedScale(
                        scale: (_isPlayPressed && !isReducedMotion)
                            ? 0.94
                            : 1.0,
                        duration: AppMotion.fast,
                        curve: AppMotion.easeOut,
                        child: Container(
                          height: 58,
                          width: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                          child: Center(
                            child: Icon(
                              isRunActive
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.onAccent,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.s8),

                  // Right Accidental-Tap Protected Hold-To-Finish Button
                  Flexible(
                    child: HoldToFinishButton(
                      isRunActive: isRunActive,
                      onFinish: onFinishRun,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
