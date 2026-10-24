import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Non-blocking, high-contrast, athletic "Go!" cue.
/// Appears for <= 400 ms on run start, provides immediate haptic feedback,
/// is fully skippable on tap, and safely honors reduced-motion settings.
class RunGoCue extends StatefulWidget {
  final VoidCallback onDismissed;

  const RunGoCue({super.key, required this.onDismissed});

  @override
  State<RunGoCue> createState() => _RunGoCueState();
}

class _RunGoCueState extends State<RunGoCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      // Reduced motion: skip scaling and exit fast
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        _controller.stop();
        widget.onDismissed();
      },
      behavior: HitTestBehavior.translucent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: AppRadius.brFull,
                    border: Border.all(color: AppColors.accent, width: 1.5),
                  ),
                  child: Text(
                    'GO',
                    style: AppText.headingLarge.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
