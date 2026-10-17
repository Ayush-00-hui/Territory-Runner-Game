import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'primary_button.dart';

/// Designed Empty State for missing or zero-data screens.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32, vertical: AppSpacing.s40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: Center(
                child: Icon(icon, size: 28, color: iconColor),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s24),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
                icon: Icons.play_arrow_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
