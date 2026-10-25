import 'package:flutter/material.dart';

import '../../../services/user_settings_service.dart';
import '../../../ui/ui.dart';

/// Displays the calm, plain-language Live Visibility configuration sheet.
void showLiveVisibilitySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.r16),
    ),
    builder: (ctx) => const LiveVisibilitySheetContent(),
  );
}

class LiveVisibilitySheetContent extends StatefulWidget {
  const LiveVisibilitySheetContent({super.key});

  @override
  State<LiveVisibilitySheetContent> createState() =>
      _LiveVisibilitySheetContentState();
}

class _LiveVisibilitySheetContentState
    extends State<LiveVisibilitySheetContent> {
  final UserSettingsService _settings = UserSettingsService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final current = _settings.liveVisibility;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s16,
            AppSpacing.s20,
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
                  margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'Live Location Visibility',
                    style: AppText.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Control who can observe your live position on the map while you are running. Location sharing is server-enforced and defaults to off.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildOption(
                visibility: LiveVisibility.off,
                title: 'Off (Recommended)',
                description: 'Your live location is never broadcast or delivered to anyone.',
                isSelected: current == LiveVisibility.off,
              ),
              const Divider(height: 1, color: AppColors.border),
              _buildOption(
                visibility: LiveVisibility.friends,
                title: 'Friends only',
                description: 'Only accepted friends can see your live position during active runs.',
                isSelected: current == LiveVisibility.friends,
              ),
              const Divider(height: 1, color: AppColors.border),
              _buildOption(
                visibility: LiveVisibility.nearby,
                title: 'Nearby runners',
                description: 'Nearby runners can see your position coarsened to ~25 m with a 5-second delay. Speed and heading are never shared.',
                isSelected: current == LiveVisibility.nearby,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption({
    required LiveVisibility visibility,
    required String title,
    required String description,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        await _settings.setLiveVisibility(visibility);
        if (mounted) setState(() {});
      },
      borderRadius: AppRadius.br8,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s12,
          horizontal: AppSpacing.s4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
