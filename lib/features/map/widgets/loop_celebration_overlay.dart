import 'package:flutter/material.dart';
import '../../../ui/ui.dart';

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

  static void show(
    BuildContext context, {
    required double areaSqMeters,
    required int xpAwarded,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => LoopCelebrationOverlay(
        areaSqMeters: areaSqMeters,
        xpAwarded: xpAwarded,
        onDismissed: () {
          entry.remove();
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<LoopCelebrationOverlay> createState() => _LoopCelebrationOverlayState();
}

class _LoopCelebrationOverlayState extends State<LoopCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flashAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _flashAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.04).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn),
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
        ? '${(widget.areaSqMeters / 1000000.0).toStringAsFixed(2)} KM²'
        : '${widget.areaSqMeters.toStringAsFixed(0)} M²';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return IgnorePointer(
          child: Stack(
            children: [
              // 1. Full-screen ember flash gradient
              Opacity(
                opacity: _flashAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.35),
                        AppColors.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Neon Boundary Flash Ring
              Positioned.fill(
                child: Opacity(
                  opacity: _flashAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.6),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Center Celebration Trophy Badge
              Center(
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s24,
                        vertical: AppSpacing.s20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppSpacing.br28,
                        border: Border.all(color: AppColors.accent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Trophy / Flag Icon Capsule
                          Container(
                            height: 64,
                            width: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shield_rounded,
                                color: AppColors.onAccent,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s14),

                          Text(
                            'TERRITORY CONQUERED!',
                            style: AppText.headingLarge.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.s6),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.18),
                                  borderRadius: AppSpacing.br8,
                                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '+$areaDisplay CLAIMED',
                                  style: AppText.label.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: AppSpacing.br8,
                                ),
                                child: Text(
                                  '+${widget.xpAwarded} XP',
                                  style: AppText.label.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
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
            ],
          ),
        );
      },
    );
  }
}
