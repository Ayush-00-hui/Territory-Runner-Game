import 'package:flutter/material.dart';
import '../../../models/loot_crate.dart';

/// Modal bottom sheet celebrating collection of a tactical loot crate.
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
        themeColor = const Color(0xFF38BDF8);
        icon = Icons.shield_rounded;
        break;
      case LootCrateType.overchargeBeacon:
        themeColor = const Color(0xFFFBBF24);
        icon = Icons.bolt_rounded;
        break;
      case LootCrateType.factionShard:
        themeColor = const Color(0xFFA855F7);
        icon = Icons.diamond_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: themeColor.withValues(alpha: 0.8), width: 1.8),
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
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeColor.withValues(alpha: 0.15),
              border: Border.all(color: themeColor, width: 2.0),
            ),
            child: Icon(icon, color: themeColor, size: 36.0),
          ),
          const SizedBox(height: 16.0),
          Text(
            'TACTICAL CRATE SECURED',
            style: TextStyle(
              color: themeColor,
              fontSize: 12.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            crate.title,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 22.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            crate.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 20.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E242C),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18.0),
                const SizedBox(width: 8.0),
                Text(
                  '+${crate.bonusXp} Faction XP Added',
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: const Color(0xFF0D0F11),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: const Text(
                'CONTINUE RUN',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
