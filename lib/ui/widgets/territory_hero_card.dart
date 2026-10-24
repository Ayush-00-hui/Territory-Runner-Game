import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'primary_button.dart';
import 'territory_art.dart';
import '../../models/territory.dart';

/// Central Hero Card for Home and Profile screens.
/// Features the TerritoryArt vector canvas, total claimed area readout,
/// weekly delta, and a prominent 56dp primary Start Run action.
class TerritoryHeroCard extends StatelessWidget {
  final List<Territory> territories;
  final double totalAreaSqm;
  final double? weeklyGainedAreaSqm;
  final VoidCallback? onStartRun;
  final bool isRunActive;

  const TerritoryHeroCard({
    super.key,
    required this.territories,
    required this.totalAreaSqm,
    this.weeklyGainedAreaSqm,
    this.onStartRun,
    this.isRunActive = false,
  });

  String _formatArea(double sqm) {
    if (sqm >= 1000000) {
      return (sqm / 1000000.0).toStringAsFixed(2);
    }
    return sqm.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatUnit(double sqm) {
    return sqm >= 1000000 ? 'km²' : 'm²';
  }

  @override
  Widget build(BuildContext context) {
    final hasTerritories = territories.isNotEmpty || totalAreaSqm > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br24,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Territory Art Canvas
          TerritoryArt.fromTerritories(
            territories: territories,
            totalAreaSqm: totalAreaSqm,
            showAreaCountUp: true,
            height: 160,
          ),

          const SizedBox(height: AppSpacing.s16),

          // 2. Metric & Weekly Delta Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL TERRITORY', style: AppText.labelSmall),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatArea(totalAreaSqm),
                        style: AppText.displayMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        _formatUnit(totalAreaSqm),
                        style: AppText.statUnit.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (weeklyGainedAreaSqm != null && weeklyGainedAreaSqm! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppRadius.br8,
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${_formatArea(weeklyGainedAreaSqm!)} ${_formatUnit(weeklyGainedAreaSqm!)} this week',
                        style: AppText.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                )
              else if (!hasTerritories)
                Text(
                  'No territory claimed yet',
                  style: AppText.caption.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),

          // 3. Full-width Primary Action (>= 56 dp touch target)
          PrimaryButton(
            label: isRunActive ? 'Resume current run' : 'Start run',
            icon: isRunActive
                ? Icons.play_arrow_rounded
                : Icons.directions_run_rounded,
            height: 56.0,
            onPressed: onStartRun,
          ),
        ],
      ),
    );
  }
}
