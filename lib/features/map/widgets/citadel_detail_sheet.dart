import 'package:flutter/material.dart';

import '../../../models/citadel.dart';

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
    final isVanguard = citadel.controllingFaction.contains('Vanguard');
    final factionColor = isVanguard
        ? const Color(0xFFA3C586)
        : const Color(0xFFA855F7);

    return Container(
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(24.0),
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
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: factionColor.withValues(alpha: 0.15),
                  border: Border.all(color: factionColor, width: 1.5),
                ),
                child: const Icon(
                  Icons.fort_rounded,
                  color: Color(0xFFF8FAFC),
                  size: 28.0,
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KING OF THE HILL CITADEL',
                      style: TextStyle(
                        color: factionColor,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      citadel.name,
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 20.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E242C),
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'Controlling Faction',
                  citadel.controllingFaction,
                  factionColor,
                ),
                Container(
                  width: 1.0,
                  height: 32.0,
                  color: const Color(0xFF334155),
                ),
                _buildMetric(
                  'Current Ruler',
                  citadel.rulerAthleteName,
                  const Color(0xFFF8FAFC),
                ),
                Container(
                  width: 1.0,
                  height: 32.0,
                  color: const Color(0xFF334155),
                ),
                _buildMetric(
                  'Defense Tier',
                  'Tier ${citadel.defenseLevel}',
                  const Color(0xFF38BDF8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Encircle this Citadel in your running polygon loop to capture it for your faction and claim the Sector Ruler title.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: factionColor,
                foregroundColor: const Color(0xFF0D0F11),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: const Text(
                'DISMISS CITADEL INTEL',
                style: TextStyle(fontWeight: FontWeight.w800),
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
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
