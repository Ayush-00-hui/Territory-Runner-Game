import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

enum SocialTab { squad, duels }

/// Header with Syndicate title, refresh button, and Squad/Duels tab switcher.
class SocialHubHeader extends StatelessWidget {
  final SocialTab activeTab;
  final int friendsCount;
  final int activeDuelsCount;
  final ValueChanged<SocialTab> onTabChanged;
  final VoidCallback onRefresh;

  const SocialHubHeader({
    super.key,
    required this.activeTab,
    required this.friendsCount,
    required this.activeDuelsCount,
    required this.onTabChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              const Icon(Icons.hub_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Social Syndicate & Duels',
                  style: AppText.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Refresh Hub',
                onPressed: onRefresh,
              ),
            ],
          ),
        ),

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.brFull,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTab(
                    tab: SocialTab.squad,
                    label: 'Squad ($friendsCount)',
                    icon: Icons.people_rounded,
                  ),
                ),
                Expanded(
                  child: _buildSubTab(
                    tab: SocialTab.duels,
                    label: 'Duels ($activeDuelsCount)',
                    icon: Icons.sports_kabaddi_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTab({
    required SocialTab tab,
    required String label,
    required IconData icon,
  }) {
    final isSelected = activeTab == tab;
    return GestureDetector(
      onTap: () => onTabChanged(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: AppSpacing.brFull,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.onAccent : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.onAccent
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
