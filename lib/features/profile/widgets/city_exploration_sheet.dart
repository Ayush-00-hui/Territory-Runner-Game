import 'package:flutter/material.dart';

import '../../../services/fog_of_war_service.dart';
import '../../../services/citadel_service.dart';
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
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
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
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF38BDF8),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Color(0xFF38BDF8),
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'METROPOLITAN EXPLORATION',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${pct.toStringAsFixed(1)}% City Unlocked',
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
          const SizedBox(height: 16.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0.01, 1.0),
              backgroundColor: const Color(0xFF1E242C),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF38BDF8),
              ),
              minHeight: 8.0,
            ),
          ),
          const SizedBox(height: 20.0),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'Explored Area',
                  '${areaSqKm.toStringAsFixed(2)} km²',
                  const Color(0xFFF8FAFC),
                ),
                Container(
                  width: 1.0,
                  height: 32.0,
                  color: const Color(0xFF334155),
                ),
                _buildStat(
                  'Discovered Citadels',
                  '$totalCitadels POIs',
                  const Color(0xFFFBBF24),
                ),
                Container(
                  width: 1.0,
                  height: 32.0,
                  color: const Color(0xFF334155),
                ),
                _buildStat(
                  'Incursions Repelled',
                  '$repelled',
                  const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Keep discovering unmapped streets to clear the city Fog of War and unlock exclusive territorial discovery badges.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0D0F11),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: const Text(
                'CONTINUE EXPEDITION',
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

  Widget _buildStat(String label, String value, Color color) {
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
            fontSize: 13.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
