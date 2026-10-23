import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../ui/ui.dart';

/// Performance-first Home Hero Card featuring Today's Goal Ring, GPS Status, and primary Start Run CTA.
class QuickLaunchHero extends StatefulWidget {
  final VoidCallback? onStartRun;
  final bool isActive;

  const QuickLaunchHero({super.key, this.onStartRun, this.isActive = true});

  @override
  State<QuickLaunchHero> createState() => _QuickLaunchHeroState();
}

class _QuickLaunchHeroState extends State<QuickLaunchHero> {
  bool _isGpsReady = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _checkGpsStatus();
      _checkTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _checkGpsStatus(),
      );
    }
  }

  @override
  void didUpdateWidget(QuickLaunchHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _checkGpsStatus();
        _checkTimer ??= Timer.periodic(
          const Duration(seconds: 8),
          (_) => _checkGpsStatus(),
        );
      } else {
        _checkTimer?.cancel();
        _checkTimer = null;
      }
    }
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
            _isGpsReady = false;
          });
        }
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isGpsReady = false;
          });
        }
        return;
      }

      final lastPos = await Geolocator.getLastKnownPosition();
      if (mounted) {
        setState(() {
          _isGpsReady = lastPos != null && lastPos.accuracy < 25;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
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
                size: 58,
                strokeWidth: 5.5,
                progressColor: AppColors.accent,
                trackColor: AppColors.surface2,
                center: Text(
                  '${(goalProgress * 100).round()}%',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily goal', style: AppText.labelSmall),
                    const SizedBox(height: AppSpacing.s2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$currentDayKm',
                            style: AppText.displaySmall.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            '/ ${goalTargetKm.toStringAsFixed(1)} km',
                            style: AppText.statUnit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // GPS Status Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.brFull,
                  border: Border.all(
                    color: _isGpsReady
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.warning.withValues(alpha: 0.4),
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
                        color: _isGpsReady
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      _isGpsReady ? 'Ready' : 'Locking...',
                      style: AppText.labelSmall.copyWith(
                        color: _isGpsReady
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),

          // Primary CTA Button
          PrimaryButton(
            label: 'Start run',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              AppMotion.mediumTick();
              widget.onStartRun?.call();
            },
          ),
          const SizedBox(height: AppSpacing.s10),

          // Subtle motivation subtext
          Text(
            'Run closed loops to claim territory on foot.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall,
          ),
        ],
      ),
    );
  }
}
