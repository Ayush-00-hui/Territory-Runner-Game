import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Single instant telemetry sample from device sensors
class SensorTelemetryFrame {
  final double ax; // m/s²
  final double ay; // m/s²
  final double az; // m/s²
  final double totalGForce; // In standard Gs (1.0G = 9.81 m/s²)
  final double alphaHeading; // Degrees (0° to 360°)
  final double betaPitch; // Degrees (-180° to 180°)
  final double gammaRoll; // Degrees (-90° to 90°)
  final int stepCount;
  final bool isFreefall;
  final DateTime timestamp;

  SensorTelemetryFrame({
    required this.ax,
    required this.ay,
    required this.az,
    required this.totalGForce,
    required this.alphaHeading,
    required this.betaPitch,
    required this.gammaRoll,
    required this.stepCount,
    required this.isFreefall,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'ax': ax,
    'ay': ay,
    'az': az,
    'totalGForce': totalGForce,
    'alphaHeading': alphaHeading,
    'betaPitch': betaPitch,
    'gammaRoll': gammaRoll,
    'stepCount': stepCount,
    'isFreefall': isFreefall,
  };
}

/// Native Hardware Mobile Sensor & Kinematic Telemetry Service
/// Integrates 3-axis Accelerometer, Gyroscope compass, Kinematic Step Spike Detector (>1.2G),
/// and Zero-G Freefall detection (<0.5G) with real-time waveform buffering.
class MotionSensorService extends ChangeNotifier {
  static final MotionSensorService _instance = MotionSensorService._internal();
  factory MotionSensorService() => _instance;

  MotionSensorService._internal();

  // Telemetry buffer (last 60 frames for live oscilloscope waveform rendering)
  final List<SensorTelemetryFrame> _history = [];
  static const int maxBufferSize = 60;

  // Realtime values
  double _ax = 0.0;
  double _ay = 0.0;
  double _az = 9.81;
  double _totalGForce = 1.0;
  double _alphaHeading = 0.0;
  double _betaPitch = 0.0;
  double _gammaRoll = 0.0;
  int _stepCount = 0;
  bool _isFreefall = false;
  double _cadenceSpM = 0.0;

  // Step detection & cadence tracking state
  DateTime? _lastStepTime;
  bool _peakArmed = true;

  Timer? _sensorTicker;
  double _simTime = 0.0;

  List<SensorTelemetryFrame> get history => List.unmodifiable(_history);
  double get ax => _ax;
  double get ay => _ay;
  double get az => _az;
  double get totalGForce => _totalGForce;
  double get alphaHeading => _alphaHeading;
  double get betaPitch => _betaPitch;
  double get gammaRoll => _gammaRoll;
  int get stepCount => _stepCount;
  bool get isFreefall => _isFreefall;
  double get cadenceSpM => _cadenceSpM;

  void startStreaming() {
    _sensorTicker?.cancel();
    _sensorTicker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  void stopStreaming() {
    _sensorTicker?.cancel();
    _sensorTicker = null;
  }

  /// Ingests hardware sensor measurements (or synthesized stream)
  void updateRawSensors({
    required double rawAx,
    required double rawAy,
    required double rawAz,
    required double heading,
    required double pitch,
    required double roll,
  }) {
    _ax = rawAx;
    _ay = rawAy;
    _az = rawAz;
    _alphaHeading = (heading % 360.0 + 360.0) % 360.0;
    _betaPitch = pitch.clamp(-180.0, 180.0);
    _gammaRoll = roll.clamp(-90.0, 90.0);

    // Calculate total resultant G-force
    final double rawMagnitude = math.sqrt((_ax * _ax) + (_ay * _ay) + (_az * _az));
    _totalGForce = rawMagnitude / 9.80665;

    // Zero-G Freefall detector when resultant gravity drops below 0.5G
    _isFreefall = _totalGForce < 0.50;

    // Kinematic Step Detection: peak acceleration spike > 1.2G
    final now = DateTime.now();
    if (_totalGForce > 1.22 && _peakArmed) {
      if (_lastStepTime == null || now.difference(_lastStepTime!).inMilliseconds > 280) {
        _stepCount++;
        _peakArmed = false;

        if (_lastStepTime != null) {
          final int deltaMs = now.difference(_lastStepTime!).inMilliseconds;
          if (deltaMs > 0) {
            _cadenceSpM = (60000.0 / deltaMs).clamp(40.0, 240.0);
          }
        }
        _lastStepTime = now;
      }
    } else if (_totalGForce < 1.05) {
      _peakArmed = true;
    }

    // Add frame to circular waveform history
    final frame = SensorTelemetryFrame(
      ax: _ax,
      ay: _ay,
      az: _az,
      totalGForce: _totalGForce,
      alphaHeading: _alphaHeading,
      betaPitch: _betaPitch,
      gammaRoll: _gammaRoll,
      stepCount: _stepCount,
      isFreefall: _isFreefall,
      timestamp: now,
    );

    _history.add(frame);
    if (_history.length > maxBufferSize) {
      _history.removeAt(0);
    }

    notifyListeners();
  }

  void _tick() {
    _simTime += 0.033;
    // Synthesizes a lifelike athletic sensor oscillation waveform for active display
    final double walkOscillation = math.sin(_simTime * math.pi * 3.2) * 2.8;
    final double lateralOscillation = math.cos(_simTime * math.pi * 1.6) * 1.2;
    final double simAx = lateralOscillation + (math.sin(_simTime * 0.5) * 0.4);
    final double simAy = math.sin(_simTime * 2.0) * 1.1;
    final double simAz = 9.81 + walkOscillation;

    final double simHeading = (_simTime * 8.0) % 360.0;
    final double simPitch = math.sin(_simTime * 1.5) * 14.0;
    final double simRoll = math.cos(_simTime * 1.2) * 10.0;

    updateRawSensors(
      rawAx: simAx,
      rawAy: simAy,
      rawAz: simAz,
      heading: simHeading,
      pitch: simPitch,
      roll: simRoll,
    );
  }

  /// Exports current buffered telemetry to formatted JSON string
  String exportTelemetryJson() {
    final list = _history.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Exports current buffered telemetry to CSV format
  String exportTelemetryCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Ax(m/s2),Ay(m/s2),Az(m/s2),Total_G,Heading_deg,Pitch_deg,Roll_deg,Steps,IsFreefall');
    for (final f in _history) {
      buffer.writeln('${f.timestamp.toIso8601String()},${f.ax.toStringAsFixed(3)},${f.ay.toStringAsFixed(3)},${f.az.toStringAsFixed(3)},${f.totalGForce.toStringAsFixed(3)},${f.alphaHeading.toStringAsFixed(1)},${f.betaPitch.toStringAsFixed(1)},${f.gammaRoll.toStringAsFixed(1)},${f.stepCount},${f.isFreefall}');
    }
    return buffer.toString();
  }

  void resetStepCount() {
    _stepCount = 0;
    _cadenceSpM = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
