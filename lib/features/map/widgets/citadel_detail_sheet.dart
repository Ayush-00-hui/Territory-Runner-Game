import 'package:flutter/material.dart';

import '../../../models/citadel.dart';
import '../../../ui/ui.dart';

/// Bottom sheet detailing Citadel status, ruling athlete, defense level, and rewards.
class CitadelDetailSheet extends StatelessWidget {
  final Citadel citadel;

  const CitadelDetailSheet({super.key, required this.citadel});

  static Future<void> show(BuildContext context, Citadel citadel) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CitadelDetailSheet(citadel: citadel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApex = citadel.controllingFaction.contains('Apex');
    final factionColor = isApex ? AppColors.accent : AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      margin: const EdgeInsets.only(
        bottom: AppSpacing.s24,
        left: AppSpacing.s16,
        right: AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br24,
        border: Border.all(
          color: factionColor.withValues(alpha: 0.8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: factionColor.withValues(alpha: 0.3),
            blurRadius: 24.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: factionColor.withValues(alpha: 0.15),
                  border: Border.all(color: factionColor, width: 1.5),
                ),
                child: const Icon(
                  Icons.fort_rounded,
                  color: AppColors.textPrimary,
                  size: 28.0,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISTRICT CITADEL BEACON',
                      style: AppText.labelSmall.copyWith(
                        color: factionColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      citadel.name,
                      style: AppText.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'Club / Group',
                  citadel.controllingFaction,
                  factionColor,
                ),
                Container(width: 1.0, height: 32.0, color: AppColors.border),
                _buildMetric(
                  'Current Leader',
                  citadel.rulerAthleteName,
                  AppColors.textPrimary,
                ),
                Container(width: 1.0, height: 32.0, color: AppColors.border),
                _buildMetric(
                  'Defense Tier',
                  'Tier ${citadel.defenseLevel}',
                  AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Encircle this Citadel in your running polygon loop to capture it for your team and claim the District Leader title.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: factionColor,
                foregroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
              ),
              child: Text(
                'DISMISS CITADEL INTEL',
                style: AppText.labelLarge.copyWith(
                  color: AppColors.bgDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.labelSmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: AppText.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
