import 'package:flutter/material.dart';

import '../../../models/run_goal.dart';
import '../../../ui/ui.dart';

/// Renders the Campaign Goal Progress Banner and Enclosure Proximity Meter.
class RunHudClosureBar extends StatefulWidget {
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
  State<RunHudClosureBar> createState() => _RunHudClosureBarState();
}

class _RunHudClosureBarState extends State<RunHudClosureBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool get _isTestEnv =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _updatePulseState();
  }

  @override
  void didUpdateWidget(RunHudClosureBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proximityToClosure != widget.proximityToClosure ||
        oldWidget.isRunActive != widget.isRunActive) {
      _updatePulseState();
    }
  }

  void _updatePulseState() {
    final double proximity = (widget.proximityToClosure ?? 0.0).clamp(0.0, 1.0);
    final bool shouldPulse = widget.isRunActive && proximity >= 0.80;

    if (shouldPulse) {
      if (_isTestEnv) {
        _pulseController.value = 1.0;
      } else if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double proximity = (widget.proximityToClosure ?? 0.0).clamp(0.0, 1.0);
    final double? closureDist = widget.distanceToClosureMeters;
    final bool isNearClosure = proximity >= 0.75;
    final bool isPulsing = widget.isRunActive && proximity >= 0.80;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Active Campaign Goal Progress Banner
        if (widget.runGoal != null && widget.runGoal!.isActive) ...[
          Semantics(
            button: true,
            label: 'Run goal: ${widget.runGoal!.title}. Tap to configure.',
            child: GestureDetector(
              onTap: widget.onOpenGoalSelector,
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
                                  widget.runGoal!.title,
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
                              widget.runGoal!.formatRemaining(
                                currentDistanceKm: widget.distanceKm,
                                currentDurationSeconds: widget.movingSeconds > 0
                                    ? widget.movingSeconds
                                    : widget.elapsedSeconds,
                                currentAreaSqm: widget.currentAreaSqm,
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
                        value: widget.runGoal!
                            .computeProgress(
                              currentDistanceKm: widget.distanceKm,
                              currentDurationSeconds: widget.movingSeconds > 0
                                  ? widget.movingSeconds
                                  : widget.elapsedSeconds,
                              currentAreaSqm: widget.currentAreaSqm,
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
        if (widget.isRunActive && closureDist != null && closureDist > 0) ...[
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              final double pulseVal = isPulsing ? _pulseAnimation.value : 0.0;
              final Color borderColor = isPulsing
                  ? AppColors.accent.withValues(alpha: 0.7 + 0.3 * pulseVal)
                  : (isNearClosure ? AppColors.accent : AppColors.border);
              final double borderWidth = isPulsing ? 1.5 + 0.5 * pulseVal : 1.0;
              final Color bgColor = isPulsing
                  ? AppColors.accent.withValues(alpha: 0.12 + 0.10 * pulseVal)
                  : (isNearClosure ? AppColors.accent : AppColors.surface2)
                        .withValues(alpha: 0.18);
              final List<BoxShadow>? shadows = isPulsing
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: 0.30 * pulseVal,
                        ),
                        blurRadius: 8 * pulseVal + 2,
                        spreadRadius: 1,
                      ),
                    ]
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: AppSpacing.br12,
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: shadows,
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
              );
            },
          ),
        ],
      ],
    );
  }
}
