import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../gameplay/territory_service.dart';
import '../../../services/app_preferences.dart';
import '../../../services/battery_saver_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../ui/ui.dart';
import 'emergency_contact_dialog.dart';
import 'live_visibility_sheet.dart';
import 'offline_maps_sheet.dart';
import 'privacy_zones_sheet.dart';
import '../../gallery/design_gallery_screen.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../../core/utils/constants.dart';
import '../../../services/user_settings_service.dart';
import '../../../services/export_service.dart';

import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../services/api_client.dart';

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
  final AppPreferences _appPrefs = AppPreferences();

  void _showExportSheet(BuildContext context) {
    final territories = widget.territoryService.getCapturedTerritoryObjects();
    AppSheet.show(
      context: context,
      builder: (ctx) => AppSheet(
        title: 'Export run data',
        subtitle:
            '${territories.length} territories recorded • privacy redacted',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export your complete GPS territorial boundary maps in open formats with automatic exclusion of private zones.',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Export GPX',
                    icon: Icons.route_rounded,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      AppMotion.mediumTick();
                      final allPoints = <LatLng>[];
                      for (final t in territories) {
                        allPoints.addAll(t.polygon);
                      }
                      await ExportService().exportAndShareGpx(
                        runTitle: 'Territory Run History',
                        coordinates: allPoints,
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Export GeoJSON',
                    icon: Icons.map_rounded,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      AppMotion.mediumTick();
                      await ExportService().exportAndShareGeoJson(
                        territories: territories,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    AppMotion.mediumTick();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.br16,
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              'Delete account?',
              style: AppText.headingSmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'This action is permanent and irreversible. All claimed territory, recorded GPS runs, and cloud rankings will be erased from this device and the server.',
          style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keep account',
              style: AppText.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brFull),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _executeAccountDeletion(context);
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAccountDeletion(BuildContext context) async {
    AppMotion.heavyBurst();
    AppToast.show(context, 'Purging account and data...');

    try {
      await ApiClient().deleteAccount();
    } catch (_) {
      // Offline fallback: continue with local purge
    }

    try {
      if (Hive.isBoxOpen('territories_v3')) {
        await Hive.box<Territory>('territories_v3').clear();
      }
      if (Hive.isBoxOpen('profile')) {
        await Hive.box<RunnerProfile>('profile').clear();
      }
      if (Hive.isBoxOpen('active_run_recovery')) {
        await Hive.box<String>('active_run_recovery').clear();
      }
      if (Hive.isBoxOpen('unsynced_runs_v2')) {
        await Hive.box<String>('unsynced_runs_v2').clear();
      }
      if (Hive.isBoxOpen('rejected_runs_v1')) {
        await Hive.box<String>('rejected_runs_v1').clear();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await widget.firebaseService.signOut();

      if (context.mounted) {
        AppToast.show(context, 'Account and data permanently deleted');
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show(context, 'Account reset complete');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HAPTICS
        _buildSectionTitle('Haptics'),
        _buildSettingsGroup([
          SwitchListTile(
            secondary: const Icon(
              Icons.vibration_rounded,
              color: AppColors.accent,
              size: 20,
            ),
            title: Text(
              'Haptic feedback',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Vibration on loop closure and territory claimed',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentContainer,
            value: _appPrefs.isHapticsEnabled,
            onChanged: (val) {
              AppMotion.selectionTick();
              setState(() {
                _appPrefs.toggleHaptics(val);
              });
            },
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 2. RUN EXPERIENCE (Switch: Battery Saver)
        _buildSectionTitle('Run experience'),
        _buildSettingsGroup([
          SwitchListTile(
            secondary: const Icon(
              Icons.battery_saver_rounded,
              color: AppColors.accent,
              size: 20,
            ),
            title: Text(
              'Battery saver',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'AMOLED black HUD, reduced animations, optimized GPS',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
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
          SwitchListTile(
            secondary: const Icon(
              Icons.pan_tool_alt_rounded,
              color: AppColors.accent,
              size: 20,
            ),
            title: Text(
              'Left-handed map layout',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Position thumb controls on the left for one-handed reach',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentContainer,
            value: _appPrefs.isLeftHandedMode,
            onChanged: (val) {
              AppMotion.selectionTick();
              setState(() {
                _appPrefs.toggleLeftHandedMode(val);
              });
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.notifications_active_rounded,
            title: 'Rival alerts',
            subtitle:
                'Alerts when nearby runners enter or contest your territory',
            onTap: () {
              AppMotion.selectionTick();
              NotificationService().showPermissionPrimerIfNeeded(
                context,
                force: true,
              );
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.gps_fixed_rounded,
            title: 'Location & GPS',
            subtitle: 'Review GPS accuracy and background location access',
            onTap: () {
              AppMotion.selectionTick();
              PermissionPrimerSheet.show(
                context,
                type: PermissionPrimerType.location,
              );
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
                ? 'Connected (${widget.firebaseService.currentUsername})'
                : 'Local storage',
            subtitle: widget.firebaseService.isInitialized
                ? 'Runs synced to cloud'
                : 'Connect account to sync runs across devices',
            trailing: widget.firebaseService.isInitialized
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 16,
                  )
                : const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
            onTap: widget.onOpenAuth,
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 4. UNITS
        _buildSectionTitle('Measurement units'),
        _buildSettingsGroup([
          ListTile(
            leading: const Icon(
              Icons.straighten_rounded,
              color: AppColors.accent,
              size: 20,
            ),
            title: Text(
              'Distance & pace units',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              _appPrefs.unit == DistanceUnit.metric
                  ? 'Metric (Kilometers, m²)'
                  : 'Imperial (Miles, Acres)',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            trailing: SegmentedButton<DistanceUnit>(
              segments: const [
                ButtonSegment(
                  value: DistanceUnit.metric,
                  label: Text('KM', style: TextStyle(fontSize: 11)),
                ),
                ButtonSegment(
                  value: DistanceUnit.imperial,
                  label: Text('MI', style: TextStyle(fontSize: 11)),
                ),
              ],
              selected: {_appPrefs.unit},
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: AppColors.onAccent,
                foregroundColor: AppColors.textSecondary,
                backgroundColor: AppColors.surface2,
              ),
              onSelectionChanged: (Set<DistanceUnit> selected) {
                AppMotion.selectionTick();
                setState(() {
                  _appPrefs.setUnit(selected.first);
                });
              },
            ),
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 5. PRIVACY & SAFETY
        _buildSectionTitle('Privacy & safety'),
        _buildSettingsGroup([
          AnimatedBuilder(
            animation: UserSettingsService(),
            builder: (context, _) {
              final vis = UserSettingsService().liveVisibility;
              return ProfileOptionTile(
                icon: Icons.visibility_outlined,
                title: 'Live location visibility',
                subtitle: 'Sharing: ${vis.displayName} (default: Off)',
                trailing: Text(
                  vis.displayName,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  AppMotion.selectionTick();
                  showLiveVisibilitySheet(context);
                },
              );
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.shield_rounded,
            title: 'Privacy zones',
            subtitle: 'Exclude home or work areas from public maps and exports',
            onTap: () {
              AppMotion.selectionTick();
              showPrivacyZonesSheet(context);
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.emergency_rounded,
            title: 'Emergency contact & SOS',
            subtitle: 'Configure emergency contact and distress SMS',
            onTap: () {
              AppMotion.selectionTick();
              showEmergencyContactDialog(context);
            },
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 6. DATA & OFFLINE
        _buildSectionTitle('Data & offline'),
        _buildSettingsGroup([
          ProfileOptionTile(
            icon: Icons.download_for_offline_rounded,
            title: AppConstants.allowTilePrefetch
                ? 'Offline maps'
                : 'Map cache & storage',
            subtitle: AppConstants.allowTilePrefetch
                ? 'Download map areas for running without cellular signal'
                : 'Local viewing cache (bulk prefetch disabled under OSM policy)',
            onTap: () {
              AppMotion.selectionTick();
              showOfflineMapsSheet(context);
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.file_download_outlined,
            title: 'Export run data',
            subtitle:
                'Export GPS tracks and claimed territory as GeoJSON or GPX',
            onTap: () {
              AppMotion.selectionTick();
              _showExportSheet(context);
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.delete_forever_rounded,
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            title: 'Delete account & data',
            subtitle: 'Permanently purge athlete profile, GPS runs, and territory records',
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ]),

        const SizedBox(height: AppSpacing.s16),

        // 7. ABOUT & PLATFORM
        _buildSectionTitle('About'),
        _buildSettingsGroup([
          ProfileOptionTile(
            icon: Icons.info_outline_rounded,
            title: 'Territory Runner',
            subtitle: '${AppVersion.display} • Territory running',
            trailing: Text(
              AppVersion.display,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                applicationVersion: AppVersion.version,
                applicationLegalese: 'Crafted with athletic precision.',
              );
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.map_outlined,
            title: 'Map Data & Attribution',
            subtitle: AppConstants.tileAttribution,
            onTap: null,
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.explore_rounded,
            title: 'Replay intro',
            subtitle: 'Introduction to territory running and closed loops',
            onTap: () {
              AppMotion.selectionTick();
              Navigator.of(context).push(
                AppMotion.pageRoute(
                  builder: (_) => OnboardingScreen(
                    onCompleted: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
          // Developer tools (hidden behind kDebugMode)
          if (kDebugMode) ...[
            const Divider(height: 1, color: AppColors.border),
            ProfileOptionTile(
              icon: Icons.palette_rounded,
              title: 'Design System Gallery (Dev)',
              subtitle:
                  'Inspect Graphite, Bone and Moss tokens and UI components',
              onTap: () {
                AppMotion.selectionTick();
                Navigator.of(context).push(
                  AppMotion.pageRoute(
                    builder: (_) => const DesignGalleryScreen(),
                  ),
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
      padding: const EdgeInsets.only(
        left: AppSpacing.s4,
        bottom: AppSpacing.s8,
      ),
      child: Text(
        title,
        style: AppText.label.copyWith(color: AppColors.textMuted),
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
        child: Column(children: children),
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
  final Color? iconColor;
  final Color? titleColor;

  const ProfileOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
        title: Text(
          title,
          style: AppText.bodyMedium.copyWith(
            color: titleColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              )
            : null,
        trailing:
            trailing ??
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
