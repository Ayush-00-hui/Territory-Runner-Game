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
                      profile.username.isNotEmpty ? profile.username[0].toUpperCase() : 'R',
                      style: const TextStyle(
                        color: AppColors.onAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
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
                            profile.username.isNotEmpty ? profile.username : 'Athlete',
                            style: AppText.headlineMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        GestureDetector(
                          onTap: onEditCallsign,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentContainer,
                            borderRadius: AppSpacing.br8,
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'LEVEL ${profile.level} ATHLETE',
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onSelectFaction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: AppSpacing.br8,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_rounded, color: AppColors.accent, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  profile.faction.isNotEmpty ? profile.faction : 'Faction',
                                  style: AppText.labelSmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              // Streak Flame Badge (Static, no pulse, Charcoal + Ember)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.br12,
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.currentStreak}',
                      style: AppText.statMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
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
                  Text(
                    'TIER PROGRESSION',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
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
