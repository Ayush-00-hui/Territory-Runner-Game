import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Athletic Primary Button with press-scale feedback and haptic tick.
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
    this.foregroundColor = Colors.black,
    this.height = 52.0,
    this.isOutlined = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    AppMotion.lightTick();
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
    final scale = _isPressed ? 0.96 : 1.0;

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isOutlined ? widget.backgroundColor : widget.foregroundColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
        ] else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            color: widget.isOutlined ? widget.backgroundColor : widget.foregroundColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
        Text(
          widget.label.toUpperCase(),
          style: AppText.button.copyWith(
            color: widget.isOutlined ? widget.backgroundColor : widget.foregroundColor,
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: scale,
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      child: GestureDetector(
        onTapDown: enabled ? _handleTapDown : null,
        onTapUp: enabled ? _handleTapUp : null,
        onTapCancel: enabled ? _handleTapCancel : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          decoration: BoxDecoration(
            color: widget.isOutlined
                ? Colors.transparent
                : (enabled ? widget.backgroundColor : widget.backgroundColor.withValues(alpha: 0.4)),
            borderRadius: AppSpacing.br16,
            border: widget.isOutlined
                ? Border.all(color: widget.backgroundColor, width: 1.5)
                : null,
            boxShadow: (!widget.isOutlined && enabled)
                ? AppSpacing.neonGlow(widget.backgroundColor, blur: 14, spread: 0.5)
                : null,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}
