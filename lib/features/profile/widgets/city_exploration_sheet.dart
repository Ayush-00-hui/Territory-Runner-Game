import 'package:flutter/material.dart';

import '../../../services/fog_of_war_service.dart';
import '../../../services/citadel_service.dart';
import '../../../ui/ui.dart';
import '../../gameplay/incursion_service.dart';

/// Modal sheet presenting city exploration statistics, district badges, and Fog of War progress.
class CityExplorationSheet extends StatelessWidget {
  const CityExplorationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const CityExplorationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fog = FogOfWarService();
    final citadels = CitadelService();
    final incursions = IncursionService();

    final pct = fog.urbanExplorationPercentage;
    final areaSqKm = fog.totalExploredAreaSqKm;
    final totalCitadels = citadels.citadels.length;
    final repelled = incursions.repelledIncursionsCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      margin: const EdgeInsets.only(
        bottom: AppSpacing.s24,
        left: AppSpacing.s16,
        right: AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 24.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accent, width: 1.5),
                ),
                child: Icon(
                  Icons.explore_rounded,
                  color: AppColors.accent,
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'METROPOLITAN EXPLORATION',
                      style: AppText.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${pct.toStringAsFixed(1)}% City Unlocked',
                      style: AppText.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0.01, 1.0),
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 8.0,
            ),
          ),
          const SizedBox(height: 20.0),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'Explored Area',
                  '${areaSqKm.toStringAsFixed(2)} km²',
                  AppColors.textPrimary,
                ),
                Container(
                  width: 1.0,
                  height: 32.0,
                  color: AppColors.borderSubtle,
                ),
                _buildStat(
                  'Discovered Citadels',
                  '$totalCitadels POIs',
                  AppColors.gold,
                ),
                Container(
                  width: 1.0,
                  height: 32.0,
                  color: AppColors.borderSubtle,
                ),
                _buildStat(
                  'Incursions Repelled',
                  '$repelled',
                  AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            'Keep discovering unmapped streets to clear the city Fog of War and unlock exclusive territorial discovery badges.',
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: Text(
                'CONTINUE EXPEDITION',
                style: AppText.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: AppText.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
