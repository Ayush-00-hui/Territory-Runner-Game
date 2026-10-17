import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Big Athletic Stat Tile with animated count-up and tabular figures.
/// Charcoal + Ember style: numbers are the hero, units are smaller and muted.
class StatTile extends StatelessWidget {
  final String label;
  final num? numericValue;
  final String? stringValue;
  final String? unit;
  final String? delta;
  final IconData? icon;
  final Color accentColor;
  final int precision;

  const StatTile({
    super.key,
    required this.label,
    this.numericValue,
    this.stringValue,
    this.unit,
    this.delta,
    this.icon,
    this.accentColor = AppColors.accent,
    this.precision = 0,
  }) : assert(numericValue != null || stringValue != null, 'Provide either numericValue or stringValue');

  @override
  Widget build(BuildContext context) {
    final semanticValue = '${numericValue != null ? numericValue!.toStringAsFixed(precision) : stringValue} ${unit ?? ''}';

    return Semantics(
      container: true,
      label: '$label: $semanticValue',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br16,
          border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppText.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (icon != null)
                  Icon(icon, size: 16, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (numericValue != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: numericValue!.toDouble()),
                    duration: AppMotion.duration(context, AppMotion.countUp),
                    curve: AppMotion.easeOut,
                    builder: (context, val, _) {
                      final String displayVal = precision > 0
                          ? val.toStringAsFixed(precision)
                          : val.round().toString();
                      return Text(displayVal, style: AppText.displaySmall);
                    },
                  )
                else
                  Text(stringValue ?? '', style: AppText.displaySmall),
                if (unit != null) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    unit!,
                    style: AppText.statUnit,
                  ),
                ],
              ],
            ),
            if (delta != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                delta!,
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
