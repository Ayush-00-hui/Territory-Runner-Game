import 'package:flutter/material.dart';

import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';

class HomeHeader extends StatelessWidget {
  final RunnerProfile profile;

  const HomeHeader({super.key, required this.profile});

  Color _factionColor(String faction) {
    if (faction.contains('Solar')) return AppColors.warning;
    if (faction.contains('Quantum')) return AppColors.info;
    return AppColors.accent;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final factionColor = _factionColor(profile.faction);
    final callsign = profile.username.isNotEmpty ? profile.username : 'Runner';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle with athletic initial
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 1.5),
          ),
          child: Center(
            child: Text(
              callsign.isNotEmpty ? callsign[0].toUpperCase() : 'R',
              style: AppText.titleLarge.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),

        // Greeting, Callsign and Faction / Level badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_greeting(), style: AppText.labelSmall),
              const SizedBox(height: AppSpacing.s2),
              Text(
                callsign,
                style: AppText.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s4),
              Wrap(
                spacing: AppSpacing.s6,
                runSpacing: AppSpacing.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Level capsule
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadius.br8,
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'Level ${profile.level}',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Faction tag
                  if (profile.faction.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: factionColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.br8,
                        border: Border.all(
                          color: factionColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        profile.faction,
                        style: AppText.labelSmall.copyWith(
                          color: factionColor,
                          fontSize: 10,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Streak badge with amber flame
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: AppSpacing.s6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: AppRadius.brFull,
            border: Border.all(color: AppColors.borderSubtle, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.warning,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.s4),
              Text(
                '${profile.currentStreak}',
                style: AppText.labelLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Live Sync status chip
        const SyncChip(),
      ],
    );
  }
}
