import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart'; // For AppColors
import 'motion_sensor_service.dart';

class SensorExploreScreen extends StatefulWidget {
  const SensorExploreScreen({super.key});

  @override
  State<SensorExploreScreen> createState() => _SensorExploreScreenState();
}

class _SensorExploreScreenState extends State<SensorExploreScreen> {
  final MotionSensorService _sensorService = MotionSensorService();

  @override
  void initState() {
    super.initState();
    _sensorService.startStreaming();
    _sensorService.addListener(_onSensorsUpdated);
  }

  void _onSensorsUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sensorService.removeListener(_onSensorsUpdated);
    super.dispose();
  }

  void _showTelemetryExportModal() {
    HapticFeedback.selectionClick();
    final jsonText = _sensorService.exportTelemetryJson();
    final csvText = _sensorService.exportTelemetryCsv();
    int exportFormat = 0; // 0 = JSON, 1 = CSV

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.file_download_rounded, color: AppColors.accent, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'HARDWARE TELEMETRY EXPORT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.1),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // JSON vs CSV toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => exportFormat = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: exportFormat == 0 ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'JSON Stream',
                              style: TextStyle(
                                color: exportFormat == 0 ? Colors.black : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => exportFormat = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: exportFormat == 1 ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'CSV Format',
                              style: TextStyle(
                                color: exportFormat == 1 ? Colors.black : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    exportFormat == 0 ? jsonText : csvText,
                    style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: exportFormat == 0 ? jsonText : csvText));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.surface,
                      content: Text('⚡ Telemetry stream copied to clipboard!', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('COPY TELEMETRY TO CLIPBOARD', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, pad.top + 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Export Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Sensor Telemetry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Live 60Hz 6DOF Hardware Oscilloscope',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showTelemetryExportModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.file_download_outlined, color: AppColors.accent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Export',
                          style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 1. Live 3-Axis Accelerometer Waveform Canvas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.show_chart_rounded, color: AppColors.accent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '3-AXIS ACCELEROMETER OSCILLOSCOPE',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          _AxisLegend(label: 'X', color: Color(0xFFFF5722)),
                          SizedBox(width: 8),
                          _AxisLegend(label: 'Y', color: Color(0xFF00F0FF)),
                          SizedBox(width: 8),
                          _AxisLegend(label: 'Z', color: Color(0xFF00E676)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Canvas Graph
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: AppColors.bgDeep,
                        child: CustomPaint(
                          painter: AccelerometerWaveformPainter(history: _sensorService.history),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Live Axis Readings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _AxisValueTile(label: 'Ax', value: '${_sensorService.ax.toStringAsFixed(2)} m/s²', color: const Color(0xFFFF5722)),
                      _AxisValueTile(label: 'Ay', value: '${_sensorService.ay.toStringAsFixed(2)} m/s²', color: const Color(0xFF00F0FF)),
                      _AxisValueTile(label: 'Az', value: '${_sensorService.az.toStringAsFixed(2)} m/s²', color: const Color(0xFF00E676)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Gyroscope Attitude & Compass + G-Force Tactical Dial
            Row(
              children: [
                // Gyroscope Attitude & Compass
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GYROSCOPE ATTITUDE',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: CustomPaint(
                              painter: GyroscopeAttitudePainter(
                                pitch: _sensorService.betaPitch,
                                roll: _sensorService.gammaRoll,
                                heading: _sensorService.alphaHeading,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'P: ${_sensorService.betaPitch.toStringAsFixed(0)}°  R: ${_sensorService.gammaRoll.toStringAsFixed(0)}°',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Total Resultant G-Force Tactical Dial
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _sensorService.isFreefall ? const Color(0xFF8A2BE2) : AppColors.border,
                        width: _sensorService.isFreefall ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'RESULTANT G-FORCE',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                            ),
                            if (_sensorService.isFreefall)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ZERO-G', style: TextStyle(color: Color(0xFF00F0FF), fontSize: 8, fontWeight: FontWeight.w900)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: CustomPaint(
                              painter: GForceGaugePainter(gForce: _sensorService.totalGForce),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            '${_sensorService.totalGForce.toStringAsFixed(2)} G',
                            style: TextStyle(
                              color: _sensorService.isFreefall
                                  ? const Color(0xFF00F0FF)
                                  : (_sensorService.totalGForce > 1.2 ? const Color(0xFFFF5722) : Colors.white),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. Kinematic Step Counter & Cadence Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.directions_run_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KINEMATIC STRIDES',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_sensorService.stepCount} STEPS',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'CADENCE',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_sensorService.cadenceSpM.toStringAsFixed(0)} SPM',
                        style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w900),
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

class _AxisLegend extends StatelessWidget {
  final String label;
  final Color color;
  const _AxisLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _AxisValueTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AxisValueTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Custom Oscilloscope Waveform Painter for 3-Axis Accelerometer Stream
class AccelerometerWaveformPainter extends CustomPainter {
  final List<SensorTelemetryFrame> history;
  AccelerometerWaveformPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    // Background grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (double y = 0; y <= size.height; y += size.height / 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final paintX = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final paintY = Paint()
      ..color = const Color(0xFF00F0FF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final paintZ = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pathX = Path();
    final pathY = Path();
    final pathZ = Path();

    final double stepX = size.width / (MotionSensorService.maxBufferSize - 1);
    final double midY = size.height / 2;
    const double scale = 3.5; // Scale factor for m/s²

    for (int i = 0; i < history.length; i++) {
      final f = history[i];
      final double x = i * stepX;
      final double yX = (midY - (f.ax * scale)).clamp(0.0, size.height);
      final double yY = (midY - (f.ay * scale)).clamp(0.0, size.height);
      final double yZ = (midY - ((f.az - 9.81) * scale)).clamp(0.0, size.height);

      if (i == 0) {
        pathX.moveTo(x, yX);
        pathY.moveTo(x, yY);
        pathZ.moveTo(x, yZ);
      } else {
        pathX.lineTo(x, yX);
        pathY.lineTo(x, yY);
        pathZ.lineTo(x, yZ);
      }
    }

    canvas.drawPath(pathX, paintX);
    canvas.drawPath(pathY, paintY);
    canvas.drawPath(pathZ, paintZ);
  }

  @override
  bool shouldRepaint(covariant AccelerometerWaveformPainter oldDelegate) => true;
}

/// Custom Gyroscope Artificial Horizon & Compass Painter
class GyroscopeAttitudePainter extends CustomPainter {
  final double pitch;
  final double roll;
  final double heading;

  GyroscopeAttitudePainter({required this.pitch, required this.roll, required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring
    final ringPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 2, ringPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((roll * math.pi) / 180.0);

    // Horizon line
    final horizonPaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..strokeWidth = 2.5;
    final double pitchOffset = (pitch * 1.5).clamp(-radius * 0.7, radius * 0.7);
    canvas.drawLine(
      Offset(-radius * 0.7, pitchOffset),
      Offset(radius * 0.7, pitchOffset),
      horizonPaint,
    );

    // Pitch ladder rungs
    final rungPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(-radius * 0.35, pitchOffset - 15), Offset(radius * 0.35, pitchOffset - 15), rungPaint);
    canvas.drawLine(Offset(-radius * 0.35, pitchOffset + 15), Offset(radius * 0.35, pitchOffset + 15), rungPaint);

    canvas.restore();

    // Center Crosshair
    final crosshairPaint = Paint()
      ..color = const Color(0xFFFF5722)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(center.dx - 8, center.dy), Offset(center.dx + 8, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 8), Offset(center.dx, center.dy + 8), crosshairPaint);
  }

  @override
  bool shouldRepaint(covariant GyroscopeAttitudePainter oldDelegate) => true;
}

/// Custom Tactical G-Force Circular Dial Painter
class GForceGaugePainter extends CustomPainter {
  final double gForce;
  GForceGaugePainter({required this.gForce});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Background track arc
    final trackPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Active G-force arc
    final Color arcColor = gForce < 0.5
        ? const Color(0xFF8A2BE2) // Zero-G Purple
        : (gForce > 1.2 ? const Color(0xFFFF5722) : const Color(0xFF00E676));

    final activePaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final double sweep = (gForce / 2.5).clamp(0.0, 1.0) * (math.pi * 1.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant GForceGaugePainter oldDelegate) => true;
}
