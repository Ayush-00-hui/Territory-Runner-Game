import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../models/privacy_zone.dart';
import '../../../services/api_client.dart';
import '../../../services/privacy_zone_service.dart';
import '../../../ui/ui.dart';

void showPrivacyZonesSheet(BuildContext context) {
  AppSheet.show(context: context, builder: (ctx) => const _PrivacyZonesSheet());
}

class _PrivacyZonesSheet extends StatefulWidget {
  const _PrivacyZonesSheet();

  @override
  State<_PrivacyZonesSheet> createState() => _PrivacyZonesSheetState();
}

class _PrivacyZonesSheetState extends State<_PrivacyZonesSheet> {
  final PrivacyZoneService _privacyService = PrivacyZoneService();
  bool _isLoading = true;
  bool _isAdding = false;

  final TextEditingController _nameController = TextEditingController(
    text: 'Home Base',
  );
  double _newRadiusMeters = 200.0;
  LatLng? _selectedCoordinates;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _privacyService.loadZones();
    // Background sync with server (offline-first preserved)
    _privacyService.fetchAndSyncFromServer(ApiClient()).then((_) {
      if (mounted) setState(() {});
    });
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _selectedCoordinates = LatLng(pos.latitude, pos.longitude);
          _isLocating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        AppToast.show(
          context,
          'Failed to acquire GPS location: $e',
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _saveNewZone() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_privacyService.zones.length >= PrivacyZoneService.maxZones) {
      AppToast.show(
        context,
        'Maximum ${PrivacyZoneService.maxZones} privacy zones allowed.',
        type: AppToastType.warning,
      );
      return;
    }

    final coords = _selectedCoordinates ?? const LatLng(37.7749, -122.4194);
    final zone = PrivacyZone(
      id: const Uuid().v4(),
      name: name,
      latitude: coords.latitude,
      longitude: coords.longitude,
      radiusMeters: _newRadiusMeters,
      isEnabled: true,
      createdAt: DateTime.now(),
    );

    await _privacyService.addZone(zone, apiClient: ApiClient());
    if (mounted) {
      setState(() {
        _isAdding = false;
        _nameController.text = 'Office';
        _selectedCoordinates = null;
      });
      AppToast.show(
        context,
        'Privacy zone "$name" created and synced with server.',
        type: AppToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  borderRadius: AppRadius.brFull,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: AppSpacing.br10,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy zones',
                          style: AppText.headingSmall.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Privacy exclusion radius',
                          style: AppText.label.copyWith(
                            color: AppColors.accent,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isAdding)
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_rounded,
                      color:
                          _privacyService.zones.length >=
                              PrivacyZoneService.maxZones
                          ? AppColors.disabled
                          : AppColors.accent,
                      size: 28,
                    ),
                    onPressed:
                        _privacyService.zones.length >=
                            PrivacyZoneService.maxZones
                        ? () => AppToast.show(
                            context,
                            'Maximum ${PrivacyZoneService.maxZones} zones reached',
                            type: AppToastType.warning,
                          )
                        : () => setState(() => _isAdding = true),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.s12),
            Text(
              'Your GPS tracks, start/finish points, and live presence inside privacy zones are strictly hidden from other runners and public exports. Territory polygons remain visible to maintain fair territory gameplay.',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Add Zone Form
            if (_isAdding) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br16,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New privacy zone',
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Home, Work, Gym',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.br12,
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Radius Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Exclusion Radius',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${_newRadiusMeters.round()} meters',
                          style: AppText.bodyBold.copyWith(
                            color: AppColors.accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _newRadiusMeters.clamp(
                        PrivacyZoneService.minRadius,
                        PrivacyZoneService.maxRadius,
                      ),
                      min: PrivacyZoneService.minRadius,
                      max: PrivacyZoneService.maxRadius,
                      divisions: 39,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.surface2,
                      onChanged: (val) =>
                          setState(() => _newRadiusMeters = val),
                    ),

                    // Coordinate Pinning
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppSpacing.br12,
                              ),
                            ),
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    size: 16,
                                    color: AppColors.accent,
                                  ),
                            label: Text(
                              _selectedCoordinates == null
                                  ? 'Pin Current Location'
                                  : 'Pinned (${_selectedCoordinates!.latitude.toStringAsFixed(3)}, ${_selectedCoordinates!.longitude.toStringAsFixed(3)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: _fetchCurrentLocation,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _isAdding = false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.onAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppSpacing.br12,
                              ),
                            ),
                            onPressed: _saveNewZone,
                            child: const Text(
                              'Save zone',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

            // Zones List
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            else if (_privacyService.zones.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br16,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: AppColors.textMuted,
                      size: 32,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'No privacy zones yet',
                      style: AppText.headingSmall.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Tap + above to mask your home or workplace coordinates.',
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._privacyService.zones.map((zone) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s14,
                    vertical: AppSpacing.s10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.br16,
                    border: Border.all(
                      color: zone.isEnabled
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: zone.isEnabled
                              ? AppColors.accentContainer
                              : AppColors.surface2,
                        ),
                        child: Icon(
                          Icons.home_rounded,
                          color: zone.isEnabled
                              ? AppColors.accent
                              : AppColors.disabled,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone.name,
                              style: AppText.bodyBold.copyWith(
                                color: zone.isEnabled
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${zone.radiusMeters.round()}m exclusion radius • Lat: ${zone.latitude.toStringAsFixed(3)}, Lng: ${zone.longitude.toStringAsFixed(3)}',
                              style: AppText.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: zone.isEnabled,
                        activeThumbColor: AppColors.accent,
                        activeTrackColor: AppColors.accentContainer,
                        onChanged: (val) async {
                          await _privacyService.toggleZone(
                            zone.id,
                            val,
                            apiClient: ApiClient(),
                          );
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () async {
                          await _privacyService.deleteZone(
                            zone.id,
                            apiClient: ApiClient(),
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
