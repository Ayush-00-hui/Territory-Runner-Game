import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../motion/motion.dart';

/// Styled surface card container using Ink + Pacer Blue design tokens.
/// Depth is created via surface tone steps + 1px hairline borders (borderSubtle).
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    AppMotion.selectionTick();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = widget.border ??
        Border.all(color: AppColors.borderSubtle, width: 1.0);
    final effectiveRadius = widget.borderRadius ?? AppRadius.br16;
    final scale = (widget.onTap != null && _isPressed) ? AppMotion.pressScale : 1.0;

    final container = AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      padding: widget.padding,
      clipBehavior: widget.clipBehavior,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: effectiveRadius,
        border: effectiveBorder,
        boxShadow: widget.boxShadow,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return AnimatedScale(
        scale: scale,
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.easeOut,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: container,
        ),
      );
    }

    return container;
  }
}
