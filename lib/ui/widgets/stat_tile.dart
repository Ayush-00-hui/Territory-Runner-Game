import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Big Athletic Stat Tile with animated count-up and tabular figures.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: AppSpacing.cardBorder,
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppText.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (icon != null)
                Icon(icon, size: 16, color: accentColor.withValues(alpha: 0.8)),
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
                    return Text(displayVal, style: AppText.statLarge);
                  },
                )
              else
                Text(stringValue ?? '', style: AppText.statLarge),
              if (unit != null) ...[
                const SizedBox(width: AppSpacing.s4),
                Text(
                  unit!,
                  style: AppText.labelAccent.copyWith(color: accentColor),
                ),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              delta!,
              style: AppText.bodySmall.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
