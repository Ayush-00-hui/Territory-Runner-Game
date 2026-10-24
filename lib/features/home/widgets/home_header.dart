import 'package:flutter/material.dart';

import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';

/// Executive Athlete Home Header
/// Features avatar with thin athletic level ring, greeting, callsign,
/// and the unified CombinedStatusIndicator (GPS + Sync).
/// Streak and faction are moved to Profile per H3.
class HomeHeader extends StatelessWidget {
  final RunnerProfile profile;
  final double? accuracyMeters;
  final bool isGpsSearching;

  const HomeHeader({
    super.key,
    required this.profile,
    this.accuracyMeters,
    this.isGpsSearching = false,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final callsign = profile.username.isNotEmpty ? profile.username : 'Runner';
    final int nextLevelXp = profile.level * 250;
    final double levelProgress = (profile.xp / nextLevelXp).clamp(0.05, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle with thin athletic level progression ring (replaces Level chip)
        ProgressRing(
          progress: levelProgress,
          size: 50,
          strokeWidth: 2.5,
          progressColor: AppColors.accent,
          trackColor: AppColors.surface2,
          center: Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: Center(
              child: Text(
                callsign.isNotEmpty ? callsign[0].toUpperCase() : 'R',
                style: AppText.titleMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),

        // Greeting, Callsign, and Level indicator
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_greeting(), style: AppText.labelSmall),
              const SizedBox(height: AppSpacing.s2),
              Text(
                callsign,
                style: AppText.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'Level ${profile.level}',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Unified calm status indicator: combines GPS and Cloud Sync (dot + label, tap for details)
        CombinedStatusIndicator(
          accuracyMeters: accuracyMeters,
          isGpsSearching: isGpsSearching,
        ),
      ],
    );
  }
}
