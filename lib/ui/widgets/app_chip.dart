import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Athletic Pill / Chip component for tags, status badges, and selectors.
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
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? Colors.black
        : (customTextColor ?? AppColors.textSecondary);

    final bgColor = isSelected
        ? activeColor
        : AppColors.surface2;

    final borderColor = isSelected
        ? activeColor
        : AppColors.border;

    final content = AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.brFull,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: isSelected
            ? AppSpacing.neonGlow(activeColor, blur: 10, spread: 0.5)
            : null,
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
            style: AppText.label.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          AppMotion.lightTick();
          onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
