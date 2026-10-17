import 'package:flutter/material.dart';
import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';
import 'profile_dialogs.dart';

class ProfileAchievementsList extends StatelessWidget {
  final RunnerProfile profile;
  final int territoriesCount;

  const ProfileAchievementsList({
    super.key,
    required this.profile,
    required this.territoriesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ProfileAchievementTile(
            icon: Icons.emoji_events_rounded,
            title: 'First Conquest',
            subtitle: 'Claim your first territory polygon on foot',
            unlocked: profile.badges.contains('First Conquest') || territoriesCount >= 1,
            onTap: () {
              showBadgeDetailModal(
                context,
                title: 'First Conquest',
                subtitle: 'Claim your first territory polygon on foot',
                unlocked: profile.badges.contains('First Conquest') || territoriesCount >= 1,
                criteria: 'Enclose and claim at least 1 real-world polygon in GPS tracking mode.',
                reward: '+50 XP, "Pioneer Runner" Title',
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          ProfileAchievementTile(
            icon: Icons.military_tech_rounded,
            title: 'Territory Sovereign',
            subtitle: 'Conquer over 10,000 m² of sovereign ground',
            unlocked: profile.badges.contains('Territory Sovereign') || profile.badges.contains('Sector Commander') || territoriesCount >= 5,
            onTap: () {
              showBadgeDetailModal(
                context,
                title: 'Territory Sovereign',
                subtitle: 'Conquer over 10,000 m² of sovereign ground',
                unlocked: profile.badges.contains('Territory Sovereign') || profile.badges.contains('Sector Commander') || territoriesCount >= 5,
                criteria: 'Enclose and secure vast contiguous territory polygons.',
                reward: '+200 XP, "Sovereign Runner" Faction Insignia',
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          ProfileAchievementTile(
            icon: Icons.bolt_rounded,
            title: '10K Centurion',
            subtitle: 'Log over 10.0 total kilometers on foot',
            unlocked: profile.badges.contains('10K Centurion') || profile.totalDistanceKm >= 10.0,
            onTap: () {
              showBadgeDetailModal(
                context,
                title: '10K Centurion',
                subtitle: 'Log over 10.0 total kilometers on foot',
                unlocked: profile.badges.contains('10K Centurion') || profile.totalDistanceKm >= 10.0,
                criteria: 'Complete a cumulative 10.0 km of running or walking.',
                reward: '+300 XP, 10K Centurion Cyber Wings',
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileAchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool unlocked;
  final VoidCallback? onTap;

  const ProfileAchievementTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = unlocked ? AppColors.gold : AppColors.disabled;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          AppMotion.selectionTick();
          onTap!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: unlocked ? AppColors.gold.withValues(alpha: 0.06) : AppColors.surface2,
          borderRadius: AppSpacing.br16,
          border: Border.all(
            color: unlocked ? AppColors.gold.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: unlocked ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surface,
                borderRadius: AppSpacing.br12,
                border: Border.all(
                  color: unlocked ? AppColors.gold.withValues(alpha: 0.4) : AppColors.borderSubtle,
                ),
              ),
              child: Icon(icon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyMedium.copyWith(
                      color: unlocked ? AppColors.textPrimary : AppColors.disabled,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              color: badgeColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
