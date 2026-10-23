import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'secondary_button.dart';

/// Standard Error State widget pairing Rose error icon + message + Retry action.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    this.title = 'Unable to load stats',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s32,
          vertical: AppSpacing.s40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 28,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s20),
              SecondaryButton(
                label: retryLabel,
                onPressed: onRetry,
                isFullWidth: false,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
