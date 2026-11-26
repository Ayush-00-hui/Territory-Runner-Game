import 'package:flutter/material.dart';

import '../../../models/run_log_entry.dart';
import '../../../services/daily_quest_service.dart';
import '../../../services/run_log_service.dart';
import '../../../ui/ui.dart';

/// Compact daily quests card on Home showing today's rotating goals & streak status.
class DailyQuestsHomeCard extends StatelessWidget {
  final int activeStreakDays;
  final double totalAreaSqMeters;
  final VoidCallback? onTapQuest;

  const DailyQuestsHomeCard({
    super.key,
    required this.activeStreakDays,
    required this.totalAreaSqMeters,
    this.onTapQuest,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        DailyQuestService().revisionNotifier,
        RunLogService().runsNotifier,
      ]),
      builder: (context, _) {
        final List<RunLogEntry> runs = RunLogService().isBoxOpen
            ? RunLogService().getAllRuns()
            : const [];
        return FutureBuilder<List<DailyQuestProgress>>(
          future: DailyQuestService().getTodayQuests(
            overrideRuns: runs,
            totalAreaSqMeters: totalAreaSqMeters,
          ),
          builder: (context, snapshot) {
            final quests = snapshot.data;
            if (quests == null || quests.isEmpty) {
              return const SizedBox.shrink();
            }

            final int completedCount = quests
                .where((q) => q.isCompleted)
                .length;
            final DailyQuestProgress focusQuest = quests.firstWhere(
              (q) => !q.isCompleted,
              orElse: () => quests.first,
            );

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              onTap: onTapQuest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.s6),
                      Expanded(
                        child: Text(
                          'Daily quests',
                          style: AppText.labelLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (activeStreakDays > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                            vertical: AppSpacing.s2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: AppRadius.brFull,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                size: 13,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              Text(
                                '${activeStreakDays}d streak',
                                style: AppText.micro.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                      ],
                      Text(
                        '$completedCount/${quests.length}',
                        style: AppText.labelSmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          focusQuest.title,
                          style: AppText.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        focusQuest.isClaimed
                            ? 'Claimed'
                            : '+${focusQuest.xpReward} XP',
                        style: AppText.labelSmall.copyWith(
                          color: focusQuest.isCompleted
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    focusQuest.description,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  ClipRRect(
                    borderRadius: AppRadius.brFull,
                    child: LinearProgressIndicator(
                      value: focusQuest.progress,
                      backgroundColor: AppColors.surface2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        focusQuest.isCompleted
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.7),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
