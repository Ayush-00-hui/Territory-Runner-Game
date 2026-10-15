import 'package:flutter/material.dart';
import '../../../services/location_service.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/motion/motion.dart';
import 'demo_controls.dart';

/// Modal bottom sheet allowing selection of GNSS hardware vs Virtual Pacer velocity profiles.
class VirtualPacerSheet extends StatelessWidget {
  final LocationService locationService;
  final VoidCallback onSimulateLoop;
  final VoidCallback onSimulateRivalCut;
  final VoidCallback onSimulateAnomaly;
  final VoidCallback onSimulateCoachDebrief;

  const VirtualPacerSheet({
    super.key,
    required this.locationService,
    required this.onSimulateLoop,
    required this.onSimulateRivalCut,
    required this.onSimulateAnomaly,
    required this.onSimulateCoachDebrief,
  });

  static Future<void> show({
    required BuildContext context,
    required LocationService locationService,
    required VoidCallback onSimulateLoop,
    required VoidCallback onSimulateRivalCut,
    required VoidCallback onSimulateAnomaly,
    required VoidCallback onSimulateCoachDebrief,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => VirtualPacerSheet(
        locationService: locationService,
        onSimulateLoop: onSimulateLoop,
        onSimulateRivalCut: onSimulateRivalCut,
        onSimulateAnomaly: onSimulateAnomaly,
        onSimulateCoachDebrief: onSimulateCoachDebrief,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s20, AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: AppSpacing.brFull,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              const Row(
                children: [
                  Icon(Icons.speed_rounded, color: AppColors.accent, size: 24),
                  SizedBox(width: AppSpacing.s8),
                  Text(
                    'VIRTUAL PACER & GNSS SIMULATION',
                    style: AppText.headingSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Select a pacer velocity profile for rapid indoor debugging, desktop simulation, or real hardware GPS:',
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.s16),
              _buildPacerOption(
                context: context,
                mode: VirtualPacerMode.none,
                title: 'Real Hardware GNSS Stream',
                subtitle: 'High-accuracy real satellite GPS location stream',
                icon: Icons.satellite_alt_rounded,
                color: AppColors.mine,
                setModalState: setModalState,
              ),
              _buildPacerOption(
                context: context,
                mode: VirtualPacerMode.walking,
                title: 'Virtual Walk — 5.0 km/h',
                subtitle: '1.39 m/s with micro-oscillation heading drift',
                icon: Icons.directions_walk_rounded,
                color: AppColors.info,
                setModalState: setModalState,
              ),
              _buildPacerOption(
                context: context,
                mode: VirtualPacerMode.running,
                title: 'Virtual Run — 10.0 km/h',
                subtitle: '2.78 m/s standard athletic pacing',
                icon: Icons.directions_run_rounded,
                color: AppColors.secondary,
                setModalState: setModalState,
              ),
              _buildPacerOption(
                context: context,
                mode: VirtualPacerMode.sprinting,
                title: 'Virtual Sprint — 15.0 km/h',
                subtitle: '4.17 m/s high-velocity athletic charge',
                icon: Icons.bolt_rounded,
                color: const Color(0xFF8A2BE2),
                setModalState: setModalState,
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.s12),
              DemoControlsLab(
                onSimulateLoop: onSimulateLoop,
                onSimulateRivalCut: onSimulateRivalCut,
                onSimulateAnomaly: onSimulateAnomaly,
                onSimulateCoachDebrief: onSimulateCoachDebrief,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPacerOption({
    required BuildContext context,
    required VirtualPacerMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required StateSetter setModalState,
  }) {
    final isSelected = locationService.pacerMode == mode;
    return GestureDetector(
      onTap: () {
        AppMotion.mediumTick();
        locationService.setVirtualPacer(mode);
        setModalState(() {});
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 2),
            content: Text(
              'Pacer mode: $title ⚡',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s10),
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: AppSpacing.br16,
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyBold.copyWith(
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(subtitle, style: AppText.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
