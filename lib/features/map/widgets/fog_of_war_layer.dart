import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/fog_of_war_service.dart';
import '../../../ui/ui.dart';

/// Atmospheric Fog of War map overlay that reveals explored corridors
/// while keeping unexplored city streets cloaked in obsidian shadow.
class FogOfWarLayer extends StatefulWidget {
  const FogOfWarLayer({super.key});

  @override
  State<FogOfWarLayer> createState() => _FogOfWarLayerState();
}

class _FogOfWarLayerState extends State<FogOfWarLayer> {
  final FogOfWarService _fogService = FogOfWarService();

  @override
  void initState() {
    super.initState();
    _fogService.addListener(_onFogChanged);
  }

  void _onFogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fogService.removeListener(_onFogChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final explored = _fogService.recentExploredPoints;

    return CustomPaint(
      painter: _FogOfWarPainter(camera: camera, exploredPoints: explored),
      size: Size.infinite,
    );
  }
}

class _FogOfWarPainter extends CustomPainter {
  final MapCamera camera;
  final List<LatLng> exploredPoints;

  _FogOfWarPainter({required this.camera, required this.exploredPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (exploredPoints.isEmpty) return;

    // Soft subtle atmospheric tint using AppColors base canvas
    final veilPaint = Paint()
      ..color = AppColors.bgDeep.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, veilPaint);

    // Punch glowing holes along explored path using DestinationOut blend mode
    final clearPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill;

    for (final pt in exploredPoints) {
      final offset = camera.getOffsetFromOrigin(pt);
      // Reveal ~45-55m radius in screen pixels
      final radius = 28.0 * (camera.zoom / 15.0).clamp(0.6, 2.2);
      canvas.drawCircle(Offset(offset.dx, offset.dy), radius, clearPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FogOfWarPainter oldDelegate) {
    return oldDelegate.exploredPoints.length != exploredPoints.length ||
        oldDelegate.camera != camera;
  }
}
