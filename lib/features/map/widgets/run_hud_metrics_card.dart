import 'package:flutter/material.dart';

import '../../../services/app_preferences.dart';
import '../../../ui/ui.dart';

/// Primary Distance, Time, Pace and Secondary Metrics Card for RunHud.
class RunHudMetricsCard extends StatefulWidget {
  final bool isRunActive;
  final bool isAutoPaused;
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final String splitPace;
  final String? targetPace;
  final double currentSpeedKmh;
  final double satelliteAccuracyMeters;
  final int? stepCount;
  final bool isStepCountEstimated;
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
    this.stepCount,
    this.isStepCountEstimated = true,
    required this.territoriesClaimed,
    required this.onToggleExpanded,
  });

  @override
  State<RunHudMetricsCard> createState() => _RunHudMetricsCardState();
}

class _RunHudMetricsCardState extends State<RunHudMetricsCard> {
  int _cachedCalories = 0;
  int _lastCalculatedSec = -1;

  int _getThrottledCalories() {
    final effectiveSec = widget.movingSeconds > 0
        ? widget.movingSeconds
        : widget.elapsedSeconds;
    // Update every 5 seconds, when not yet calculated, or when run is not active
    if (_lastCalculatedSec < 0 ||
        (effectiveSec - _lastCalculatedSec).abs() >= 5 ||
        !widget.isRunActive) {
      _lastCalculatedSec = effectiveSec;
      _cachedCalories = AppPreferences().estimateCalories(
        distanceKm: widget.distanceKm,
        durationMinutes: widget.movingSeconds > 0
            ? widget.movingSeconds / 60.0
            : (widget.elapsedSeconds > 0 ? widget.elapsedSeconds / 60.0 : null),
        speedKmh: widget.currentSpeedKmh > 0 ? widget.currentSpeedKmh : null,
      );
    }
    return _cachedCalories;
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

  String _formatSteps(int steps) {
    final str = steps.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return str.replaceAll(reg, ',');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLight = palette.isLight;

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
                  Text(
                    'Distance',
                    style: AppText.labelSmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.isRunActive
                              ? widget.distanceKm.toStringAsFixed(2)
                              : '0.00',
                          style: AppText.statHero.copyWith(
                            fontSize: isLight ? 36 : 34,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          'km',
                          style: AppText.labelAccent.copyWith(
                            color: palette.accent,
                            fontWeight: isLight
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
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
                      Text(
                        'Time',
                        style: AppText.labelSmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      if (widget.isRunActive && !widget.isAutoPaused) ...[
                        const SizedBox(width: AppSpacing.s4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isRunActive
                          ? _formatDuration(
                              widget.movingSeconds > 0
                                  ? widget.movingSeconds
                                  : widget.elapsedSeconds,
                            )
                          : '00:00',
                      style: AppText.timer.copyWith(
                        fontSize: isLight ? 34 : 32,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
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
                      Text(
                        'Pace',
                        style: AppText.labelSmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      if (widget.targetPace != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface2,
                            borderRadius: AppSpacing.br8,
                          ),
                          child: Text(
                            'P: ${widget.targetPace}',
                            style: AppText.labelSmall.copyWith(
                              color: palette.info,
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
                      widget.isRunActive ? widget.splitPace : "--'--\"",
                      style: AppText.statHero.copyWith(
                        fontSize: isLight ? 30 : 28,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
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

        // Secondary Metrics Row (Tap to expand/collapse extended metrics)
        GestureDetector(
          onTap: widget.onToggleExpanded,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s10,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: palette.surface2,
              borderRadius: AppSpacing.br14,
              border: Border.all(color: palette.borderSubtle),
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
                        Icon(
                          Icons.speed_rounded,
                          color: palette.info,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '${widget.currentSpeedKmh.toStringAsFixed(1)} km/h',
                          style: AppText.bodyBold.copyWith(
                            color: palette.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                          Icons.local_fire_department_rounded,
                          color: palette.rival,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          AppPreferences().formatCalories(
                            _getThrottledCalories(),
                          ),
                          style: AppText.bodyBold.copyWith(
                            color: palette.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                          color: widget.satelliteAccuracyMeters <= 10.0
                              ? palette.accent
                              : (widget.satelliteAccuracyMeters <= 30.0
                                    ? palette.warning
                                    : palette.rival),
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          widget.satelliteAccuracyMeters > 50.0
                              ? 'No GPS'
                              : '±${widget.satelliteAccuracyMeters.toStringAsFixed(0)}m',
                          style: AppText.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.satelliteAccuracyMeters <= 10.0
                                ? palette.textSecondary
                                : (widget.satelliteAccuracyMeters <= 30.0
                                      ? palette.warning
                                      : palette.rival),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.stepCount != null) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Semantics(
                        label: widget.isStepCountEstimated
                            ? 'estimated'
                            : 'measured',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_walk_rounded,
                              color: palette.accent,
                              size: 14,
                            ),
                            const SizedBox(width: AppSpacing.s4),
                            Text(
                              widget.isStepCountEstimated
                                  ? '~${_formatSteps(widget.stepCount!)} steps (est.)'
                                  : '${_formatSteps(widget.stepCount!)} steps',
                              style: AppText.bodyBold.copyWith(
                                color: palette.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: palette.accent,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          '${widget.territoriesClaimed} claimed',
                          style: AppText.bodyBold.copyWith(
                            color: palette.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
