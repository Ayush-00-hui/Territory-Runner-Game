import 'package:flutter/material.dart';

import '../../../models/leaderboard_entry.dart';
import '../../../services/api_client.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/widgets/skeleton_box.dart';
import '../../../ui/widgets/empty_state.dart';

/// Global Leaderboard Bottom Sheet modal with podium accents and pinned user row.
class LeaderboardSheet extends StatelessWidget {
  final ApiClient apiClient;
  final String currentUserId;

  const LeaderboardSheet({
    super.key,
    required this.apiClient,
    required this.currentUserId,
  });

  static Future<void> show({
    required BuildContext context,
    required ApiClient apiClient,
    required String currentUserId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => LeaderboardSheet(
          apiClient: apiClient,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s20,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: AppSpacing.brFull,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 24,
                  ),
                  SizedBox(width: AppSpacing.s8),
                  Text('Global leaderboard', style: AppText.headingSmall),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntry>>(
              future: apiClient.getLeaderboard(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s8,
                      ),
                      child: SkeletonBox(
                        height: 56,
                        borderRadius: AppSpacing.br16,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Leaderboard Offline',
                      message:
                          'Could not connect to authority server.\n${snapshot.error}',
                    ),
                  );
                }

                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No Runners Ranked',
                      message:
                          'Be the first pioneer to claim territory on foot!',
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: AppColors.borderSubtle, height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isCurrent = entry.userId == currentUserId;

                    Color rankColor = AppColors.textSecondary;
                    if (entry.rank == 1) rankColor = AppColors.gold;
                    if (entry.rank == 2) rankColor = AppColors.silver;
                    if (entry.rank == 3) rankColor = AppColors.bronze;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s12,
                        horizontal: AppSpacing.s8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: AppSpacing.br12,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '#${entry.rank}',
                              style: AppText.statSmall.copyWith(
                                color: rankColor,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      entry.username,
                                      style: AppText.bodyBold.copyWith(
                                        color: isCurrent
                                            ? AppColors.accent
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: AppSpacing.s6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.s6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius: AppSpacing.br8,
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: AppColors.onAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${entry.faction} • Lvl ${entry.level} • ${entry.totalRuns} runs',
                                  style: AppText.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                entry.totalAreaSqm >= 1000000
                                    ? '${(entry.totalAreaSqm / 1000000).toStringAsFixed(2)} km²'
                                    : '${entry.totalAreaSqm.toStringAsFixed(0)} m²',
                                style: AppText.statSmall.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const Text('Claimed', style: AppText.label),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
