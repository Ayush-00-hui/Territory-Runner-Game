import 'package:flutter/material.dart';

import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/motion/motion.dart';

/// Classroom & Viva Demo Lab triggers for simulated real-time GPS scenarios.
class DemoControlsLab extends StatelessWidget {
  final VoidCallback onSimulateLoop;
  final VoidCallback onSimulateRivalCut;
  final VoidCallback onSimulateAnomaly;
  final VoidCallback onSimulateCoachDebrief;
  final VoidCallback onSimulateDecayAndAttack;
  final bool isRivalSimulating;
  final VoidCallback? onToggleRivalSimulation;

  const DemoControlsLab({
    super.key,
    required this.onSimulateLoop,
    required this.onSimulateRivalCut,
    required this.onSimulateAnomaly,
    required this.onSimulateCoachDebrief,
    required this.onSimulateDecayAndAttack,
    this.isRivalSimulating = false,
    this.onToggleRivalSimulation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.science_rounded, color: AppColors.info, size: 20),
            SizedBox(width: AppSpacing.s8),
            Text('CLASSROOM & VIVA DEMO LAB', style: AppText.headingSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        _buildDemoActionTile(
          context: context,
          title: '🎯 Auto-Simulate 400m Loop Conquest',
          subtitle: 'Streams real-time waypoints to trigger loop enclosure & Shoelace area',
          icon: Icons.replay_circle_filled_rounded,
          color: AppColors.mine,
          onTap: onSimulateLoop,
        ),
        _buildDemoActionTile(
          context: context,
          title: '⚔️ Auto-Simulate Rival Territory Cut',
          subtitle: 'Spawns Crimson rival & runs a slicing loop using Clipper2 difference',
          icon: Icons.shield_outlined,
          color: AppColors.rival,
          onTap: onSimulateRivalCut,
        ),
        _buildDemoActionTile(
          context: context,
          title: '🚨 Test Anti-Cheat Speed Anomaly',
          subtitle:
              'Injects vehicle velocity (>40 km/h) to verify Z-score rejection',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          onTap: onSimulateAnomaly,
        ),
        _buildDemoActionTile(
          context: context,
          title: '🤖 Instant Gemini AI Coach Debrief',
          subtitle:
              'Simulates completed 3.5km workout with LLM tactical insights',
          icon: Icons.psychology_rounded,
          color: AppColors.info,
          onTap: onSimulateCoachDebrief,
        ),
        _buildDemoActionTile(
          context: context,
          title: '🛡️ Simulate Decay & Under Attack Alert',
          subtitle: 'Degrades territory to 20% strength & dispatches targeted attack alert',
          icon: Icons.security_update_warning_rounded,
          color: AppColors.error,
          onTap: onSimulateDecayAndAttack,
        ),
        if (onToggleRivalSimulation != null)
          _buildDemoActionTile(
            context: context,
            title: isRivalSimulating
                ? '⏹️ Stop Live Rival Simulation'
                : '🔴 Simulate Live Rival Runner (GPS Stream)',
            subtitle: isRivalSimulating
                ? 'Halt simulated rival movement and breadcrumbs'
                : 'Streams real-time moving rival marker with live trail breadcrumbs',
            icon: isRivalSimulating
                ? Icons.stop_circle_rounded
                : Icons.radar_rounded,
            color: isRivalSimulating ? AppColors.warning : AppColors.rival,
            onTap: onToggleRivalSimulation!,
          ),
      ],
    );
  }

  Widget _buildDemoActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppSpacing.br16,
          onTap: () {
            AppMotion.mediumTick();
            Navigator.pop(context);
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.bodyBold.copyWith(
                          color: color,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        subtitle,
                        style: AppText.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
