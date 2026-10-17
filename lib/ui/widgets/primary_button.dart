import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Athletic Primary Button with press-scale feedback and haptic tick.
/// Pacer Blue fill `#4C8DFF`, onAccent `#06080C` text, 48dp touch target, Semantics.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;
  final bool isOutlined;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor = AppColors.accent,
    this.foregroundColor = AppColors.onAccent,
    this.height = 48.0,
    this.isOutlined = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
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

    final Color bgColor = widget.isOutlined
        ? Colors.transparent
        : (enabled ? widget.backgroundColor : AppColors.disabled);

    final Color fgColor = enabled
        ? (widget.isOutlined ? widget.backgroundColor : widget.foregroundColor)
        : AppColors.textMuted;

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
          Icon(
            widget.icon,
            color: fgColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
        Text(
          widget.label,
          style: AppText.button.copyWith(color: fgColor),
        ),
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
                border: Border.all(
                  color: _isFocused
                      ? AppColors.textPrimary
                      : (widget.isOutlined ? widget.backgroundColor : Colors.transparent),
                  width: _isFocused ? 1.5 : (widget.isOutlined ? 1.2 : 0.0),
                ),
              ),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
