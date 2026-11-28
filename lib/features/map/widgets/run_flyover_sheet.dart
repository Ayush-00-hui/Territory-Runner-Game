import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../ui/ui.dart';

/// Interactive modal sheet displaying a cinematic route replay with speed controls.
class RunFlyoverSheet extends StatefulWidget {
  final List<LatLng> coordinates;
  final double distanceKm;
  final int durationSeconds;

  const RunFlyoverSheet({
    super.key,
    required this.coordinates,
    required this.distanceKm,
    required this.durationSeconds,
  });

  static Future<void> show({
    required BuildContext context,
    required List<LatLng> coordinates,
    required double distanceKm,
    required int durationSeconds,
  }) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => RunFlyoverSheet(
        coordinates: coordinates,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
      ),
    );
  }

  @override
  State<RunFlyoverSheet> createState() => _RunFlyoverSheetState();
}

class _RunFlyoverSheetState extends State<RunFlyoverSheet> {
  final MapController _mapController = MapController();
  int _currentIndex = 0;
  bool _isPlaying = false;
  int _speedMultiplier = 2; // 1x, 2x, 4x
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.coordinates.length >= 2) {
      _startPlayback();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPlayback() {
    setState(() => _isPlaying = true);
    _timer?.cancel();
    final intervalMs = (150 ~/ _speedMultiplier).clamp(20, 300);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (t) {
      if (!mounted) return;
      if (_currentIndex < widget.coordinates.length - 1) {
        setState(() => _currentIndex++);
        final currentPoint = widget.coordinates[_currentIndex];
        _mapController.move(currentPoint, 16.0);
      } else {
        t.cancel();
        setState(() => _isPlaying = false);
      }
    });
  }

  void _pausePlayback() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _toggleSpeed() {
    final nextSpeed = _speedMultiplier == 1
        ? 2
        : _speedMultiplier == 2
        ? 4
        : 1;
    setState(() => _speedMultiplier = nextSpeed);
    if (_isPlaying) {
      _startPlayback();
    }
  }

  void _restart() {
    _timer?.cancel();
    setState(() => _currentIndex = 0);
    _startPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final coords = widget.coordinates;
    if (coords.length < 2) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Center(
          child: Text(
            'Route too short for cinematic replay.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final currentSubPath = coords.sublist(0, _currentIndex + 1);
    final activePuck = coords[_currentIndex];
    final progress = _currentIndex / (coords.length - 1);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROUTE FLYOVER',
                        style: AppText.labelLarge.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        '${widget.distanceKm.toStringAsFixed(2)} km cinematic replay',
                        style: AppText.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Interactive Map Viewport
            SizedBox(
              height: 220.0,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: coords.first,
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.territoryrunner.app',
                  ),
                  // Full route path outline in faint muted line
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: coords,
                        color: AppColors.borderSubtle.withValues(alpha: 0.6),
                        strokeWidth: 3.0,
                      ),
                      // Active traversed segment
                      Polyline(
                        points: currentSubPath,
                        color: AppColors.accent,
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                  // Live Replay Puck
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: activePuck,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.5),
                                blurRadius: 10.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Playback Controls
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                children: [
                  // Progress Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: AppColors.surface2,
                      thumbColor: AppColors.accent,
                      overlayColor: AppColors.accent.withValues(alpha: 0.2),
                      trackHeight: 3.5,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (val) {
                        final targetIdx = ((coords.length - 1) * val).round();
                        setState(() => _currentIndex = targetIdx);
                        _mapController.move(coords[_currentIndex], 16.0);
                      },
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Replay: ${(progress * 100).round()}%',
                        style: AppText.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          // Speed multiplier button
                          GestureDetector(
                            onTap: _toggleSpeed,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
                                vertical: AppSpacing.s6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                '${_speedMultiplier}x',
                                style: AppText.labelLarge.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          // Play / Pause / Restart button
                          IconButton(
                            iconSize: 32.0,
                            icon: Icon(
                              _currentIndex >= coords.length - 1
                                  ? Icons.replay_rounded
                                  : _isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              color: AppColors.accent,
                            ),
                            onPressed: () {
                              if (_currentIndex >= coords.length - 1) {
                                _restart();
                              } else if (_isPlaying) {
                                _pausePlayback();
                              } else {
                                _startPlayback();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
