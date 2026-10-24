import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Bottom sheet presenting secondary tools during an active or idle run:
/// - Virtual Pacer
/// - Run Goals
/// - Route Suggestions
/// - AMOLED Low-Power Display
/// - Offline Map Tiles
/// - Emergency SOS Beacon
class MapToolsSheet extends StatelessWidget {
  final VoidCallback onOpenPacer;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenRoutePlanner;
  final VoidCallback onToggleAmoled;
  final VoidCallback onOpenOfflineMaps;
  final VoidCallback onTriggerSos;
  final String? activePacerLabel;
  final String? activeGoalLabel;
  final bool isAmoledActive;

  const MapToolsSheet({
    super.key,
    required this.onOpenPacer,
    required this.onOpenGoals,
    required this.onOpenRoutePlanner,
    required this.onToggleAmoled,
    required this.onOpenOfflineMaps,
    required this.onTriggerSos,
    this.activePacerLabel,
    this.activeGoalLabel,
    this.isAmoledActive = false,
  });

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onOpenPacer,
    required VoidCallback onOpenGoals,
    required VoidCallback onOpenRoutePlanner,
    required VoidCallback onToggleAmoled,
    required VoidCallback onOpenOfflineMaps,
    required VoidCallback onTriggerSos,
    String? activePacerLabel,
    String? activeGoalLabel,
    bool isAmoledActive = false,
  }) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => MapToolsSheet(
        onOpenPacer: () {
          Navigator.pop(ctx);
          onOpenPacer();
        },
        onOpenGoals: () {
          Navigator.pop(ctx);
          onOpenGoals();
        },
        onOpenRoutePlanner: () {
          Navigator.pop(ctx);
          onOpenRoutePlanner();
        },
        onToggleAmoled: () {
          Navigator.pop(ctx);
          onToggleAmoled();
        },
        onOpenOfflineMaps: () {
          Navigator.pop(ctx);
          onOpenOfflineMaps();
        },
        onTriggerSos: () {
          Navigator.pop(ctx);
          onTriggerSos();
        },
        activePacerLabel: activePacerLabel,
        activeGoalLabel: activeGoalLabel,
        isAmoledActive: isAmoledActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Run tools',
      subtitle: 'Pacer, goals, route guidance and utilities',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Virtual Pacer
          _ToolTile(
            icon: Icons.speed_rounded,
            title: 'Virtual pacer',
            subtitle: activePacerLabel ?? 'Select target split pace',
            accentColor: AppColors.accent,
            onTap: onOpenPacer,
          ),
          const SizedBox(height: AppSpacing.s8),

          // 2. Run Goals
          _ToolTile(
            icon: Icons.flag_rounded,
            title: 'Run goals',
            subtitle: activeGoalLabel ?? 'Set distance, time or area targets',
            accentColor: AppColors.gold,
            onTap: onOpenGoals,
          ),
          const SizedBox(height: AppSpacing.s8),

          // 3. Route Suggestions
          _ToolTile(
            icon: Icons.alt_route_rounded,
            title: 'Route suggestions',
            subtitle: 'Suggested closed loops for territory capture',
            accentColor: AppColors.info,
            onTap: onOpenRoutePlanner,
          ),
          const SizedBox(height: AppSpacing.s8),

          // 4. Low-Power Display
          _ToolTile(
            icon: Icons.battery_saver_rounded,
            title: 'Low-power display',
            subtitle: isAmoledActive
                ? 'Active (pure black AMOLED HUD)'
                : 'Save battery with high-contrast black HUD',
            accentColor: AppColors.accent,
            onTap: onToggleAmoled,
          ),
          const SizedBox(height: AppSpacing.s8),

          // 5. Offline Maps
          _ToolTile(
            icon: Icons.download_rounded,
            title: 'Offline maps',
            subtitle: 'Preload local tiles for offline running',
            accentColor: AppColors.textSecondary,
            onTap: onOpenOfflineMaps,
          ),
          const SizedBox(height: AppSpacing.s8),

          // 6. Emergency SOS Trigger
          _ToolTile(
            icon: Icons.emergency_rounded,
            title: 'Emergency SOS',
            subtitle: 'Trigger distress alert with GPS coordinates',
            accentColor: AppColors.error,
            isDestructive: true,
            onTap: onTriggerSos,
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title: $subtitle',
      child: InkWell(
        onTap: () {
          AppMotion.lightTick();
          onTap();
        },
        borderRadius: AppRadius.br16,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.06)
                : AppColors.surface2,
            borderRadius: AppRadius.br16,
            border: Border.all(
              color: isDestructive
                  ? AppColors.error.withValues(alpha: 0.25)
                  : AppColors.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.14)
                      : accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(icon, color: accentColor, size: 20)),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppText.bodyMedium.copyWith(
                        color: isDestructive
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.6)
                    : AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
