import 'package:flutter/material.dart';

import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';

class ProfileHeroCard extends StatelessWidget {
  final RunnerProfile profile;
  final VoidCallback onEditCallsign;
  final VoidCallback onSelectFaction;

  const ProfileHeroCard({
    super.key,
    required this.profile,
    required this.onEditCallsign,
    required this.onSelectFaction,
  });

  @override
  Widget build(BuildContext context) {
    final int nextLevelXp = profile.level * 250;
    final double xpProgress = (profile.xp / nextLevelXp).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with live circular XP Progress Ring
              ProgressRing(
                progress: xpProgress,
                size: 68,
                strokeWidth: 3.5,
                progressColor: AppColors.accent,
                trackColor: AppColors.surface2,
                center: Container(
                  height: 52,
                  width: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: Center(
                    child: Text(
                      profile.username.isNotEmpty
                          ? profile.username[0].toUpperCase()
                          : 'R',
                      style: AppText.headingLarge.copyWith(
                        color: AppColors.onAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.username.isNotEmpty
                                ? profile.username
                                : 'Athlete',
                            style: AppText.headlineMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Semantics(
                          button: true,
                          label: 'Edit callsign',
                          child: GestureDetector(
                            onTap: onEditCallsign,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: AppColors.textSecondary,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        NeutralChip(label: 'Level ${profile.level}'),
                        NeutralChip(
                          label: profile.faction.isNotEmpty
                              ? profile.faction
                              : 'Faction',
                          icon: Icons.shield_outlined,
                          onTap: onSelectFaction,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              // Neutral Streak Badge (Moved to Profile per H3)
              NeutralChip(
                label: '${profile.currentStreak}',
                icon: Icons.local_fire_department_outlined,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          // Tier Progression Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Tier progression',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    '${profile.xp} / $nextLevelXp XP',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              ClipRRect(
                borderRadius: AppSpacing.brFull,
                child: LinearProgressIndicator(
                  value: xpProgress,
                  minHeight: 6,
                  backgroundColor: AppColors.surface2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
