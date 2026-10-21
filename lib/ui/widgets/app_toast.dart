import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

enum AppToastType { info, success, warning, error }

/// Athletic floating toast pill replacing raw SnackBars.
/// Always pairs color with icon + text for accessibility and clarity.
class AppToast extends StatelessWidget {
  final String message;
  final IconData? icon;
  final AppToastType type;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AppToast({
    super.key,
    required this.message,
    this.icon,
    this.type = AppToastType.info,
    this.onAction,
    this.actionLabel,
  });

  /// Root scaffold messenger key for showing toasts without a BuildContext
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Displays the toast globally via the root ScaffoldMessenger key
  static void showGlobal(
    String message, {
    IconData? icon,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    AppMotion.selectionTick();
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        padding: EdgeInsets.zero,
        duration: duration,
        content: AppToast(
          message: message,
          icon: icon,
          type: type,
          onAction: onAction,
          actionLabel: actionLabel,
        ),
      ),
    );
  }

  /// Displays the toast across the screen via ScaffoldMessenger
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    AppMotion.selectionTick();

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        padding: EdgeInsets.zero,
        duration: duration,
        content: AppToast(
          message: message,
          icon: icon,
          type: type,
          onAction: onAction,
          actionLabel: actionLabel,
        ),
      ),
    );
  }

  Color get _accentColor {
    switch (type) {
      case AppToastType.success:
        return AppColors.success;
      case AppToastType.warning:
        return AppColors.warning;
      case AppToastType.error:
        return AppColors.error;
      case AppToastType.info:
        return AppColors.info;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.warning:
        return Icons.warning_rounded;
      case AppToastType.error:
        return Icons.error_rounded;
      case AppToastType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = icon ?? _defaultIcon;
    final color = _accentColor;

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppRadius.br16,
          border: Border.all(color: AppColors.borderSubtle, width: 1.0),
          boxShadow: AppElevation.floating,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(effectiveIcon, size: 20, color: color),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                message,
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.s8),
              GestureDetector(
                onTap: () {
                  AppMotion.selectionTick();
                  onAction!();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: AppSpacing.s2,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppText.labelLarge.copyWith(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
