import 'package:flutter/material.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/motion/motion.dart';

/// Mode Tabs Switcher: Run | Explore | Leaderboard | Challenges
class ModeTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<String> tabs;

  const ModeTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.tabs = const ['Run', 'Explore', 'Leaderboard', 'Challenges'],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: AppSpacing.br16,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                AppMotion.lightTick();
                onTabSelected(index);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppMotion.duration(context, AppMotion.fast),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface2 : Colors.transparent,
                  borderRadius: AppSpacing.br12,
                  border: isSelected
                      ? Border.all(color: AppColors.border, width: 1.0)
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: isSelected
                        ? AppText.label.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          )
                        : AppText.label.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
