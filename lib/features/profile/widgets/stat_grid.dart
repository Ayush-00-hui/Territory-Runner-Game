import 'package:flutter/material.dart';

import '../../gameplay/territory_service.dart';
import '../../../models/runner_profile.dart';
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
              description: 'Cumulative GPS route distance logged on foot.',
              metrics: [
                {
                  'label': 'Lifetime Distance',
                  'val': '${profile.totalDistanceKm.toStringAsFixed(2)} km',
                },
                {
                  'label': 'Weekly Estimated',
                  'val':
                      '${(profile.totalDistanceKm / 4).toStringAsFixed(1)} km/wk',
                },
                {'label': 'Pace Rating', 'val': 'Active Runner'},
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
              value: '${profile.currentStreak} days',
              description: 'Daily running consistency. Running and claiming territory keeps your streak active.',
              metrics: [
                {
                  'label': 'Active Streak Days',
                  'val': '${profile.currentStreak} days',
                },
                {
                  'label': 'Streak Multiplier Bonus',
                  'val': '+${(profile.currentStreak * 2).clamp(0, 50)}% XP',
                },
                {'label': 'Status', 'val': 'Active Momentum'},
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
              description: 'Territory polygons permanently claimed on foot.',
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
              description: 'Athlete experience tier. Level up as you run and claim territory.',
              metrics: [
                {'label': 'Current Level', 'val': 'Level ${profile.level}'},
                {
                  'label': 'Experience Points',
                  'val': '${profile.xp} / ${profile.level * 250} XP',
                },
                {
                  'label': 'Perks Unlocked',
                  'val': 'Territory Master, Speed Burst',
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
          AppMotion.selectionTick();
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
