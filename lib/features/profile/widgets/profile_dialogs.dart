import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../gameplay/territory_service.dart';
import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';

void showEditCallsignDialog(
  BuildContext context,
  RunnerProfile profile,
  TerritoryService territoryService,
  VoidCallback onUpdated,
) {
  final controller = TextEditingController(text: profile.username);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.badge_rounded, color: AppColors.accent, size: 22),
          SizedBox(width: 8),
          Text('Edit Athlete Callsign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your cyber runner callsign broadcasted to rival factions on the grid:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'Callsign / Nickname',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              profile.username = newName;
              await territoryService.saveProfile(profile);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              onUpdated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text('Callsign updated to "$newName" ⚡', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ),
                );
              }
            }
          },
          child: const Text('Save Callsign', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );
}

void showFactionSelectionDialog(
  BuildContext context,
  RunnerProfile profile,
  TerritoryService territoryService,
  VoidCallback onUpdated,
) {
  final factions = [
    {
      'name': 'Cyber Vanguard',
      'tag': 'SYSTEM GUARDIANS',
      'color': const Color(0xFF00E676),
      'icon': Icons.security_rounded,
      'perk': 'Precision spatial radar & fast polygon enclosure recognition (+10% base claim speed)',
    },
    {
      'name': 'Solar Syndicate',
      'tag': 'KINETIC CONQUERORS',
      'color': const Color(0xFFFF9100),
      'icon': Icons.wb_sunny_rounded,
      'perk': 'Solar endurance surge & stamina battery efficiency (+15% cadence recharge boost)',
    },
    {
      'name': 'Quantum Pulse',
      'tag': 'ANTI-GRAVITY DRIFTERS',
      'color': const Color(0xFF8A2BE2),
      'icon': Icons.bolt_rounded,
      'perk': 'Zero-G sub-orbital glide thrust & +40% sprint momentum conversion multiplier',
    },
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.accent, size: 22),
                SizedBox(width: 8),
                Text(
                  'FACTION ALIGNMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pledge allegiance to a runner syndicate to represent them on the territorial map grid and unlock tactical flight bonuses:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 20),
            ...factions.map((f) {
              final isSelected = profile.faction == f['name'];
              final factionColor = f['color'] as Color;
              final factionIcon = f['icon'] as IconData;

              return GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  profile.faction = f['name'] as String;
                  await territoryService.saveProfile(profile);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  onUpdated();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text(
                          'Aligned with ${f['name']} Syndicate! ⚡',
                          style: TextStyle(color: factionColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? factionColor.withValues(alpha: 0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? factionColor : AppColors.border,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: factionColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(factionIcon, color: factionColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  f['name'] as String,
                                  style: TextStyle(
                                    color: isSelected ? factionColor : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: factionColor.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: TextStyle(color: factionColor, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f['tag'] as String,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              f['perk'] as String,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

void showStatDetailModal(
  BuildContext context, {
  required String title,
  required String value,
  required String description,
  required List<Map<String, String>> metrics,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: metrics.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m['label'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(m['val'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface2,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE TELEMETRY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

void showBadgeDetailModal(
  BuildContext context, {
  required String title,
  required String subtitle,
  required bool unlocked,
  required String criteria,
  required String reward,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (unlocked ? AppColors.accent : AppColors.surface2).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                  color: unlocked ? AppColors.accent : Colors.white38,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (unlocked ? AppColors.accent : Colors.white12).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        unlocked ? 'STATUS: UNLOCKED 🏆' : 'STATUS: LOCKED 🔒',
                        style: TextStyle(
                          color: unlocked ? AppColors.accent : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CRITERIA', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(criteria, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                const Divider(color: Colors.white10, height: 20),
                const Text('CONQUEST REWARD', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(reward, style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: unlocked ? AppColors.accent : AppColors.surface2,
              foregroundColor: unlocked ? Colors.black : Colors.white70,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(unlocked ? 'CLAIM BADGE' : 'CLOSE', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    ),
  );
}
