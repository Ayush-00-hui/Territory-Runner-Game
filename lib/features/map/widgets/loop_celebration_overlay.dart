import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Joyful, memorable loop-closure celebration banner.
/// A spring-scale pill (+1,250 m² claimed) with expanding sonar shockwave
/// and sparkling micro-starburst particles that fades out gracefully.
class LoopCelebrationOverlay extends StatefulWidget {
  final double areaSqMeters;
  final int xpAwarded;
  final VoidCallback onDismissed;

  const LoopCelebrationOverlay({
    super.key,
    required this.areaSqMeters,
    required this.xpAwarded,
    required this.onDismissed,
  });

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required double areaSqMeters,
    required int xpAwarded,
  }) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => LoopCelebrationOverlay(
        areaSqMeters: areaSqMeters,
        xpAwarded: xpAwarded,
        onDismissed: () {
          if (_activeEntry == entry) {
            entry.remove();
            _activeEntry = null;
          }
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  @override
  State<LoopCelebrationOverlay> createState() => _LoopCelebrationOverlayState();
}

class _LoopCelebrationOverlayState extends State<LoopCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.capture);

    AppMotion.heavyBurst();

    _scaleAnimation = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areaDisplay = widget.areaSqMeters >= 10000
        ? '${(widget.areaSqMeters / 1000000.0).toStringAsFixed(2)} km²'
        : '${widget.areaSqMeters.toStringAsFixed(0)} m²';
    final reducedMotion = AppMotion.isReducedMotion(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = reducedMotion ? 1.0 : _scaleAnimation.value;
        final opacity = _opacityAnimation.value;

        return IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: CelebrationBurst(
                      primaryColor: AppColors.accent,
                      secondaryColor: AppColors.gold,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.brFull,
                          border: Border.all(
                            color: AppColors.accent,
                            width: 1.2,
                          ),
                          boxShadow: [
                            ...AppElevation.floating,
                            BoxShadow(
                              color: AppColors.accent.withValues(
                                alpha: 0.25 * opacity,
                              ),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              color: AppColors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              '+$areaDisplay claimed',
                              style: AppText.bodyBold.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (widget.xpAwarded > 0) ...[
                              const SizedBox(width: AppSpacing.s8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentContainer,
                                  borderRadius: AppRadius.br8,
                                ),
                                child: Text(
                                  '+${widget.xpAwarded} XP',
                                  style: AppText.labelSmall.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
