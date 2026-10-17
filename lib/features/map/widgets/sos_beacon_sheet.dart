import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/safety_service.dart';
import '../../../ui/ui.dart';
import '../../profile/widgets/emergency_contact_dialog.dart';

void showSosBeaconSheet(BuildContext context, LatLng? currentPosition) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _SosBeaconSheet(currentPosition: currentPosition),
  );
}

class _SosBeaconSheet extends StatefulWidget {
  final LatLng? currentPosition;

  const _SosBeaconSheet({required this.currentPosition});

  @override
  State<_SosBeaconSheet> createState() => _SosBeaconSheetState();
}

class _SosBeaconSheetState extends State<_SosBeaconSheet> {
  final SafetyService _safetyService = SafetyService();
  bool _isSirenOn = false;

  @override
  void initState() {
    super.initState();
    _safetyService.loadSettings();
    _isSirenOn = _safetyService.isSirenPlaying;
  }

  @override
  void dispose() {
    // If siren was turned on here, we leave it or stop if modal closes
    super.dispose();
  }

  void _toggleSiren() {
    if (_isSirenOn) {
      _safetyService.stopTacticalSiren();
      setState(() => _isSirenOn = false);
    } else {
      _safetyService.playTacticalSiren();
      setState(() => _isSirenOn = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.currentPosition ?? const LatLng(37.7749, -122.4194);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.16),
                  border: Border.all(color: AppColors.error, width: 2),
                ),
                child: const Icon(Icons.emergency_rounded, color: AppColors.error, size: 24),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TACTICAL SOS BEACON',
                      style: AppText.headingSmall.copyWith(
                        color: AppColors.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                      style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),
          Text(
            'If you feel unsafe or experience an incident, trigger instant emergency contact dispatch, audible deterrence, or 911 dialing.',
            style: AppText.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Action 1: Call Emergency 911
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
              ),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
              label: const Text(
                'CALL EMERGENCY (911)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0),
              ),
              onPressed: () {
                _safetyService.callEmergencyServices(dialNumber: '911');
              },
            ),
          ),

          const SizedBox(height: AppSpacing.s12),

          // Action 2: Send SOS SMS to Emergency Contact
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
              ),
              icon: const Icon(Icons.sms_rounded, color: AppColors.error, size: 20),
              label: Text(
                _safetyService.hasContactConfigured
                    ? 'SMS CONTACT (${_safetyService.contactName.isNotEmpty ? _safetyService.contactName : _safetyService.contactPhone})'
                    : 'SET UP EMERGENCY CONTACT SMS',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
              onPressed: () {
                if (_safetyService.hasContactConfigured) {
                  _safetyService.sendEmergencySms(position: position);
                } else {
                  showEmergencyContactDialog(context);
                }
              },
            ),
          ),

          const SizedBox(height: AppSpacing.s12),

          // Action 3: Row with Share Live Location & Audio Siren
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                    ),
                    icon: const Icon(Icons.share_location_rounded, color: AppColors.accent, size: 18),
                    label: const Text('SHARE GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      _safetyService.shareLiveLocation(position: position);
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isSirenOn ? AppColors.warning : AppColors.surface,
                      foregroundColor: _isSirenOn ? AppColors.onAccent : AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                      side: BorderSide(
                        color: _isSirenOn ? AppColors.warning : AppColors.borderSubtle,
                      ),
                    ),
                    icon: Icon(_isSirenOn ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18),
                    label: Text(
                      _isSirenOn ? 'STOP SIREN' : 'SIREN ALARM',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: _toggleSiren,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
