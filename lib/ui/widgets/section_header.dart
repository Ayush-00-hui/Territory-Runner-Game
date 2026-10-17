import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Clean sports section header with title, optional overline/subtitle, and trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && actionLabel != null && onAction != null) {
      effectiveTrailing = TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          foregroundColor: AppColors.accent,
        ),
        onPressed: onAction,
        child: Text(
          actionLabel!,
          style: AppText.labelLarge.copyWith(color: AppColors.accent),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (overline != null) ...[
                  Text(
                    overline!.toUpperCase(),
                    style: AppText.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                ],
                Text(
                  title,
                  style: AppText.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle!,
                    style: AppText.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          ?effectiveTrailing,
        ],
      ),
    );
  }
}
