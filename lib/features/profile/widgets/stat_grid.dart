import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gameplay/territory_service.dart';
import '../../../models/runner_profile.dart';
import '../../../services/run_log_service.dart';
import '../../../ui/ui.dart';
import 'profile_dialogs.dart';

class ProfileStatGrid extends StatelessWidget {
  final RunnerProfile profile;
  final TerritoryService territoryService;

  const ProfileStatGrid({
    super.key,
    required this.profile,
    required this.territoryService,
  });

  @override
  Widget build(BuildContext context) {
    final captured = territoryService.getCapturedTerritoryObjects();
    final double totalAreaM2 = captured.fold(
      0.0,
      (sum, t) => sum + t.areaSqMeters,
    );
    final String territoryVal = totalAreaM2 >= 10000
        ? '${(totalAreaM2 / 1000000.0).toStringAsFixed(2)} km²'
        : '${totalAreaM2.toStringAsFixed(0)} m²';

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final double aspectRatio = textScale > 1.15 ? 1.2 : 1.45;

    final runs = RunLogService().getAllRuns();
    final int totalRuns = runs.length;
    final double longestRunKm = runs.isEmpty
        ? 0.0
        : runs.map((r) => r.distanceM / 1000.0).reduce(math.max);
    final double avgRunKm = runs.isEmpty
        ? 0.0
        : (runs.fold<double>(0.0, (s, r) => s + (r.distanceM / 1000.0)) /
              runs.length);

    final runsWithPace = runs
        .where((r) => r.distanceM > 0 && r.movingSeconds > 0)
        .toList();
    final String avgPaceStr = runsWithPace.isEmpty
        ? 'No runs logged'
        : () {
            final totalDistM = runsWithPace.fold<double>(
              0.0,
              (s, r) => s + r.distanceM,
            );
            final totalSec = runsWithPace.fold<int>(
              0,
              (s, r) => s + r.movingSeconds,
            );
            final secPerKm = totalSec / (totalDistM / 1000.0);
            final mins = secPerKm ~/ 60;
            final secs = (secPerKm % 60).round();
            return "$mins'${secs.toString().padLeft(2, '0')}\" /km";
          }();

    final nextMilestone = profile.currentStreak < 3
        ? '3 days'
        : profile.currentStreak < 7
        ? '7 days'
        : profile.currentStreak < 14
        ? '14 days'
        : profile.currentStreak < 30
        ? '30 days'
        : '${((profile.currentStreak ~/ 30) + 1) * 30} days';

    final int nextLevelXp = profile.level * 250;
    final int remainingXp = (nextLevelXp - profile.xp).clamp(0, nextLevelXp);

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.s12,
      crossAxisSpacing: AppSpacing.s12,
      childAspectRatio: aspectRatio,
      children: [
        ProfileStatCard(
          icon: Icons.route_rounded,
          title: 'Total Distance',
          value: '${profile.totalDistanceKm.toStringAsFixed(1)} km',
          iconColor: AppColors.accent,
          delay: 0,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'Distance Stats',
              value: '${profile.totalDistanceKm.toStringAsFixed(2)} km',
              description: 'Cumulative GPS route distance logged on foot across all running sessions.',
              metrics: [
                {
                  'label': 'Lifetime Distance',
                  'val': '${profile.totalDistanceKm.toStringAsFixed(2)} km',
                },
                {
                  'label': 'Completed Runs',
                  'val': totalRuns > 0 ? '$totalRuns runs' : '0 recorded',
                },
                if (totalRuns > 0) ...[
                  {
                    'label': 'Longest Run',
                    'val': '${longestRunKm.toStringAsFixed(2)} km',
                  },
                  {
                    'label': 'Average Run',
                    'val': '${avgRunKm.toStringAsFixed(2)} km',
                  },
                  {'label': 'Average Pace', 'val': avgPaceStr},
                ],
              ],
            );
          },
        ),
        ProfileStatCard(
          icon: Icons.local_fire_department_rounded,
          title: 'Active Streak',
          value: '${profile.currentStreak} days',
          iconColor: AppColors.warning,
          delay: 80,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'Streak Stats',
              value:
                  '${profile.currentStreak} ${profile.currentStreak == 1 ? "day" : "days"}',
              description: 'Daily running momentum. Run and close territory loops every 24-36 hours to maintain your streak.',
              metrics: [
                {
                  'label': 'Active Streak',
                  'val':
                      '${profile.currentStreak} ${profile.currentStreak == 1 ? "day" : "days"}',
                },
                {'label': 'Next Milestone', 'val': nextMilestone},
                {'label': 'Consistency Rule', 'val': 'Daily run or claim'},
              ],
            );
          },
        ),
        ProfileStatCard(
          icon: Icons.terrain_rounded,
          title: 'Total Territory',
          value: territoryVal,
          iconColor: AppColors.accent,
          delay: 160,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'Territory Stats',
              value: '${(totalAreaM2 / 1000000.0).toStringAsFixed(3)} km²',
              description: 'Territory polygons enclosed and permanently claimed on foot.',
              metrics: [
                {
                  'label': 'Captured Polygons',
                  'val': '${captured.length} areas',
                },
                {
                  'label': 'Controlled Area',
                  'val': '${(totalAreaM2 / 1000000.0).toStringAsFixed(3)} km²',
                },
                {
                  'label': 'Square Meters',
                  'val': '${totalAreaM2.toStringAsFixed(0)} m²',
                },
              ],
            );
          },
        ),
        ProfileStatCard(
          icon: Icons.military_tech_rounded,
          title: 'Athlete Tier',
          value: 'Lvl ${profile.level}',
          iconColor: AppColors.accent,
          delay: 240,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'Rank & Tier Stats',
              value: 'Level ${profile.level}',
              description: 'Athlete experience tier. Advance your tier by logging runs and claiming territorial loops.',
              metrics: [
                {'label': 'Current Level', 'val': 'Level ${profile.level}'},
                {
                  'label': 'Tier Progress',
                  'val': '${profile.xp} / $nextLevelXp XP',
                },
                {'label': 'XP to Next Level', 'val': '$remainingXp XP'},
                {
                  'label': 'Badges Earned',
                  'val': '${profile.badges.length} unlocked',
                },
              ],
            );
          },
        ),
      ],
    );
  }
}

class ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final int delay;
  final VoidCallback? onTap;

  const ProfileStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    required this.delay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.br16,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textMuted,
                  size: 14,
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppText.statMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
