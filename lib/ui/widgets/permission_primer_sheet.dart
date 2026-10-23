import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_sheet.dart';

enum PermissionPrimerType { notifications, location, backgroundLocation }

/// Athletic system permission primer bottom sheet.
/// Educates the athlete on why permissions are required before invoking native OS dialogs.
class PermissionPrimerSheet extends StatelessWidget {
  final PermissionPrimerType type;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const PermissionPrimerSheet({
    super.key,
    this.type = PermissionPrimerType.notifications,
    this.onAccept,
    this.onDecline,
  });

  const PermissionPrimerSheet.notifications({
    super.key,
    this.onAccept,
    this.onDecline,
  }) : type = PermissionPrimerType.notifications;

  const PermissionPrimerSheet.location({
    super.key,
    this.onAccept,
    this.onDecline,
  }) : type = PermissionPrimerType.location;

  const PermissionPrimerSheet.backgroundLocation({
    super.key,
    this.onAccept,
    this.onDecline,
  }) : type = PermissionPrimerType.backgroundLocation;

  /// Helper to display this primer as a standardized AppSheet.
  static Future<bool> show(
    BuildContext context, {
    PermissionPrimerType type = PermissionPrimerType.notifications,
  }) async {
    final result = await AppSheet.show<bool?>(
      context: context,
      builder: (ctx) => PermissionPrimerSheet(
        type: type,
        onAccept: () => Navigator.of(ctx).pop(true),
        onDecline: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final config = _PrimerConfig.forType(type);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s20,
        AppSpacing.s24,
        AppSpacing.s32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.disabled,
                borderRadius: AppRadius.brFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Header Icon & Title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  config.headerIcon,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.title,
                      style: AppText.headingSmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.subtitle,
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 9.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),

          Text(
            config.description,
            style: AppText.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(height: AppSpacing.s16),

          // Features bullet list
          for (final feature in config.features) ...[
            _buildFeatureRow(feature.icon, feature.title, feature.description),
            const SizedBox(height: AppSpacing.s10),
          ],

          const SizedBox(height: AppSpacing.s14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br14,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (onDecline != null) {
                      onDecline!();
                    } else {
                      Navigator.of(context).pop(false);
                    }
                  },
                  child: Text(
                    config.secondaryButtonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br14,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (onAccept != null) {
                      onAccept!();
                    } else {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: Text(
                    config.primaryButtonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.bodyBold.copyWith(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                description,
                style: AppText.bodySmall.copyWith(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem(this.icon, this.title, this.description);
}

class _PrimerConfig {
  final IconData headerIcon;
  final String title;
  final String subtitle;
  final String description;
  final List<_FeatureItem> features;
  final String primaryButtonText;
  final String secondaryButtonText;

  const _PrimerConfig({
    required this.headerIcon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.features,
    required this.primaryButtonText,
    required this.secondaryButtonText,
  });

  factory _PrimerConfig.forType(PermissionPrimerType type) {
    switch (type) {
      case PermissionPrimerType.notifications:
        return const _PrimerConfig(
          headerIcon: Icons.notifications_active_rounded,
          title: 'Territory alerts',
          subtitle: 'Live run updates',
          description: 'Nearby runners can challenge your claimed territories. Enable alerts to receive instant notifications when your territory is contested.',
          features: [
            _FeatureItem(
              Icons.shield_rounded,
              'Nearby runner alerts',
              'Instant notifications when a rival runs through your territory',
            ),
            _FeatureItem(
              Icons.gps_fixed_rounded,
              'Direct map deep-link',
              'Tap notification to immediately center and view on map',
            ),
            _FeatureItem(
              Icons.military_tech_rounded,
              'Weekly League Cutoffs',
              'Alerts when promotion or relegation zones shift',
            ),
          ],
          primaryButtonText: 'Enable alerts',
          secondaryButtonText: 'Maybe later',
        );

      case PermissionPrimerType.location:
        return const _PrimerConfig(
          headerIcon: Icons.gps_fixed_rounded,
          title: 'High-precision GPS',
          subtitle: 'Territory mapping',
          description: 'Territory Runner requires location access to track your running path, calculate enclosed loops, and map your territory. Data stays on your device.',
          features: [
            _FeatureItem(
              Icons.polyline_rounded,
              'Sub-Meter Loop Enclosure',
              'Calculates closed loops accurately without GPS jitter',
            ),
            _FeatureItem(
              Icons.speed_rounded,
              'Real-Time Pace & Stats',
              'Live split times, stride cadence, and elevation metrics',
            ),
            _FeatureItem(
              Icons.shield_outlined,
              'Strict Athlete Privacy',
              'Automated privacy zones mask home and office locations',
            ),
          ],
          primaryButtonText: 'Grant GPS access',
          secondaryButtonText: 'Maybe later',
        );

      case PermissionPrimerType.backgroundLocation:
        return const _PrimerConfig(
          headerIcon: Icons.screen_lock_portrait_rounded,
          title: 'Background tracking',
          subtitle: 'Continuous run tracking',
          description: 'To record loops while your phone is locked in your pocket or when using AMOLED battery saver, background location access is required. No location is logged when not running.',
          features: [
            _FeatureItem(
              Icons.lock_clock_rounded,
              'Locked-Screen Run Capture',
              'Run with screen turned off to save battery without losing path points',
            ),
            _FeatureItem(
              Icons.battery_saver_rounded,
              'AMOLED Minimalist Display',
              'Seamlessly pairs with black-out AMOLED HUD during active runs',
            ),
            _FeatureItem(
              Icons.restore_rounded,
              'Autonomous Run Recovery',
              'Restores state if OS suspends app during a run',
            ),
          ],
          primaryButtonText: 'Allow background GPS',
          secondaryButtonText: 'Maybe later',
        );
    }
  }
}
