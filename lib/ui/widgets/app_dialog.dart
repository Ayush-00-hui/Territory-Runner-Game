import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Standard Confirmation Dialog with squircle corners (24dp), hairline border,
/// paired alert icons for destructive actions, and clear primary/secondary CTAs.
class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData? icon;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.icon,
    this.onConfirm,
    this.onCancel,
  });

  /// Displays standard confirmation dialog and returns boolean outcome
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (ctx) => AppDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIcon =
        icon ?? (isDestructive ? Icons.warning_amber_rounded : null);

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br24,
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s24,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (effectiveIcon != null) ...[
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDestructive
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.borderSubtle,
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    effectiveIcon,
                    size: 22,
                    color: isDestructive ? AppColors.error : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
            Text(title, style: AppText.titleLarge),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: cancelLabel,
                    onPressed:
                        onCancel ?? () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: PrimaryButton(
                    label: confirmLabel,
                    backgroundColor: isDestructive
                        ? AppColors.error
                        : AppColors.accent,
                    foregroundColor: isDestructive
                        ? AppColors.textPrimary
                        : AppColors.onAccent,
                    onPressed:
                        onConfirm ?? () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
