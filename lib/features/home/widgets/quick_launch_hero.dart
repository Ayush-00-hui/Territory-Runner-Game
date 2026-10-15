import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../ui/ui.dart';

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
  String _gpsStatus = 'CHECKING GPS...';
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
            _gpsStatus = 'GPS DISABLED';
            _isGpsReady = false;
          });
        }
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsStatus = 'LOCATION DENIED';
            _isGpsReady = false;
          });
        }
        return;
      }

      final lastPos = await Geolocator.getLastKnownPosition();
      if (mounted) {
        setState(() {
          if (lastPos != null && lastPos.accuracy < 25) {
            _gpsStatus = 'GPS READY • ±${lastPos.accuracy.round()}m';
            _isGpsReady = true;
          } else {
            _gpsStatus = 'GPS READY (LOCKING)';
            _isGpsReady = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'GPS ACTIVE';
          _isGpsReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br24,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // GPS Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: (_isGpsReady ? AppColors.accent : AppColors.warning).withValues(alpha: 0.12),
              borderRadius: AppSpacing.brFull,
              border: Border.all(
                color: (_isGpsReady ? AppColors.accent : AppColors.warning).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isGpsReady ? AppColors.accent : AppColors.warning,
                    boxShadow: AppSpacing.neonGlow(
                      _isGpsReady ? AppColors.accent : AppColors.warning,
                      blur: 6,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  _gpsStatus,
                  style: AppText.label.copyWith(
                    color: _isGpsReady ? AppColors.accent : AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Big Bold START RUN Hero Button
          GestureDetector(
            onTap: () {
              AppMotion.heavyBurst();
              if (widget.onStartRun != null) {
                widget.onStartRun!();
              }
            },
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: AppSpacing.br20,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 30,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'START CONQUEST RUN',
                    style: AppText.headingMedium.copyWith(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s10),

          // Subtle motivation subtext
          Text(
            'Enclose territory loops to claim sovereign grid ground on foot.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
