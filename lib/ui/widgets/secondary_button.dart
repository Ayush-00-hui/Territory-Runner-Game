import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'inline_loading.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';
import 'app_toast.dart';

/// Athletic Secondary Button (Surface tone step + 1px hairline border)
/// 48dp minimum touch target, Semantics, focus, debounced taps,
/// and disabled explanation feedback.
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final String? disabledReason;
  final VoidCallback? onDisabledTap;
  final bool debounce;

  /// Clock provider for deterministic testing of debounce timing
  static DateTime Function() clock = DateTime.now;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = AppSpacing.touchTarget,
    this.disabledReason,
    this.onDisabledTap,
    this.debounce = false,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isPressed = false;
  bool _isFocused = false;
  DateTime? _lastTapTime;
  static const Duration _debounceThreshold = Duration(milliseconds: 400);

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = false);

    if (widget.debounce) {
      final now = SecondaryButton.clock();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < _debounceThreshold) {
        return;
      }
      _lastTapTime = now;
    }

    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = false);
  }

  void _handleDisabledTap() {
    if (widget.onDisabledTap != null) {
      widget.onDisabledTap!();
    } else if (widget.disabledReason != null &&
        widget.disabledReason!.trim().isNotEmpty) {
      AppToast.show(
        context,
        widget.disabledReason!,
        type: AppToastType.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;
    final scale = _isPressed ? AppMotion.pressScale : 1.0;

    final Color bgColor = enabled ? AppColors.surface2 : AppColors.surface;
    final Color fgColor = enabled ? AppColors.textPrimary : AppColors.textMuted;
    final Color borderColor = _isFocused ? AppColors.accent : AppColors.border;

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          InlineLoading(size: 18, strokeWidth: 2.0, color: fgColor),
          const SizedBox(width: AppSpacing.s12),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, color: fgColor, size: 20),
          const SizedBox(width: AppSpacing.s8),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: AppText.button.copyWith(color: fgColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: !enabled && widget.disabledReason != null
          ? widget.disabledReason
          : null,
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
            onTap: !enabled ? _handleDisabledTap : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.easeOut,
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
                minWidth: AppSpacing.touchTarget,
              ),
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
