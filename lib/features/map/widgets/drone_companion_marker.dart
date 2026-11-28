import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/drone_companion_service.dart';
import '../../../ui/ui.dart';

/// Interactive map layer rendering the animated orbiting AI Tactical Drone ('Aero').
class DroneCompanionMarker extends StatefulWidget {
  final LatLng? runnerPosition;

  const DroneCompanionMarker({super.key, this.runnerPosition});

  @override
  State<DroneCompanionMarker> createState() => _DroneCompanionMarkerState();
}

class _DroneCompanionMarkerState extends State<DroneCompanionMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  final DroneCompanionService _droneService = DroneCompanionService();

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.runnerPosition == null) return const SizedBox.shrink();

    final dronePos = _droneService.computeDronePosition(widget.runnerPosition!);

    return MarkerLayer(
      markers: [
        Marker(
          point: dronePos,
          width: 38.0,
          height: 38.0,
          child: AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              final bobbingOffset =
                  math.sin(_hoverController.value * math.pi) * 3.0;

              return Transform.translate(
                offset: Offset(0, bobbingOffset),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.accent, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 10.0,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.flight_takeoff_rounded,
                      color: AppColors.accent,
                      size: 18.0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
