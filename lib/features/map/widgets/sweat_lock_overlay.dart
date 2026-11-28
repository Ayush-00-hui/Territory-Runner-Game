import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';
import '../controllers/map_run_controller.dart';

/// Fullscreen pure-black ambient runner mode with accidental tap protection.
class SweatLockOverlay extends StatefulWidget {
  final MapRunController controller;
  final VoidCallback onUnlock;

  const SweatLockOverlay({
    super.key,
    required this.controller,
    required this.onUnlock,
  });

  @override
  State<SweatLockOverlay> createState() => _SweatLockOverlayState();
}

class _SweatLockOverlayState extends State<SweatLockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        widget.onUnlock();
      }
    });

    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  void _onHoldStart(PointerDownEvent _) {
    HapticFeedback.lightImpact();
    _holdController.forward();
  }

  void _onHoldEnd() {
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final speed = controller.currentSpeedKmh;
    final paceStr = speed > 0.5
        ? () {
            final secPerKm = (3600.0 / speed).round();
            final m = secPerKm ~/ 60;
            final s = secPerKm % 60;
            return "$m'${s.toString().padLeft(2, '0')}\"";
          }()
        : '--:--';

    final distanceKm = controller.runDistanceKm.toStringAsFixed(2);
    final elapsedSec = controller.elapsedDurationSeconds;
    final mins = elapsedSec ~/ 60;
    final secs = elapsedSec % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final closureM = controller.distanceToClosureMeters;
    final closureStr = closureM != null
        ? '${closureM.round()} m to close loop'
        : 'Open course';

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Status Bar: Sweat Lock Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.accent,
                          size: 14.0,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Text(
                          'SWEAT LOCK ACTIVE',
                          style: AppText.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Primary Metric 1: Pace
              Text(
                'CURRENT PACE',
                style: AppText.labelLarge.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                paceStr,
                style: AppText.displayLarge.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/km',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: AppSpacing.s32),

              // Secondary Metrics: Distance & Elapsed Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        'DISTANCE',
                        style: AppText.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        distanceKm,
                        style: AppText.displaySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'km',
                        style: AppText.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1.0,
                    height: 40.0,
                    color: AppColors.borderSubtle,
                  ),
                  Column(
                    children: [
                      Text(
                        'DURATION',
                        style: AppText.caption.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        timeStr,
                        style: AppText.displaySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'time',
                        style: AppText.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s24),

              // Loop Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      closureM != null
                          ? Icons.radar_rounded
                          : Icons.route_rounded,
                      color: closureM != null
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 16.0,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      closureStr,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Hold-to-Unlock Circle Indicator
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onHoldStart,
                onPointerUp: (_) => _onHoldEnd(),
                onPointerCancel: (_) => _onHoldEnd(),
                child: AnimatedBuilder(
                  animation: _holdController,
                  builder: (context, _) {
                    final progress = _holdController.value;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 72.0,
                              height: 72.0,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3.5,
                                backgroundColor: AppColors.surface2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.accent,
                                ),
                              ),
                            ),
                            Container(
                              width: 58.0,
                              height: 58.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: progress > 0.0
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : AppColors.surface,
                              ),
                              child: Icon(
                                Icons.lock_open_rounded,
                                color: progress > 0.5
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                size: 24.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        Text(
                          progress > 0.0
                              ? 'Keep holding to unlock...'
                              : 'Hold to unlock',
                          style: AppText.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.s12),
            ],
          ),
        ),
      ),
    );
  }
}
