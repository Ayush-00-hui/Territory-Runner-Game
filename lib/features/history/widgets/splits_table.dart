import 'package:flutter/material.dart';

import '../../../services/app_preferences.dart';
import '../../../services/elevation_splits_service.dart';
import '../../../ui/ui.dart';

/// Real splits table displaying per-km or per-mile statistics:
/// pace, elevation change, average grade, and highlighted best split.
class SplitsTable extends StatelessWidget {
  final List<RunSplit> splits;
  final DistanceUnit unit;

  const SplitsTable({super.key, required this.splits, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return const SizedBox.shrink();
    }

    final unitLabel = unit == DistanceUnit.imperial ? 'MI' : 'KM';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            color: AppColors.surface2,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    unitLabel,
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Pace',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Elev',
                    textAlign: TextAlign.right,
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Grade',
                    textAlign: TextAlign.right,
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Splits Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: splits.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.borderSubtle),
            itemBuilder: (context, index) {
              final split = splits[index];
              return _buildSplitRow(split);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSplitRow(RunSplit split) {
    final distLabel = split.isPartial
        ? '${split.index} (${split.displayDistance.toStringAsFixed(2)})'
        : '${split.index}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      color: split.isBest
          ? AppColors.accentContainer.withValues(alpha: 0.15)
          : null,
      child: Row(
        children: [
          // Split Index / Partial distance
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                distLabel,
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),

          // Pace + Best Pill
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    split.formattedPace,
                    style: AppText.bodyMedium.copyWith(
                      color: split.isBest
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (split.isBest) ...[
                    const SizedBox(width: AppSpacing.s4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentContainer,
                        borderRadius: AppSpacing.br8,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'BEST',
                        style: AppText.labelSmall.copyWith(
                          color: AppColors.accent,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),

          // Elevation Change
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                split.formattedElevationChange,
                textAlign: TextAlign.right,
                style: AppText.bodySmall.copyWith(
                  color: split.elevationChangeMeters > 0
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),

          // Grade
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                split.formattedGrade,
                textAlign: TextAlign.right,
                style: AppText.bodySmall.copyWith(
                  color: split.averageGrade > 0
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
