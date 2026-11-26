import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../gameplay/territory_service.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../models/training_plan.dart';
import '../../services/run_log_service.dart';
import '../../services/sync_queue.dart';
import '../../ui/ui.dart';
import '../history/run_history_screen.dart';
import '../social/widgets/social_hub_cache.dart';
import '../social/widgets/social_hub_sheet.dart';
import 'widgets/daily_quests_home_card.dart';
import 'widgets/home_header.dart';
import 'widgets/needs_defending_row.dart';
import 'widgets/offline_sync_banner.dart';
import 'widgets/quick_launch_hero.dart';
import 'widgets/recent_activity_feed.dart';
import 'widgets/today_workout_card.dart';
import 'widgets/weekly_recap_card.dart';
import 'widgets/weekly_summary_card.dart';

/// Athlete Home Screen - Performance First Running & Territory Dashboard
class HomeScreen extends StatelessWidget {
  final VoidCallback? onStartRun;
  final ValueChanged<PlanWorkoutDay>? onStartWorkout;
  final bool isActive;
  final ScrollController? scrollController;

  const HomeScreen({
    super.key,
    this.onStartRun,
    this.onStartWorkout,
    this.isActive = true,
    this.scrollController,
  });

  Widget _buildSkeleton(BuildContext context, double topPad, double bottomPad) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        topPad + AppSpacing.s12,
        AppSpacing.s16,
        bottomPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              SkeletonBox(
                width: 48,
                height: 48,
                borderRadius: AppRadius.brFull,
              ),
              const SizedBox(width: AppSpacing.s12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 12),
                    SizedBox(height: AppSpacing.s6),
                    SkeletonBox(width: 140, height: 18),
                  ],
                ),
              ),
              SkeletonBox(
                width: 64,
                height: 28,
                borderRadius: AppRadius.brFull,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          SkeletonBox(height: 180, borderRadius: AppRadius.br24),
          const SizedBox(height: AppSpacing.s24),
          SkeletonBox(height: 24, width: 140),
          const SizedBox(height: AppSpacing.s12),
          SkeletonBox(height: 150, borderRadius: AppRadius.br16),
          const SizedBox(height: AppSpacing.s24),
          SkeletonBox(height: 72, borderRadius: AppRadius.br16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final territoryService = TerritoryService();
    final topPad = MediaQuery.paddingOf(context).top;
    // Bottom padding = Nav height (72dp) + safe area + athletic buffer
    final bottomNavPad =
        72.0 + MediaQuery.paddingOf(context).bottom + AppSpacing.s24;

    final isBoxReady =
        Hive.isBoxOpen('profile') && Hive.isBoxOpen('territories_v3');
    if (!isBoxReady) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: _buildSkeleton(context, topPad, bottomNavPad),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: ValueListenableBuilder(
        valueListenable: Hive.box<RunnerProfile>('profile').listenable(),
        builder: (context, Box<RunnerProfile> profileBox, _) {
          final profile = territoryService.getProfile();

          return ValueListenableBuilder(
            valueListenable: Hive.box<Territory>('territories_v3').listenable(),
            builder: (context, Box<Territory> territoryBox, _) {
              final territories = territoryService
                  .getCapturedTerritoryObjects();
              final double totalAreaSqm = territories.fold<double>(
                0.0,
                (sum, t) => sum + t.areaSqMeters,
              );
              final int activeStreak = RunLogService().isBoxOpen
                  ? RunLogService().computeActiveStreakDays()
                  : profile.currentStreak;
              final now = DateTime.now();
              final int daysToLeagueReset = 8 - now.weekday;

              return RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.surface,
                displacement: 40,
                onRefresh: () async {
                  await SyncQueueService().syncPendingRuns();
                },
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    topPad + AppSpacing.s12,
                    AppSpacing.s16,
                    bottomNavPad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Athlete Header Row (with level ring avatar + single CombinedStatusIndicator)
                      HomeHeader(profile: profile),

                      const SizedBox(height: AppSpacing.s16),

                      // Offline Sync Banner (Appears only when pending runs exist)
                      const OfflineSyncBanner(),

                      // Quick Launch Hero (Real daily goal or quiet goal setup + 56dp CTA)
                      QuickLaunchHero(
                        profile: profile,
                        territories: territories,
                        onStartRun: onStartRun,
                        isActive: isActive,
                      ),

                      const SizedBox(height: AppSpacing.s12),

                      // Daily Quests & Streak Pulse (Placed below primary hero CTA)
                      DailyQuestsHomeCard(
                        activeStreakDays: activeStreak,
                        totalAreaSqMeters: totalAreaSqm,
                        onTapQuest: onStartRun,
                      ),

                      // Needs Defending Row (Appears when claimed land falls <= 50% strength)
                      NeedsDefendingRow(territories: territories),

                      // Today's Structured Workout (Zero-shame training plan card)
                      TodayWorkoutCard(
                        onStartWorkout: (plan) {
                          onStartRun?.call();
                        },
                        onStartWorkoutDay: (day) {
                          if (onStartWorkout != null) {
                            onStartWorkout!(day);
                          } else {
                            onStartRun?.call();
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // Weekly Performance Recap (Sundays or active weeks)
                      const WeeklyRecapCard(),

                      // Weekly Performance Summary Header & Card
                      const SectionHeader(title: 'Weekly summary'),
                      WeeklySummaryCard(
                        profile: profile,
                        territories: territories,
                      ),

                      // Recent Activity Header (with baseline-aligned "View all" action)
                      SectionHeader(
                        title: 'Recent runs',
                        actionLabel: 'View all',
                        onAction: () {
                          Navigator.push(
                            context,
                            AppMotion.pageRoute(
                              builder: (_) => const RunHistoryScreen(),
                            ),
                          );
                        },
                      ),

                      // Recent Activity Feed
                      RecentActivityFeed(
                        territories: territories,
                        onStartRun: onStartRun,
                      ),

                      const SizedBox(height: AppSpacing.s16),

                      // Community Feed & Duels Banner
                      InkWell(
                        onTap: () => showSocialHubSheet(context),
                        borderRadius: AppRadius.br16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.br16,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.sports_kabaddi_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: ValueListenableBuilder<int>(
                                  valueListenable:
                                      SocialHubCache.incomingCountNotifier,
                                  builder: (context, incomingRequests, _) {
                                    final String subtitleText =
                                        incomingRequests > 0
                                        ? '$incomingRequests pending invite${incomingRequests == 1 ? '' : 's'} · League resets in ${daysToLeagueReset}d'
                                        : 'Feed, kudos, duels · League resets in ${daysToLeagueReset}d';
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Community & duels',
                                          style: AppText.bodyMedium.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitleText,
                                          style: AppText.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
