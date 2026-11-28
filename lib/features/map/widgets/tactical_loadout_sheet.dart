import 'package:flutter/material.dart';

import '../../../models/tactical_perk.dart';
import '../../../services/tactical_loadout_service.dart';
import '../../../ui/ui.dart';

/// Modal sheet for selecting and equipping pre-run runner perk loadouts.
class TacticalLoadoutSheet extends StatefulWidget {
  const TacticalLoadoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TacticalLoadoutSheet(),
    );
  }

  @override
  State<TacticalLoadoutSheet> createState() => _TacticalLoadoutSheetState();
}

class _TacticalLoadoutSheetState extends State<TacticalLoadoutSheet> {
  final TacticalLoadoutService _loadoutService = TacticalLoadoutService();

  @override
  Widget build(BuildContext context) {
    final perks = _loadoutService.availablePerks;
    final equippedCount = _loadoutService.equippedPerks.length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: AppColors.accent,
                      size: 22.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    'RUNNER LOADOUT',
                    style: AppText.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  '$equippedCount/2 EQUIPPED',
                  style: AppText.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            'Equip up to 2 active runner perks to deploy during your upcoming run session.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16.0),
          ...perks.map((perk) {
            final isEquipped = perk.isEquipped;
            final cardColor = isEquipped
                ? AppColors.accent
                : AppColors.textMuted;

            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: isEquipped ? cardColor : AppColors.borderSubtle,
                  width: isEquipped ? 1.5 : 1.0,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                leading: Icon(
                  _getPerkIcon(perk.type),
                  color: cardColor,
                  size: 26.0,
                ),
                title: Text(
                  perk.title,
                  style: AppText.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  perk.description,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: Switch(
                  value: isEquipped,
                  activeColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      _loadoutService.toggleEquip(perk.type);
                    });
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 12.0),
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
                'CONFIRM LOADOUT',
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

  IconData _getPerkIcon(TacticalPerkType type) {
    switch (type) {
      case TacticalPerkType.sonarPulse:
        return Icons.radar_rounded;
      case TacticalPerkType.aegisShield:
        return Icons.security_rounded;
      case TacticalPerkType.overdrive:
        return Icons.speed_rounded;
      case TacticalPerkType.trailMagnet:
        return Icons.all_inclusive_rounded;
    }
  }
}
