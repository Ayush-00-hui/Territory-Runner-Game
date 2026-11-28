import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../models/loot_crate.dart';
import '../../gameplay/loot_crate_service.dart';

/// Interactive FlutterMap layer rendering procedural tactical loot crates
/// with glowing neon pulse animations.
class LootCrateLayer extends StatefulWidget {
  const LootCrateLayer({super.key});

  @override
  State<LootCrateLayer> createState() => _LootCrateLayerState();
}

class _LootCrateLayerState extends State<LootCrateLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final LootCrateService _crateService = LootCrateService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _crateService.addListener(_onCratesChanged);
  }

  void _onCratesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _crateService.removeListener(_onCratesChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crates = _crateService.activeCrates;
    if (crates.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: crates.map((crate) {
        return Marker(
          point: crate.position,
          width: 52.0,
          height: 52.0,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 0.90 + (_pulseController.value * 0.20);
              Color themeColor;
              IconData icon;

              switch (crate.type) {
                case LootCrateType.shieldBattery:
                  themeColor = const Color(0xFF38BDF8); // Electric sky blue
                  icon = Icons.shield_rounded;
                  break;
                case LootCrateType.overchargeBeacon:
                  themeColor = const Color(0xFFFBBF24); // Amber gold
                  icon = Icons.bolt_rounded;
                  break;
                case LootCrateType.factionShard:
                  themeColor = const Color(0xFFA855F7); // Neon amethyst
                  icon = Icons.diamond_rounded;
                  break;
              }

              return Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D0F11).withValues(alpha: 0.92),
                    border: Border.all(color: themeColor, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(
                          alpha: 0.55 * _pulseController.value,
                        ),
                        blurRadius: 14.0 * scale,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, color: themeColor, size: 24.0),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
