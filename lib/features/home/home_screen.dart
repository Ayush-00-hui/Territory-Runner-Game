import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../gameplay/territory_service.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../ui/ui.dart';
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

  @override
  Widget build(BuildContext context) {
    final territoryService = TerritoryService();
    final topPad = MediaQuery.paddingOf(context).top;

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

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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

                    const SizedBox(height: AppSpacing.s16),

                    // Offline Sync Banner (Appears only when pending runs exist)
                    const OfflineSyncBanner(),

                    // Weekly Performance Summary & 7-Day Bar Chart
                    WeeklySummaryCard(
                      profile: profile,
                      territories: territories,
                    ),

                    const SizedBox(height: AppSpacing.s20),

                    // Quick Launch "START RUN" Hero
                    QuickLaunchHero(onStartRun: onStartRun, isActive: isActive),

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
              );
            },
          );
        },
      ),
    );
  }
}
