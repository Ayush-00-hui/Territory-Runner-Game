import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Design System: Standard circular icon button.
/// Enforces minimum 48x48 dp touch target, 40-44 dp visual surface,
/// 0.97 press-scale micro-animation, and purposeful athletic haptic response.
class AppIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? semanticLabel;
  final double visualSize;
  final double hitTargetSize;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isGlass;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.semanticLabel,
    this.visualSize = 44.0,
    this.hitTargetSize = 48.0,
    this.iconSize = 22.0,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.isGlass = true,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    AppMotion.selectionTick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = AppMotion.shouldReduceMotion(context);
    final isEnabled = widget.onTap != null;

    final bgColor = widget.backgroundColor ??
        (widget.isGlass ? AppColors.surfaceGlass : AppColors.surface);
    final iconColor = widget.iconColor ??
        (isEnabled ? AppColors.textPrimary : AppColors.disabled);
    final borderColor = widget.borderColor ?? AppColors.borderSubtle;

    final visualWidget = AnimatedScale(
      scale: (_isPressed && !isReducedMotion && isEnabled) ? 0.97 : 1.0,
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.easeOut,
        width: widget.visualSize,
        height: widget.visualSize,
        decoration: BoxDecoration(
          color: _isPressed ? AppColors.surface2 : bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isPressed ? AppColors.accent : borderColor,
            width: 1.0,
          ),
          boxShadow: AppElevation.floating,
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: iconColor,
          ),
        ),
      ),
    );

    Widget hitTarget = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isEnabled ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          minWidth: widget.hitTargetSize,
          minHeight: widget.hitTargetSize,
        ),
        alignment: Alignment.center,
        child: visualWidget,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      hitTarget = Tooltip(
        message: widget.tooltip!,
        child: hitTarget,
      );
    }

    final semanticText = widget.semanticLabel ?? widget.tooltip;
    if (semanticText != null && semanticText.isNotEmpty) {
      hitTarget = Semantics(
        button: true,
        enabled: isEnabled,
        label: semanticText,
        child: hitTarget,
      );
    }

    return hitTarget;
  }
}
