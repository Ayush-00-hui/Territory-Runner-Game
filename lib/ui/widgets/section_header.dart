import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Unified section header with title left, optional action right,
/// strictly aligned on the same typographic baseline, and consistent spacing.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(
      top: AppSpacing.s24,
      bottom: AppSpacing.s12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final Widget? effectiveAction = actionLabel != null && onAction != null
        ? Semantics(
            button: true,
            label: actionLabel!,
            child: GestureDetector(
              onTap: () {
                AppMotion.selectionTick();
                onAction!();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  actionLabel!,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        : trailing;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overline != null) ...[
            Text(
              overline!.toUpperCase(),
              style: AppText.labelSmall.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (effectiveAction != null) ...[
                const SizedBox(width: AppSpacing.s12),
                effectiveAction,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(subtitle!, style: AppText.bodySmall),
          ],
        ],
      ),
    );
  }
}
