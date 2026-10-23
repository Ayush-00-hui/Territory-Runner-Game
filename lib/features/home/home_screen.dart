import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../gameplay/territory_service.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../services/sync_queue.dart';
import '../../ui/ui.dart';
import 'widgets/gps_status_chip.dart';
import 'widgets/home_header.dart';
import 'widgets/offline_sync_banner.dart';
import 'widgets/quick_launch_hero.dart';
import 'widgets/recent_activity_feed.dart';
import 'widgets/weekly_summary_card.dart';
import '../history/run_history_screen.dart';

/// Athlete Home Screen - Performance First Conquest Dashboard
class HomeScreen extends StatelessWidget {
  final VoidCallback? onStartRun;
  final bool isActive;

  const HomeScreen({super.key, this.onStartRun, this.isActive = true});

  Widget _buildSkeleton(BuildContext context, double topPad) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        topPad + AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s32,
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
                width: 48,
                height: 28,
                borderRadius: AppRadius.brFull,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          SkeletonBox(width: 130, height: 32, borderRadius: AppRadius.brFull),
          const SizedBox(height: AppSpacing.s12),
          SkeletonBox(height: 190, borderRadius: AppRadius.br24),
          const SizedBox(height: AppSpacing.s20),
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

    final isBoxReady =
        Hive.isBoxOpen('profile') && Hive.isBoxOpen('territories_v3');
    if (!isBoxReady) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: _buildSkeleton(context, topPad),
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

              return RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.surface,
                displacement: 40,
                onRefresh: () async {
                  AppMotion.lightTick();
                  await SyncQueueService().syncPendingRuns();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    topPad + AppSpacing.s12,
                    AppSpacing.s16,
                    AppSpacing.s32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Athlete Header Row
                      HomeHeader(profile: profile),

                      const SizedBox(height: AppSpacing.s12),

                      // Live Status: Athletic GPS Status Chip with active colored dot
                      Row(children: [GpsStatusChip(isActive: isActive)]),

                      const SizedBox(height: AppSpacing.s12),

                      // Offline Sync Banner (Appears only when pending runs exist)
                      const OfflineSyncBanner(),

                      // Quick Launch "START RUN" Hero (Above the fold on 360x640)
                      QuickLaunchHero(
                        onStartRun: onStartRun,
                        isActive: isActive,
                      ),

                      const SizedBox(height: AppSpacing.s20),

                      // Weekly Performance Summary & 7-Day Bar Chart (Below the fold)
                      WeeklySummaryCard(
                        profile: profile,
                        territories: territories,
                      ),

                      const SizedBox(height: AppSpacing.s24),

                      // Recent Activity Header
                      SectionHeader(
                        title: 'Recent runs',
                        actionLabel: 'View all',
                        onAction: () {
                          AppMotion.lightTick();
                          Navigator.push(
                            context,
                            AppMotion.pageRoute(
                              builder: (_) => const RunHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // Recent Activity Feed
                      RecentActivityFeed(
                        territories: territories,
                        onStartRun: onStartRun,
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
