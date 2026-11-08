import 'package:flutter/material.dart';

import '../../../models/territory.dart';
import '../../../services/notification_service.dart';
import '../../../ui/ui.dart';

/// Renders a calm, glanceable row displaying territories that have decayed below 50% strength.
/// Hidden if all claimed territories remain fortified (> 50%).
class NeedsDefendingRow extends StatelessWidget {
  final List<Territory> territories;
  final ValueChanged<String>? onTerritoryTap;

  const NeedsDefendingRow({
    super.key,
    required this.territories,
    this.onTerritoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weakTerritories = territories
        .where((t) => t.computeCurrentStrength(now: now) <= 50.0)
        .toList();

    if (weakTerritories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by lowest strength first
    weakTerritories.sort(
      (a, b) => a
          .computeCurrentStrength(now: now)
          .compareTo(b.computeCurrentStrength(now: now)),
    );

    final weakest = weakTerritories.first;
    final strengthPercent = weakest.computeCurrentStrength(now: now).round();
    final areaText = weakest.areaSqMeters >= 10000
        ? '${(weakest.areaSqMeters / 1000000.0).toStringAsFixed(2)} km²'
        : '${weakest.areaSqMeters.toStringAsFixed(0)} m²';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s16),
        const SectionHeader(title: 'Needs defending'),
        const SizedBox(height: AppSpacing.s8),
        Semantics(
          button: true,
          label:
              'Territory needs defending, $areaText, $strengthPercent percent strength. Tap to view on map.',
          child: Material(
            color: AppColors.surface,
            borderRadius: AppSpacing.br16,
            child: InkWell(
              onTap: () {
                if (onTerritoryTap != null) {
                  onTerritoryTap!(weakest.id);
                } else {
                  NotificationService().simulateAttackedTerritoryTap(
                    weakest.id,
                  );
                }
              },
              borderRadius: AppSpacing.br16,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s14),
                decoration: BoxDecoration(
                  borderRadius: AppSpacing.br16,
                  border: Border.all(
                    color: strengthPercent <= 30
                        ? AppColors.error.withValues(alpha: 0.4)
                        : AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            (strengthPercent <= 30
                                    ? AppColors.error
                                    : AppColors.warning)
                                .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: strengthPercent <= 30
                            ? AppColors.error
                            : AppColors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                areaText,
                                style: AppText.bodyBold.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (strengthPercent <= 30
                                              ? AppColors.error
                                              : AppColors.warning)
                                          .withValues(alpha: 0.15),
                                  borderRadius: AppSpacing.br8,
                                ),
                                child: Text(
                                  '$strengthPercent% strength',
                                  style: AppText.labelSmall.copyWith(
                                    color: strengthPercent <= 30
                                        ? AppColors.error
                                        : AppColors.warning,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'A short loop through this area will restore it.',
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
