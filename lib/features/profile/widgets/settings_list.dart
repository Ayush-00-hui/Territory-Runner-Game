import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../coach/voice_coach_service.dart';
import '../../gameplay/territory_service.dart';
import '../../../services/battery_saver_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../ui/ui.dart';
import 'emergency_contact_dialog.dart';
import 'offline_maps_sheet.dart';
import 'privacy_zones_sheet.dart';

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
                'Milestone distance & pace announcements via TTS',
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
            if (_voiceCoach.isAudioEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up_rounded, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Text('Volume', style: AppText.bodySmall.copyWith(color: AppColors.textMuted)),
                    Expanded(
                      child: Slider(
                        value: _voiceCoach.volume,
                        activeColor: AppColors.accent,
                        inactiveColor: AppColors.surface2,
                        onChanged: (v) {
                          setState(() {
                            _voiceCoach.setVolume(v);
                          });
                        },
                      ),
                    ),
                    Text('${(_voiceCoach.volume * 100).round()}%', style: AppText.label.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
            const Divider(height: 1, color: AppColors.border),

            // Units Setting (Metric / Imperial)
            ListTile(
              leading: const Icon(Icons.straighten_rounded, color: AppColors.accent, size: 22),
              title: Text(
                'Measurement Units',
                style: AppText.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                _voiceCoach.unit == DistanceUnit.metric ? 'Metric (Kilometers, m²)' : 'Imperial (Miles, Acres)',
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5),
              ),
              trailing: SegmentedButton<DistanceUnit>(
                segments: const [
                  ButtonSegment(value: DistanceUnit.metric, label: Text('KM', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: DistanceUnit.imperial, label: Text('MI', style: TextStyle(fontSize: 11))),
                ],
                selected: {_voiceCoach.unit},
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.accent,
                  selectedForegroundColor: Colors.black,
                  foregroundColor: Colors.white70,
                  backgroundColor: AppColors.surface,
                ),
                onSelectionChanged: (Set<DistanceUnit> selected) {
                  AppMotion.lightTick();
                  setState(() {
                    _voiceCoach.setUnit(selected.first);
                  });
                },
              ),
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

          // Endurance Battery Saver Mode
          SwitchListTile(
            secondary: const Icon(Icons.battery_saver_rounded, color: AppColors.accent, size: 22),
            title: Text(
              'Endurance Battery Saver',
              style: AppText.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'AMOLED black HUD, suppresses map animations & optimizes GPS polling',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5),
            ),
            activeThumbColor: AppColors.accent,
            value: BatterySaverService().isBatterySaverEnabled,
            onChanged: (val) {
              AppMotion.lightTick();
              setState(() {
                BatterySaverService().setBatterySaver(val);
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

          // Tactical Radar Push Alerts
          ProfileOptionTile(
            icon: Icons.notifications_active_rounded,
            title: 'Tactical Radar Push Alerts',
            subtitle: 'Real-time notifications when rival runners carve your sectors',
            onTap: () {
              AppMotion.lightTick();
              NotificationService().showPermissionPrimerIfNeeded(context, force: true);
            },
          ),
          const Divider(height: 1, color: AppColors.border),

          // Privacy Zones & Geo-Masking
          ProfileOptionTile(
            icon: Icons.shield_rounded,
            title: 'Privacy Zones & Geo-Masking',
            subtitle: 'Exclude home & workplace tracks from public exports',
            onTap: () {
              AppMotion.lightTick();
              showPrivacyZonesSheet(context);
            },
          ),
          const Divider(height: 1, color: AppColors.border),

          // Emergency Contact & SOS Beacon
          ProfileOptionTile(
            icon: Icons.emergency_rounded,
            title: 'Emergency Contact & SOS Beacon',
            subtitle: 'Configure distress SMS recipient and safety credentials',
            onTap: () {
              AppMotion.lightTick();
              showEmergencyContactDialog(context);
            },
          ),
          const Divider(height: 1, color: AppColors.border),

          // Offline Map Storage & Pre-caching
          ProfileOptionTile(
            icon: Icons.download_for_offline_rounded,
            title: 'Offline Map Storage & Pre-caching',
            subtitle: 'Pre-download sector tiles for zero-signal offline running',
            onTap: () {
              AppMotion.lightTick();
              showOfflineMapsSheet(context);
            },
          ),
          // Reset Dev Mode (Only visible in debug builds)
          if (kDebugMode) ...[
            const Divider(height: 1, color: AppColors.border),
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
