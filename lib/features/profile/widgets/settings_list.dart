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
import '../../gallery/design_gallery_screen.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. AUDIO & HAPTICS (Switch 1: Voice Coach, Switch 2: Tactical Haptic Bursts)
        _buildSectionTitle('Audio & Haptics'),
        _buildSettingsGroup([
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_rounded, color: AppColors.accent, size: 20),
            title: Text(
              'Voice Coach Audio Cues',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Milestone distance and pace telemetry announcements',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentContainer,
            value: _voiceCoach.isAudioEnabled,
            onChanged: (val) {
              AppMotion.selectionTick();
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
                  Text(
                    '${(_voiceCoach.volume * 100).round()}%',
                    style: AppText.labelSmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1, color: AppColors.border),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded, color: AppColors.accent, size: 20),
            title: Text(
              'Tactical Haptic Bursts',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Physical vibration pulses upon loop closure and territory claims',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentContainer,
            value: _voiceCoach.isHapticsEnabled,
            onChanged: (val) {
              AppMotion.selectionTick();
              setState(() {
                _voiceCoach.toggleHaptics(val);
              });
            },
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 2. RUN EXPERIENCE (Switch 3: Battery Saver)
        _buildSectionTitle('Run Experience'),
        _buildSettingsGroup([
          SwitchListTile(
            secondary: const Icon(Icons.battery_saver_rounded, color: AppColors.accent, size: 20),
            title: Text(
              'Endurance Battery Saver',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'AMOLED dark HUD, reduced map animations & optimized GPS polling',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentContainer,
            value: BatterySaverService().isBatterySaverEnabled,
            onChanged: (val) {
              AppMotion.selectionTick();
              setState(() {
                BatterySaverService().setBatterySaver(val);
              });
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.notifications_active_rounded,
            title: 'Tactical Radar Alerts',
            subtitle: 'Real-time alerts when rival runners contest your territory',
            onTap: () {
              AppMotion.selectionTick();
              NotificationService().showPermissionPrimerIfNeeded(context, force: true);
            },
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 3. ACCOUNT
        _buildSectionTitle('Account'),
        _buildSettingsGroup([
          ProfileOptionTile(
            icon: Icons.cloud_done_rounded,
            title: widget.firebaseService.isInitialized
                ? 'Cloud Connected (${widget.firebaseService.currentUsername})'
                : 'Offline Local Storage',
            subtitle: widget.firebaseService.isInitialized
                ? 'Telemetry synced to cloud'
                : 'Tap to connect account & sync runs',
            trailing: widget.firebaseService.isInitialized
                ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16)
                : const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
            onTap: widget.onOpenAuth,
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 4. UNITS
        _buildSectionTitle('Measurement Units'),
        _buildSettingsGroup([
          ListTile(
            leading: const Icon(Icons.straighten_rounded, color: AppColors.accent, size: 20),
            title: Text(
              'Distance & Pace Units',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              _voiceCoach.unit == DistanceUnit.metric ? 'Metric (Kilometers, m²)' : 'Imperial (Miles, Acres)',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
            trailing: SegmentedButton<DistanceUnit>(
              segments: const [
                ButtonSegment(value: DistanceUnit.metric, label: Text('KM', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: DistanceUnit.imperial, label: Text('MI', style: TextStyle(fontSize: 11))),
              ],
              selected: {_voiceCoach.unit},
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: AppColors.onAccent,
                foregroundColor: AppColors.textSecondary,
                backgroundColor: AppColors.surface2,
              ),
              onSelectionChanged: (Set<DistanceUnit> selected) {
                AppMotion.selectionTick();
                setState(() {
                  _voiceCoach.setUnit(selected.first);
                });
              },
            ),
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 5. PRIVACY & SAFETY
        _buildSectionTitle('Privacy & Safety'),
        _buildSettingsGroup([
          ProfileOptionTile(
            icon: Icons.shield_rounded,
            title: 'Privacy Zones & Geo-Masking',
            subtitle: 'Exclude home & workplace tracks from public exports',
            onTap: () {
              AppMotion.selectionTick();
              showPrivacyZonesSheet(context);
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.emergency_rounded,
            title: 'Emergency Contact & SOS Beacon',
            subtitle: 'Configure distress SMS recipient and safety credentials',
            onTap: () {
              AppMotion.selectionTick();
              showEmergencyContactDialog(context);
            },
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 6. DATA & OFFLINE
        _buildSectionTitle('Data & Offline'),
        _buildSettingsGroup([
          ProfileOptionTile(
            icon: Icons.download_for_offline_rounded,
            title: 'Offline Map Storage',
            subtitle: 'Pre-download sector tiles for zero-signal running',
            onTap: () {
              AppMotion.selectionTick();
              showOfflineMapsSheet(context);
            },
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 7. ABOUT & PLATFORM
        _buildSectionTitle('About'),
        _buildSettingsGroup([
          ProfileOptionTile(
            icon: Icons.info_outline_rounded,
            title: 'Territory Runner',
            subtitle: 'v2.4.0 • GPS Territory Conquest',
            trailing: const Text(
              'v2.4.0',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            onTap: null,
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.policy_outlined,
            title: 'Open Source Licenses',
            subtitle: 'Software dependencies & attributions',
            onTap: () {
              AppMotion.selectionTick();
              showLicensePage(
                context: context,
                applicationName: 'Territory Runner',
                applicationVersion: '2.4.0',
                applicationLegalese: 'Crafted with athletic precision.',
              );
            },
          ),
          // Developer tools (hidden behind kDebugMode)
          if (kDebugMode) ...[
            const Divider(height: 1, color: AppColors.border),
            ProfileOptionTile(
              icon: Icons.palette_rounded,
              title: 'Design System Gallery (Dev)',
              subtitle: 'Inspect Charcoal + Ember tokens and UI components',
              onTap: () {
                AppMotion.selectionTick();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DesignGalleryScreen()),
                );
              },
            ),
            const Divider(height: 1, color: AppColors.border),
            ProfileOptionTile(
              icon: Icons.refresh_rounded,
              title: 'Reset Local Territories (Dev)',
              subtitle: 'Clears offline polygons to initial state',
              onTap: () async {
                AppMotion.mediumTick();
                await widget.territoryService.resetTerritories();
                if (context.mounted) {
                  AppToast.show(context, 'Territories reset to initial grid');
                }
              },
            ),
          ],
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s4, bottom: AppSpacing.s8),
      child: Text(
        title,
        style: AppText.labelSmall.copyWith(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppSpacing.br16,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.br16,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ProfileOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent, size: 20),
        title: Text(
          title,
          style: AppText.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  )
                : null),
        onTap: onTap,
      ),
    );
  }
}
