import 'package:flutter/material.dart';

import '../../gameplay/territory_service.dart';
import '../../../models/runner_profile.dart';
import '../../../services/api_client.dart';
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
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.br20,
        side: const BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          const Icon(Icons.badge_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Text(
            'Edit Runner Name',
            style: AppText.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your runner name displayed on leaderboards and team standings:',
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: controller,
            style: AppText.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'Runner name',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        SecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
        PrimaryButton(
          label: 'Save Name',
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
                AppToast.show(context, 'Runner name updated to "$newName"');
              }
            }
          },
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
      'tag': 'Vanguard',
      'color': AppColors.accent,
      'icon': Icons.security_rounded,
      'perk': 'Fast loop closure recognition & precision spatial tracking (+10% base claim speed)',
    },
    {
      'name': 'Iron Syndicate',
      'tag': 'Syndicate',
      'color': AppColors.warning,
      'icon': Icons.wb_sunny_rounded,
      'perk': 'Steady cadence endurance & stamina battery optimization (+15% cadence boost)',
    },
    {
      'name': 'Neon Nomads',
      'tag': 'Nomads',
      'color': AppColors.info,
      'icon': Icons.bolt_rounded,
      'perk': 'Pace acceleration & dynamic sprint momentum (+40% sprint momentum conversion)',
    },
  ];

  AppSheet.show(
    context: context,
    builder: (ctx) => AppSheet(
      title: 'Choose Team',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pledge allegiance to a runner syndicate to represent them on the territorial map grid and unlock tactical perks:',
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          ...factions.map((f) {
            final isSelected = profile.faction == f['name'];
            final factionColor = f['color'] as Color;
            final factionIcon = f['icon'] as IconData;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: GestureDetector(
                onTap: () async {
                  AppMotion.mediumTick();
                  profile.faction = f['name'] as String;
                  await territoryService.saveProfile(profile);
                  // Fire-and-forget sync to backend
                  ApiClient()
                      .updateUserFaction(profile.faction)
                      .catchError((_) => false);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  onUpdated();
                  if (context.mounted) {
                    AppToast.show(
                      context,
                      'Aligned with ${f['name']} Syndicate',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? factionColor.withValues(alpha: 0.12)
                        : AppColors.surface2,
                    borderRadius: AppSpacing.br16,
                    border: Border.all(
                      color: isSelected ? factionColor : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: factionColor.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(factionIcon, color: factionColor, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  f['name'] as String,
                                  style: AppText.bodyMedium.copyWith(
                                    color: isSelected
                                        ? factionColor
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: factionColor.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: AppSpacing.br8,
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: AppText.labelSmall.copyWith(
                                        color: factionColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f['tag'] as String,
                              style: AppText.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              f['perk'] as String,
                              style: AppText.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

void showStatDetailModal(
  BuildContext context, {
  required String title,
  required String value,
  required String description,
  required List<Map<String, String>> metrics,
}) {
  AppSheet.show(
    context: context,
    builder: (ctx) => AppSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Telemetry Summary',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: AppText.headlineSmall.copyWith(
                  color: AppColors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            description,
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: metrics.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['label'] ?? '',
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        m['val'] ?? '',
                        style: AppText.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          PrimaryButton(
            label: 'Close Telemetry',
            onPressed: () => Navigator.pop(ctx),
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
  final Color badgeColor = unlocked ? AppColors.gold : AppColors.disabled;

  AppSheet.show(
    context: context,
    builder: (ctx) => AppSheet(
      title: 'Achievement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unlocked
                      ? Icons.emoji_events_rounded
                      : Icons.lock_outline_rounded,
                  color: badgeColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.gold.withValues(alpha: 0.16)
                            : AppColors.surface2,
                        borderRadius: AppSpacing.br8,
                        border: Border.all(
                          color: unlocked
                              ? AppColors.gold.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        unlocked ? 'Unlocked 🏆' : 'Locked',
                        style: AppText.labelSmall.copyWith(
                          color: unlocked
                              ? AppColors.gold
                              : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRITERIA',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  criteria,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const Divider(color: AppColors.border, height: 20),
                Text(
                  'CONQUEST REWARD',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reward,
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          PrimaryButton(
            label: unlocked ? 'Done' : 'Close',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}
