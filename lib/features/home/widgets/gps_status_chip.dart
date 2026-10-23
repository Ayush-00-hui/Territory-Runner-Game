import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../ui/ui.dart';

/// Reusable athletic GPS status chip with an active colored status dot.
/// Dot colors:
/// - [AppColors.success] (green): GPS signal locked (accuracy <= 25m)
/// - [AppColors.warning] (amber): GPS locking or weak signal
/// - [AppColors.error] (red): GPS service disabled or permission denied
class GpsStatusChip extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onTap;

  const GpsStatusChip({super.key, this.isActive = true, this.onTap});

  @override
  State<GpsStatusChip> createState() => _GpsStatusChipState();
}

class _GpsStatusChipState extends State<GpsStatusChip> {
  String _label = 'Acquiring GPS...';
  Color _dotColor = AppColors.warning;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _checkGps();
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => _checkGps());
    }
  }

  @override
  void didUpdateWidget(GpsStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _checkGps();
        _timer ??= Timer.periodic(
          const Duration(seconds: 8),
          (_) => _checkGps(),
        );
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _label = 'GPS disabled';
            _dotColor = AppColors.error;
          });
        }
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _label = 'Location denied';
            _dotColor = AppColors.error;
          });
        }
        return;
      }

      final lastPos = await Geolocator.getLastKnownPosition();
      if (mounted) {
        setState(() {
          if (lastPos != null && lastPos.accuracy <= 25) {
            _label = 'GPS ready • ±${lastPos.accuracy.round()}m';
            _dotColor = AppColors.success;
          } else {
            _label = 'Locking GPS...';
            _dotColor = AppColors.warning;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _label = 'GPS ready';
          _dotColor = AppColors.success;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GPS signal status: $_label',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: AppRadius.brFull,
            border: Border.all(
              color: _dotColor.withValues(alpha: 0.35),
              width: 1.0,
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
                  color: _dotColor,
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Flexible(
                child: Text(
                  _label,
                  style: AppText.labelSmall.copyWith(
                    color: _dotColor == AppColors.error
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
