import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../motion/motion.dart';

/// Styled surface card container using design tokens.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Border? border;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.onTap,
    this.backgroundColor = AppColors.surface,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = border ?? AppSpacing.cardBorder;
    final effectiveRadius = borderRadius ?? AppSpacing.br24;
    final effectiveShadow = boxShadow ?? AppSpacing.cardShadow;

    final container = Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveRadius,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          AppMotion.lightTick();
          onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: container,
      );
    }

    return container;
  }
}
