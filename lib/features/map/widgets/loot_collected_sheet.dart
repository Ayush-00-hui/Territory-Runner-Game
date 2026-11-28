import 'package:flutter/material.dart';

import '../../../models/loot_crate.dart';
import '../../../ui/ui.dart';

/// Modal bottom sheet celebrating collection of a supply loot crate.
class LootCollectedSheet extends StatelessWidget {
  final LootCrate crate;

  const LootCollectedSheet({super.key, required this.crate});

  static Future<void> show(BuildContext context, LootCrate crate) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LootCollectedSheet(crate: crate),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    IconData icon;

    switch (crate.type) {
      case LootCrateType.shieldBattery:
        themeColor = AppColors.info;
        icon = Icons.shield_rounded;
        break;
      case LootCrateType.overchargeBeacon:
        themeColor = AppColors.gold;
        icon = Icons.bolt_rounded;
        break;
      case LootCrateType.factionShard:
        themeColor = AppColors.accent;
        icon = Icons.diamond_rounded;
        break;
    }

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
          color: themeColor.withValues(alpha: 0.8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.35),
            blurRadius: 24.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeColor.withValues(alpha: 0.15),
              border: Border.all(color: themeColor, width: 2.0),
            ),
            child: Icon(icon, color: themeColor, size: 36.0),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'SUPPLY CRATE SECURED',
            style: AppText.labelSmall.copyWith(
              color: themeColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            crate.title,
            style: AppText.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            crate.description,
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s10,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.gold,
                  size: 18.0,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '+${crate.bonusXp} Team Points Added',
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
              ),
              child: Text(
                'CONTINUE RUN',
                style: AppText.labelLarge.copyWith(
                  color: AppColors.bgDeep,
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
}
