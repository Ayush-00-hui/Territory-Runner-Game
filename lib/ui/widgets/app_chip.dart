import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Athletic Pill / Chip component for tags, status badges, and selectors.
/// Clean subtle fills, hairline borders, no colored shadows.
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color? customTextColor;
  final EdgeInsetsGeometry padding;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.activeColor = AppColors.accent,
    this.customTextColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s12,
      vertical: AppSpacing.s6,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? activeColor
        : (customTextColor ?? AppColors.textSecondary);

    final bgColor = isSelected ? AppColors.accentContainer : AppColors.surface2;

    final borderColor = isSelected ? activeColor : AppColors.borderSubtle;

    final content = AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.brFull,
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: AppSpacing.s6),
          ],
          Text(
            label,
            style: AppText.labelSmall.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: GestureDetector(
          onTap: () {
            AppMotion.selectionTick();
            onTap!();
          },
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36.0),
            child: Center(widthFactor: 1.0, child: content),
          ),
        ),
      );
    }

    return content;
  }
}
