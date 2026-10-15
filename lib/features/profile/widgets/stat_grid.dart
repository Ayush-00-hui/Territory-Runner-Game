import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final double totalAreaM2 = captured.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    final String territoryVal = totalAreaM2 >= 10000
        ? '${(totalAreaM2 / 1000000.0).toStringAsFixed(2)} KM²'
        : '${totalAreaM2.toStringAsFixed(0)} M²';

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.s12,
      crossAxisSpacing: AppSpacing.s12,
      childAspectRatio: 1.45,
      children: [
        ProfileStatCard(
          icon: Icons.route_rounded,
          title: 'TOTAL DISTANCE',
          value: '${profile.totalDistanceKm.toStringAsFixed(1)} KM',
          iconColor: AppColors.accent,
          delay: 0,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'DISTANCE TELEMETRY',
              value: '${profile.totalDistanceKm.toStringAsFixed(2)} KM',
              description: 'Cumulative GPS route distance logged on foot across urban and wilderness sectors.',
              metrics: [
                {'label': 'Lifetime Distance', 'val': '${profile.totalDistanceKm.toStringAsFixed(2)} km'},
                {'label': 'Weekly Estimated', 'val': '${(profile.totalDistanceKm / 4).toStringAsFixed(1)} km/wk'},
                {'label': 'Pace Rating', 'val': 'Active Runner'},
              ],
            );
          },
        ),
        ProfileStatCard(
          icon: Icons.local_fire_department_rounded,
          title: 'ACTIVE STREAK',
          value: '${profile.currentStreak} DAYS',
          iconColor: AppColors.secondary,
          delay: 80,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'STREAK TELEMETRY',
              value: '${profile.currentStreak} DAYS',
              description: 'Continuous daily conquest momentum. Running and claiming territory daily keeps your streak active.',
              metrics: [
                {'label': 'Active Streak Days', 'val': '${profile.currentStreak} days'},
                {'label': 'Streak Multiplier Bonus', 'val': '+${(profile.currentStreak * 2).clamp(0, 50)}% XP'},
                {'label': 'Status', 'val': 'Active Momentum 🔥'},
              ],
            );
          },
        ),
        ProfileStatCard(
          icon: Icons.terrain_rounded,
          title: 'TOTAL TERRITORY',
          value: territoryVal,
          iconColor: AppColors.accent,
          delay: 160,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'TERRITORY TELEMETRY',
              value: '${(totalAreaM2 / 1000000.0).toStringAsFixed(3)} KM²',
              description: 'Post-union sovereign territory polygons permanently claimed on foot.',
              metrics: [
                {'label': 'Captured Polygons', 'val': '${captured.length} sectors'},
                {'label': 'Controlled Area', 'val': '${(totalAreaM2 / 1000000.0).toStringAsFixed(3)} km²'},
                {'label': 'Square Meters', 'val': '${totalAreaM2.toStringAsFixed(0)} m²'},
              ],
            );
          },
        ),
        ProfileStatCard(
          icon: Icons.military_tech_rounded,
          title: 'ATHLETE TIER',
          value: 'LVL ${profile.level}',
          iconColor: AppColors.accent,
          delay: 240,
          onTap: () {
            showStatDetailModal(
              context,
              title: 'RANK & TIER TELEMETRY',
              value: 'LEVEL ${profile.level}',
              description: 'Athlete experience tier. Progressing tiers grants improved sector claim speed and prestige insignia.',
              metrics: [
                {'label': 'Current Level', 'val': 'Level ${profile.level}'},
                {'label': 'Experience Points', 'val': '${profile.xp} / ${profile.level * 250} XP'},
                {'label': 'Perks Unlocked', 'val': 'Territory Sovereign, Speed Burst'},
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.selectionClick();
            onTap!();
          }
        },
        child: Container(
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
                  Icon(icon, color: iconColor, size: 22),
                  const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 14),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: AppText.statMedium.copyWith(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                title,
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
