import 'package:flutter/material.dart';

import '../../../models/tactical_perk.dart';
import '../../../services/tactical_loadout_service.dart';

/// Modal sheet for selecting and equipping pre-run tactical perk loadouts.
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
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFA3C586).withValues(alpha: 0.8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA3C586).withValues(alpha: 0.25),
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
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA3C586).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFFA3C586),
                      size: 22.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'TACTICAL LOADOUT',
                    style: TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 18.0,
                      fontWeight: FontWeight.w800,
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
                  color: const Color(0xFF1E242C),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  '$equippedCount/2 EQUIPPED',
                  style: const TextStyle(
                    color: Color(0xFFA3C586),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const Text(
            'Equip up to 2 active tactical perks to deploy during your upcoming run session.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
          ),
          const SizedBox(height: 16.0),
          ...perks.map((perk) {
            final isEquipped = perk.isEquipped;
            final cardColor = isEquipped
                ? const Color(0xFFA3C586)
                : const Color(0xFF475569);

            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: isEquipped ? cardColor : const Color(0xFF1E293B),
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
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                  ),
                ),
                subtitle: Text(
                  perk.description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.0,
                  ),
                ),
                trailing: Switch(
                  value: isEquipped,
                  activeColor: const Color(0xFFA3C586),
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
                backgroundColor: const Color(0xFFA3C586),
                foregroundColor: const Color(0xFF0D0F11),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: const Text(
                'CONFIRM LOADOUT',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
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
