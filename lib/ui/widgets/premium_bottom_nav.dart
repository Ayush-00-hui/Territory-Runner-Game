import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// 5-destination athletic bottom navigation bar:
/// [Home] | [Activity] | [Run] (centre, primary) | [Compete] | [Profile].
///
/// Rules enforced:
/// - Center Run is always the primary action button and NEVER renders as a selected tab.
/// - Selected tab = icon + label in accent color with a subtle 2px top indicator.
/// - Labels always visible.
/// - Minimum 48 dp touch targets.
/// - Safe-area aware with haptic feedback on navigation ticks.
class PremiumBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onStartRun;
  final bool isRunActive;

  const PremiumBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onStartRun,
    this.isRunActive = false,
  });

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label tab',
        child: GestureDetector(
          onTap: () {
            if (selectedIndex != index) {
              AppMotion.selectionTick();
              onTabSelected(index);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 2px active indicator bar
                Container(
                  height: 2.0,
                  width: 20.0,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    borderRadius: AppRadius.brFull,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  icon,
                  size: 20.0,
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppText.caption.copyWith(
                    color: isSelected ? AppColors.accent : AppColors.textMuted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: 60.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Home
              _buildTabItem(index: 0, icon: Icons.home_rounded, label: 'Home'),

              // 2. Activity (History + Personal Records)
              _buildTabItem(
                index: 1,
                icon: Icons.timeline_rounded,
                label: 'Activity',
              ),

              // 3. Centre Primary Run Action (Never a selected tab)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                child: Semantics(
                  button: true,
                  label: isRunActive ? 'Resume run' : 'Start run',
                  child: GestureDetector(
                    onTap: () {
                      onStartRun();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.onAccent.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isRunActive
                              ? Icons.play_arrow_rounded
                              : Icons.directions_run_rounded,
                          color: AppColors.onAccent,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Compete (League, Leaderboards, Friends, Duels)
              _buildTabItem(
                index: 3,
                icon: Icons.military_tech_rounded,
                label: 'Compete',
              ),

              // 5. Profile & Settings
              _buildTabItem(
                index: 4,
                icon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
