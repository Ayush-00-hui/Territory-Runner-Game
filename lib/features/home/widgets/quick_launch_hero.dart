import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../ui/ui.dart';

/// Performance-first Home Hero Card featuring Today's Goal Ring, GPS Status, and primary Start Run CTA.
class QuickLaunchHero extends StatefulWidget {
  final VoidCallback? onStartRun;

  const QuickLaunchHero({
    super.key,
    this.onStartRun,
  });

  @override
  State<QuickLaunchHero> createState() => _QuickLaunchHeroState();
}

class _QuickLaunchHeroState extends State<QuickLaunchHero> {
  String _gpsStatus = 'Checking GPS...';
  bool _isGpsReady = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _checkGpsStatus();
    _checkTimer = Timer.periodic(const Duration(seconds: 8), (_) => _checkGpsStatus());
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkGpsStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsStatus = 'GPS Disabled';
            _isGpsReady = false;
          });
        }
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsStatus = 'Location Denied';
            _isGpsReady = false;
          });
        }
        return;
      }

      final lastPos = await Geolocator.getLastKnownPosition();
      if (mounted) {
        setState(() {
          if (lastPos != null && lastPos.accuracy < 25) {
            _gpsStatus = 'GPS Ready • ±${lastPos.accuracy.round()}m';
            _isGpsReady = true;
          } else {
            _gpsStatus = 'GPS Ready (Locking)';
            _isGpsReady = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'GPS Active';
          _isGpsReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double goalTargetKm = 5.0;
    const double currentDayKm = 3.4;
    final double goalProgress = (currentDayKm / goalTargetKm).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        children: [
          Row(
            children: [
              // Today's Goal Ring
              ProgressRing(
                progress: goalProgress,
                size: 64,
                strokeWidth: 6,
                progressColor: AppColors.accent,
                trackColor: AppColors.surface2,
                center: Text(
                  '${(goalProgress * 100).round()}%',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TODAY\'S TARGET', style: AppText.labelSmall),
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$currentDayKm', style: AppText.displaySmall),
                        const SizedBox(width: AppSpacing.s4),
                        Text('/ $goalTargetKm KM', style: AppText.statUnit),
                      ],
                    ),
                  ],
                ),
              ),

              // GPS Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s6),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.brFull,
                  border: Border.all(
                    color: _isGpsReady ? AppColors.success.withValues(alpha: 0.4) : AppColors.warning.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isGpsReady ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      _gpsStatus,
                      style: AppText.labelSmall.copyWith(
                        color: _isGpsReady ? AppColors.success : AppColors.warning,
                        fontSize: 9.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s20),

          // Primary CTA Button
          PrimaryButton(
            label: 'START CONQUEST RUN',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              AppMotion.heavyBurst();
              widget.onStartRun?.call();
            },
          ),
          const SizedBox(height: AppSpacing.s10),

          // Subtle motivation subtext
          Text(
            'Enclose territory loops to claim sovereign ground on foot.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall,
          ),
        ],
      ),
    );
  }
}
