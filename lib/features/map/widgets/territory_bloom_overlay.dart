import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Celebratory capture event payload.
class TerritoryCaptureCelebration {
  final int xpEarned;
  final double netAreaSqM;
  final String timestamp;

  const TerritoryCaptureCelebration({
    required this.xpEarned,
    required this.netAreaSqM,
    required this.timestamp,
  });
}

/// High-impact animated Bloom & Shockwave celebration overlay.
/// Triggers when an athlete closes a GPS loop and claims land.
class TerritoryBloomOverlay extends StatefulWidget {
  final TerritoryCaptureCelebration? celebration;
  final VoidCallback onDismissed;

  const TerritoryBloomOverlay({
    super.key,
    required this.celebration,
    required this.onDismissed,
  });

  @override
  State<TerritoryBloomOverlay> createState() => _TerritoryBloomOverlayState();
}

class _TerritoryBloomOverlayState extends State<TerritoryBloomOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.3,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 35),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_animController);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_animController);

    _slideAnimation = Tween<double>(begin: 30.0, end: -40.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed();
      }
    });

    if (widget.celebration != null) {
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(TerritoryBloomOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebration != null &&
        widget.celebration != oldWidget.celebration) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.celebration == null) return const SizedBox.shrink();

    final celebration = widget.celebration!;
    final areaFormatted = celebration.netAreaSqM >= 10000.0
        ? '${(celebration.netAreaSqM / 10000.0).toStringAsFixed(2)} ha'
        : '${celebration.netAreaSqM.round()} m²';

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final shockwaveProgress = math.min(
              1.0,
              _animController.value * 2.2,
            );
            final shockwaveRadius = 60.0 + (shockwaveProgress * 180.0);
            final shockwaveAlpha = (1.0 - shockwaveProgress).clamp(0.0, 0.45);

            return Stack(
              alignment: Alignment.center,
              children: [
                // Expanding Radial Shockwave Ring
                if (shockwaveProgress < 1.0)
                  Container(
                    width: shockwaveRadius * 2,
                    height: shockwaveRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(
                          alpha: shockwaveAlpha,
                        ),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: shockwaveAlpha * 0.4,
                          ),
                          blurRadius: 20.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                  ),

                // Floating Hero Celebration Banner
                Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s20,
                          vertical: AppSpacing.s14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.8),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.30),
                              blurRadius: 24.0,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.s6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.accent,
                                    size: 22.0,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s10),
                                Text(
                                  'TERRITORY CLAIMED',
                                  style: AppText.labelLarge.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              '+${celebration.xpEarned} XP • $areaFormatted',
                              style: AppText.headlineSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              'Loop secured on foot',
                              style: AppText.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
