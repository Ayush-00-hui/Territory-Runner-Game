import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Athletic Secondary Button (Surface tone step + 1px hairline border)
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48.0,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isPressed = false;
  bool _isFocused = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    AppMotion.selectionTick();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;
    final scale = _isPressed ? AppMotion.pressScale : 1.0;

    final Color bgColor = enabled ? AppColors.surface2 : AppColors.surface;
    final Color fgColor = enabled ? AppColors.textPrimary : AppColors.textMuted;
    final Color borderColor = _isFocused
        ? AppColors.accent
        : AppColors.borderSubtle;

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, color: fgColor, size: 20),
          const SizedBox(width: AppSpacing.s8),
        ],
        Text(widget.label, style: AppText.button.copyWith(color: fgColor)),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          child: GestureDetector(
            onTapDown: enabled ? _handleTapDown : null,
            onTapUp: enabled ? _handleTapUp : null,
            onTapCancel: enabled ? _handleTapCancel : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.easeOut,
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: AppRadius.br12,
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
