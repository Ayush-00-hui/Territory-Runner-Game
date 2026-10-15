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
            borderRadius: AppSpacing.br24,
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
                        'ACTIVE CONQUEST QUESTS',
                        style: AppText.headingSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'RESETS IN 14H',
                    style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 9.5),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Quest 1: Distance
              _buildQuestItem(
                title: 'DAILY SECTOR SCOUT',
                description: 'Run at least 2.0 km on foot',
                current: profile.totalDistanceKm,
                target: 2.0,
                unit: 'km',
                xpReward: 75,
              ),

              const Divider(color: AppColors.border, height: 24),

              // Quest 2: Loops
              _buildQuestItem(
                title: 'LOOP CLOSURE',
                description: 'Enclose and claim 1 territory polygon',
                current: territoriesCount.toDouble(),
                target: 1.0,
                unit: 'loop',
                xpReward: 120,
              ),

              const Divider(color: AppColors.border, height: 24),

              // Quest 3: Territory Footprint
              _buildQuestItem(
                title: 'TERRITORY EXPANSION',
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
          'TROPHY CASE & BADGES',
          style: AppText.label.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.bodyBold.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? AppColors.accent : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.accent : AppColors.surface2,
                borderRadius: AppSpacing.br8,
                border: Border.all(
                  color: isCompleted ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                isCompleted ? 'CLAIMED' : '+$xpReward XP',
                style: AppText.label.copyWith(
                  color: isCompleted ? Colors.black : AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
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
              isCompleted ? AppColors.accent : const Color(0xFF00E5FF),
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
              style: AppText.bodySmall.copyWith(fontSize: 10, color: AppColors.textMuted),
            ),
            Text(
              '${current >= 1000 ? current.toStringAsFixed(0) : current.toStringAsFixed(1)} / ${target >= 1000 ? target.toStringAsFixed(0) : target.toStringAsFixed(1)} $unit',
              style: AppText.statSmall.copyWith(fontSize: 10, color: Colors.white70),
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
    return Container(
      decoration: BoxDecoration(
        color: b.unlocked ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: Border.all(
          color: b.unlocked ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
          width: b.unlocked ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.br20,
        child: InkWell(
          borderRadius: AppSpacing.br20,
          onTap: () {
            AppMotion.lightTick();
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
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: b.unlocked ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: b.unlocked ? AppColors.accent : Colors.white12,
                    ),
                  ),
                  child: Icon(
                    b.unlocked ? b.icon : Icons.lock_outline_rounded,
                    color: b.unlocked ? AppColors.accent : Colors.white30,
                    size: 20,
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
                        style: AppText.bodyBold.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: b.unlocked ? Colors.white : Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.unlocked ? 'UNLOCKED ✓' : 'LOCKED',
                        style: AppText.label.copyWith(
                          color: b.unlocked ? AppColors.accent : AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
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
