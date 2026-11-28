import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_toast.dart';
import 'bouncy_tap.dart';
import 'motion.dart';

/// An animated, living flame micro-interaction for athlete streaks.
/// Features subtle organic breathing scale and warm luminous ember glow.
/// Tapping triggers an energetic bounce and an encouraging streak toast.
class StreakFlameWidget extends StatefulWidget {
  final int streakDays;
  final double iconSize;
  final bool showBadge;
  final VoidCallback? onTap;

  const StreakFlameWidget({
    super.key,
    required this.streakDays,
    this.iconSize = 14.0,
    this.showBadge = true,
    this.onTap,
  });

  @override
  State<StreakFlameWidget> createState() => _StreakFlameWidgetState();
}

class _StreakFlameWidgetState extends State<StreakFlameWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flameController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.40).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOutSine),
    );

    // Purposeful athletic entrance breath (single cycle, non-looping for accessibility & tests)
    _flameController.forward().then((_) {
      if (mounted) {
        _flameController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context) {
    _flameController.forward(from: 0.0).then((_) {
      if (mounted) {
        _flameController.reverse();
      }
    });

    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      final days = widget.streakDays;
      final msg = days <= 1
          ? '🔥 Day 1 of your journey! Consistency starts today.'
          : '🔥 $days-day streak! Consistency is your superpower.';
      AppToast.show(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.isReducedMotion(context);

    Widget flameIcon = Icon(
      Icons.local_fire_department_rounded,
      size: widget.iconSize,
      color: AppColors.warning,
    );

    if (!reduced) {
      flameIcon = AnimatedBuilder(
        animation: _flameController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(
                    alpha: _glowAnimation.value,
                  ),
                  blurRadius: widget.iconSize * 0.6,
                  spreadRadius: 1.0,
                ),
              ],
            ),
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: flameIcon,
      );
    }

    if (!widget.showBadge) {
      return BouncyTap(
        onTap: () => _handleTap(context),
        scaleDown: 0.90,
        enableHaptics: true,
        child: flameIcon,
      );
    }

    return BouncyTap(
      onTap: () => _handleTap(context),
      scaleDown: 0.94,
      enableHaptics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppRadius.brFull,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            flameIcon,
            const SizedBox(width: AppSpacing.s4),
            Text(
              '${widget.streakDays}d streak',
              style: AppText.micro.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
