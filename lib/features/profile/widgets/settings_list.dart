import 'package:flutter/material.dart';
import '../../coach/voice_coach_service.dart';
import '../../gameplay/territory_service.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';

class ProfileSettingsList extends StatefulWidget {
  final FirebaseService firebaseService;
  final TerritoryService territoryService;
  final VoidCallback onOpenAuth;

  const ProfileSettingsList({
    super.key,
    required this.firebaseService,
    required this.territoryService,
    required this.onOpenAuth,
  });

  @override
  State<ProfileSettingsList> createState() => _ProfileSettingsListState();
}

class _ProfileSettingsListState extends State<ProfileSettingsList> {
  final VoiceCoachService _voiceCoach = VoiceCoachService();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppSpacing.br20,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.br20,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Voice Coach Toggle
            SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_rounded, color: AppColors.accent, size: 22),
            title: Text(
              'Voice Coach Audio Cues',
              style: AppText.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Milestone distance & pace announcements',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5),
            ),
            activeThumbColor: AppColors.accent,
            value: _voiceCoach.isAudioEnabled,
            onChanged: (val) {
              AppMotion.lightTick();
              setState(() {
                _voiceCoach.toggleAudio(val);
              });
            },
          ),
          const Divider(height: 1, color: AppColors.border),

          // Haptics Toggle
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded, color: AppColors.accent, size: 22),
            title: Text(
              'Tactical Haptic Bursts',
              style: AppText.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Physical vibration pulses upon loop closure',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5),
            ),
            activeThumbColor: AppColors.accent,
            value: _voiceCoach.isHapticsEnabled,
            onChanged: (val) {
              AppMotion.lightTick();
              setState(() {
                _voiceCoach.toggleHaptics(val);
              });
            },
          ),
          const Divider(height: 1, color: AppColors.border),

          // Cloud Sync Option
          ProfileOptionTile(
            icon: Icons.cloud_done_rounded,
            title: widget.firebaseService.isInitialized
                ? 'Cloud Connected (${widget.firebaseService.currentUsername})'
                : 'Offline Local Storage (Tap to Sync)',
            subtitle: 'Secure profile & route cloud backups',
            onTap: widget.onOpenAuth,
          ),
          const Divider(height: 1, color: AppColors.border),

          // Reset Dev Mode
          ProfileOptionTile(
            icon: Icons.refresh_rounded,
            title: 'Reset Local Territories (Dev Mode)',
            subtitle: 'Clears offline polygons to initial state',
            onTap: () async {
              AppMotion.mediumTick();
              await widget.territoryService.resetTerritories();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Territories reset to initial grid.')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
}

class ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const ProfileOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent, size: 22),
        title: Text(
          title,
          style: AppText.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5),
              )
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}
