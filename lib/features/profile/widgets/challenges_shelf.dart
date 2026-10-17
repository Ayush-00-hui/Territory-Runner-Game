import 'package:flutter/material.dart';
import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';
import 'profile_dialogs.dart';

class ChallengesShelf extends StatelessWidget {
  final RunnerProfile profile;
  final int territoriesCount;
  final double totalAreaSqMeters;

  const ChallengesShelf({
    super.key,
    required this.profile,
    required this.territoriesCount,
    required this.totalAreaSqMeters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- ACTIVE ATHLETE QUESTS ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.br20,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 18),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'Active conquest quests',
                        style: AppText.headingSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Resets in 14h',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Quest 1: Distance
              _buildQuestItem(
                title: 'Daily sector scout',
                description: 'Run at least 2.0 km on foot',
                current: profile.totalDistanceKm,
                target: 2.0,
                unit: 'km',
                xpReward: 75,
              ),

              const Divider(color: AppColors.border, height: 24),

              // Quest 2: Loops
              _buildQuestItem(
                title: 'Loop closure',
                description: 'Enclose and claim 1 territory polygon',
                current: territoriesCount.toDouble(),
                target: 1.0,
                unit: 'loop',
                xpReward: 120,
              ),

              const Divider(color: AppColors.border, height: 24),

              // Quest 3: Territory Footprint
              _buildQuestItem(
                title: 'Territory expansion',
                description: 'Hold over 10,000 m² of ground',
                current: totalAreaSqMeters,
                target: 10000.0,
                unit: 'm²',
                xpReward: 250,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.s20),

        // --- TROPHY CASE SECTION HEADER ---
        Text(
          'Trophy case & badges',
          style: AppText.headingSmall.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),

        // --- TROPHY CASE GRID ---
        _buildBadgeGrid(context),
      ],
    );
  }

  Widget _buildQuestItem({
    required String title,
    required String description,
    required double current,
    required double target,
    required String unit,
    required int xpReward,
  }) {
    final double progress = (current / target).clamp(0.0, 1.0);
    final bool isCompleted = progress >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCompleted ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.accentContainer : AppColors.surface2,
                borderRadius: AppSpacing.br8,
                border: Border.all(
                  color: isCompleted ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                isCompleted ? 'Claimed ✓' : '+$xpReward XP',
                style: AppText.labelSmall.copyWith(
                  color: isCompleted ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        ClipRRect(
          borderRadius: AppSpacing.brFull,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted ? AppColors.accent : AppColors.accent.withValues(alpha: 0.6),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).round()}% complete',
              style: AppText.bodySmall.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '${current >= 1000 ? current.toStringAsFixed(0) : current.toStringAsFixed(1)} / ${target >= 1000 ? target.toStringAsFixed(0) : target.toStringAsFixed(1)} $unit',
              style: AppText.bodySmall.copyWith(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeGrid(BuildContext context) {
    final badges = [
      _BadgeDefinition(
        name: 'First Conquest',
        subtitle: 'Claimed 1st polygon loop',
        icon: Icons.emoji_events_rounded,
        unlocked: profile.badges.contains('First Conquest') || territoriesCount >= 1,
        criteria: 'Enclose and claim at least 1 sovereign GPS loop.',
        reward: '+50 XP, "Pioneer Runner" Title',
      ),
      _BadgeDefinition(
        name: 'Territory Sovereign',
        subtitle: 'Conquered 10k m² ground',
        icon: Icons.military_tech_rounded,
        unlocked: profile.badges.contains('Territory Sovereign') || totalAreaSqMeters >= 10000,
        criteria: 'Hold 10,000+ m² of sovereign territory.',
        reward: '+200 XP, "Sovereign Runner" Insignia',
      ),
      _BadgeDefinition(
        name: '10K Centurion',
        subtitle: 'Logged 10 km on foot',
        icon: Icons.directions_run_rounded,
        unlocked: profile.badges.contains('10K Centurion') || profile.totalDistanceKm >= 10.0,
        criteria: 'Complete 10.0 cumulative km on foot.',
        reward: '+300 XP, Centurion Cyber Wings',
      ),
      _BadgeDefinition(
        name: 'Streak Flame',
        subtitle: '7-day conquest streak',
        icon: Icons.local_fire_department_rounded,
        unlocked: profile.badges.contains('Streak Flame') || profile.currentStreak >= 7,
        criteria: 'Maintain run momentum for 7 continuous days.',
        reward: '+150 XP, Burning Flame Avatar Aura',
      ),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.s12,
      mainAxisSpacing: AppSpacing.s12,
      childAspectRatio: 1.5,
      children: badges.map((b) => _buildBadgeCard(context, b)).toList(),
    );
  }

  Widget _buildBadgeCard(BuildContext context, _BadgeDefinition b) {
    final Color badgeColor = b.unlocked ? AppColors.gold : AppColors.disabled;

    return Container(
      decoration: BoxDecoration(
        color: b.unlocked ? AppColors.gold.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(
          color: b.unlocked ? AppColors.gold.withValues(alpha: 0.3) : AppColors.border,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.br16,
        child: InkWell(
          borderRadius: AppSpacing.br16,
          onTap: () {
            AppMotion.selectionTick();
            showBadgeDetailModal(
              context,
              title: b.name,
              subtitle: b.subtitle,
              unlocked: b.unlocked,
              criteria: b.criteria,
              reward: b.reward,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: b.unlocked ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: b.unlocked ? AppColors.gold.withValues(alpha: 0.4) : AppColors.borderSubtle,
                    ),
                  ),
                  child: Icon(
                    b.unlocked ? b.icon : Icons.lock_outline_rounded,
                    color: badgeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        b.name,
                        style: AppText.bodyMedium.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: b.unlocked ? AppColors.textPrimary : AppColors.disabled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.unlocked ? 'Unlocked 🏆' : 'Locked',
                        style: AppText.labelSmall.copyWith(
                          color: b.unlocked ? AppColors.gold : AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeDefinition {
  final String name;
  final String subtitle;
  final IconData icon;
  final bool unlocked;
  final String criteria;
  final String reward;

  const _BadgeDefinition({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
    required this.criteria,
    required this.reward,
  });
}
