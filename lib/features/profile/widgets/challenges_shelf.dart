import 'package:flutter/material.dart';

import '../../../models/run_log_entry.dart';
import '../../../models/runner_profile.dart';
import '../../../services/daily_quest_service.dart';
import '../../../services/run_log_service.dart';
import '../../../ui/ui.dart';
import 'achievements_sheet.dart';
import 'profile_dialogs.dart';

class ChallengesShelf extends StatelessWidget {
  final RunnerProfile profile;
  final int territoriesCount;
  final double totalAreaSqMeters;
  final String? resetCountdown;

  const ChallengesShelf({
    super.key,
    required this.profile,
    required this.territoriesCount,
    required this.totalAreaSqMeters,
    this.resetCountdown,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hoursToMidnight = 24 - now.hour;
    final String resetString =
        resetCountdown ?? 'Resets in ${hoursToMidnight}h';

    return ListenableBuilder(
      listenable: Listenable.merge([
        DailyQuestService().revisionNotifier,
        RunLogService().runsNotifier,
      ]),
      builder: (context, _) {
        final List<RunLogEntry> runs = RunLogService().isBoxOpen
            ? RunLogService().getAllRuns()
            : const [];
        final initialQuests = DailyQuestService().getTodayQuestsSync(
          now: now,
          overrideRuns: runs,
          totalAreaSqMeters: totalAreaSqMeters,
        );
        return FutureBuilder<List<DailyQuestProgress>>(
          initialData: initialQuests,
          future: DailyQuestService().getTodayQuests(
            now: now,
            overrideRuns: runs,
            totalAreaSqMeters: totalAreaSqMeters,
          ),
          builder: (context, snapshot) {
            final quests = snapshot.data ?? initialQuests;
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
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: AppColors.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Flexible(
                                  child: Text(
                                    'Active territory quests',
                                    style: AppText.labelLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                resetString,
                                style: AppText.labelSmall.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      for (int i = 0; i < quests.length; i++) ...[
                        if (i > 0)
                          const Divider(color: AppColors.border, height: 24),
                        _buildQuestItem(
                          title: quests[i].title,
                          description: quests[i].description,
                          current: quests[i].current,
                          target: quests[i].target,
                          unit: quests[i].unit,
                          xpReward: quests[i].xpReward,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s20),

                // --- TROPHY CASE SECTION HEADER ---
                Text(
                  'Trophy case & badges',
                  style: AppText.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),

                // --- TROPHY CASE GRID ---
                _buildBadgeGrid(context),

                const SizedBox(height: AppSpacing.s14),

                SecondaryButton(
                  label: 'Milestones & earned timeline',
                  icon: Icons.workspace_premium_rounded,
                  onPressed: () => AchievementsSheet.show(context: context),
                ),
              ],
            );
          },
        );
      },
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
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppText.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.accentContainer
                    : AppColors.surface2,
                borderRadius: AppSpacing.br8,
                border: Border.all(
                  color: isCompleted ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                isCompleted ? 'Claimed ✓' : '+$xpReward XP',
                style: AppText.labelSmall.copyWith(
                  color: isCompleted
                      ? AppColors.accent
                      : AppColors.textSecondary,
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
              isCompleted
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.6),
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
              style: AppText.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${current >= 1000 ? current.toStringAsFixed(0) : current.toStringAsFixed(1)} / ${target >= 1000 ? target.toStringAsFixed(0) : target.toStringAsFixed(1)} $unit',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
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
        name: 'First Claim',
        subtitle: 'Claimed 1st territory loop',
        icon: Icons.emoji_events_rounded,
        unlocked: profile.hasBadge('First Claim') || territoriesCount >= 1,
        criteria: 'Enclose and claim at least 1 territory running loop.',
        reward: '+50 XP • Pioneer Runner Title',
      ),
      _BadgeDefinition(
        name: 'Territory Master',
        subtitle: 'Claimed 10k m² ground',
        icon: Icons.military_tech_rounded,
        unlocked:
            profile.hasBadge('Territory Master') || totalAreaSqMeters >= 10000,
        criteria: 'Hold 10,000+ m² of territory on foot.',
        reward: '+200 XP • Gold Crown in Wardrobe',
      ),
      _BadgeDefinition(
        name: '10K Centurion',
        subtitle: 'Logged 10 km on foot',
        icon: Icons.directions_run_rounded,
        unlocked:
            profile.hasBadge('10K Centurion') ||
            profile.totalDistanceKm >= 10.0,
        criteria: 'Complete 10.0 cumulative km on foot.',
        reward: '+300 XP • Speed Visor in Wardrobe',
      ),
      _BadgeDefinition(
        name: 'Streak Flame',
        subtitle: '7-day run streak',
        icon: Icons.local_fire_department_rounded,
        unlocked:
            profile.hasBadge('Streak Flame') || profile.currentStreak >= 7,
        criteria: 'Maintain run momentum for 7 continuous days.',
        reward: '+150 XP • Flame Shorts in Wardrobe',
      ),
    ];

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final double childAspectRatio =
        (textScale > 1.15 || MediaQuery.sizeOf(context).width <= 360)
        ? 1.2
        : 1.5;

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.s12,
      mainAxisSpacing: AppSpacing.s12,
      childAspectRatio: childAspectRatio,
      children: badges.map((b) => _buildBadgeCard(context, b)).toList(),
    );
  }

  Widget _buildBadgeCard(BuildContext context, _BadgeDefinition b) {
    final Color badgeColor = b.unlocked ? AppColors.gold : AppColors.disabled;

    return Container(
      decoration: BoxDecoration(
        color: b.unlocked
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(
          color: b.unlocked
              ? AppColors.gold.withValues(alpha: 0.3)
              : AppColors.border,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.br16,
        child: InkWell(
          borderRadius: AppSpacing.br16,
          onTap: () {
            showBadgeDetailModal(
              context,
              title: b.name,
              subtitle: b.subtitle,
              unlocked: b.unlocked,
              criteria: b.criteria,
              reward: b.reward,
            );
          },
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: b.unlocked
                        ? AppColors.gold.withValues(alpha: 0.16)
                        : AppColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: b.unlocked
                          ? AppColors.gold.withValues(alpha: 0.4)
                          : AppColors.borderSubtle,
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
                          fontWeight: FontWeight.w700,
                          color: b.unlocked
                              ? AppColors.textPrimary
                              : AppColors.disabled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.unlocked ? 'Unlocked' : 'Locked',
                        style: AppText.labelSmall.copyWith(
                          color: b.unlocked
                              ? AppColors.gold
                              : AppColors.textMuted,
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
