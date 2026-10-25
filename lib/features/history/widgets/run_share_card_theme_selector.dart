import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'run_share_card_renderer.dart';

/// Horizontal scrollable pill selector for share card themes.
class RunShareCardThemeSelector extends StatelessWidget {
  final ShareCardTheme selectedTheme;
  final ValueChanged<ShareCardTheme> onThemeChanged;

  const RunShareCardThemeSelector({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildThemePill(
            context,
            ShareCardTheme.athleticDark,
            'Athletic Dark',
          ),
          const SizedBox(width: AppSpacing.s8),
          _buildThemePill(context, ShareCardTheme.cyberVanguard, 'Vanguard'),
          const SizedBox(width: AppSpacing.s8),
          _buildThemePill(context, ShareCardTheme.stealth, 'Stealth'),
        ],
      ),
    );
  }

  Widget _buildThemePill(
    BuildContext context,
    ShareCardTheme theme,
    String label,
  ) {
    final isSelected = selectedTheme == theme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Theme: $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          AppMotion.selectionTick();
          onThemeChanged(theme);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.surface,
            borderRadius: AppSpacing.brFull,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppText.label.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
