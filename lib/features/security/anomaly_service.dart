import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';

/// Result of anomaly scoring on a trajectory window
class AnomalyResult {
  final bool isAnomaly;
  final double anomalyScore;
  final String reason;
  final Map<String, double> features;

  const AnomalyResult({
    required this.isAnomaly,
    required this.anomalyScore,
    required this.reason,
    required this.features,
  });

  static const AnomalyResult genuine = AnomalyResult(
    isAnomaly: false,
    anomalyScore: 0.0,
    reason: 'Normal human running gait',
    features: {},
  );
}

/// On-Device Rule-Based & Statistical Heuristic GPS Anomaly Detector.
///
/// Multi-stage verification architecture:
/// - Tier 1: Deterministic Physical Constraints (isMocked, human velocity ceiling, teleport jump).
/// - Tier 2: Calibrated Statistical Heuristic scoring (Z-score weighted deviations on
///   speed, acceleration, heading jerk, path sinuosity, and stop frequency).
///
/// Model configuration and calibrated baseline statistics are loaded dynamically from
/// `assets/models/gps_anomaly_detector.json`.
class AnomalyService {
  static final AnomalyService _instance = AnomalyService._internal();
  factory AnomalyService() => _instance;

  AnomalyService._internal() {
    loadModelConfig();
  }

  // Calibrated baseline parameters (fallback defaults or dynamically populated from JSON)
  List<double> _means = [9.85, 1.42, 6.35, 0.88, 0.05];
  List<double> _stds = [2.15, 0.68, 2.80, 0.09, 0.04];
  List<double> _weights = [2.5, 2.0, 1.2, 1.0, 0.8];
  double _anomalyThreshold = 3.0;
  double _maxHumanSpeedKmh = 25.0;
  bool _isConfigLoaded = false;

  bool get isConfigLoaded => _isConfigLoaded;

  /// Loads baseline statistical parameters from the asset JSON configuration
  Future<void> loadModelConfig([String assetPath = 'assets/models/gps_anomaly_detector.json']) async {
    try {
      final String jsonStr = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (data.containsKey('means') && data['means'] is List) {
        _means = (data['means'] as List).map((e) => (e as num).toDouble()).toList();
      }
      if (data.containsKey('stds') && data['stds'] is List) {
        _stds = (data['stds'] as List).map((e) => (e as num).toDouble()).toList();
      }
      if (data.containsKey('feature_weights') && data['feature_weights'] is List) {
        _weights = (data['feature_weights'] as List).map((e) => (e as num).toDouble()).toList();
      }
      if (data.containsKey('anomaly_threshold') && data['anomaly_threshold'] is num) {
        _anomalyThreshold = (data['anomaly_threshold'] as num).toDouble();
      }
      if (data.containsKey('hard_rules') && data['hard_rules'] is Map) {
        final hardRules = data['hard_rules'] as Map;
        if (hardRules.containsKey('max_human_speed_kmh')) {
          _maxHumanSpeedKmh = (hardRules['max_human_speed_kmh'] as num).toDouble();
        }
      }
      _isConfigLoaded = true;
      debugPrint('[AnomalyService] Statistical anomaly detector configured from $assetPath');
    } catch (e) {
      debugPrint('[AnomalyService] Using calibrated in-memory baseline parameters (asset load deferred): $e');
    }
  }

  /// Scores a sliding window of recent GPS positions
  AnomalyResult scoreSegment(List<Position> positions) {
    if (positions.isEmpty) return AnomalyResult.genuine;

    // --- Tier 1: Fast Rule-Based Hard Checks ---
    final Position latest = positions.last;
    
    // Check 1: Android/iOS isMocked ground-truth indicator
    if (latest.isMocked) {
      debugPrint('[AnomalyService] CHEAT DETECTED: Device reported isMocked=true');
      return const AnomalyResult(
        isAnomaly: true,
        anomalyScore: 99.0,
        reason: 'Mock location provider detected',
        features: {'isMocked': 1.0},
      );
    }

    // Check 2: Instantaneous human speed ceiling (> 25 km/h is impossible for recreational runners)
    final double instantSpeedKmh = latest.speed * 3.6;
    if (instantSpeedKmh > _maxHumanSpeedKmh) {
      debugPrint('[AnomalyService] CHEAT DETECTED: Instant speed ${instantSpeedKmh.toStringAsFixed(1)} km/h exceeds human limits');
      return AnomalyResult(
        isAnomaly: true,
        anomalyScore: 10.0 + (instantSpeedKmh - _maxHumanSpeedKmh),
        reason: 'Instantaneous speed exceeded ${_maxHumanSpeedKmh.toStringAsFixed(0)} km/h ($instantSpeedKmh km/h)',
        features: {'speed_kmh': instantSpeedKmh},
      );
    }

    // Check 3: Teleport check against previous position
    if (positions.length >= 2) {
      final Position prev = positions[positions.length - 2];
      final double dtSeconds = (latest.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0).abs();
      if (dtSeconds > 0 && dtSeconds <= 3.0) {
        final double distMeters = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          latest.latitude,
          latest.longitude,
        );
        final double stepSpeedKmh = (distMeters / dtSeconds) * 3.6;
        if (stepSpeedKmh > 35.0 || (distMeters > 50.0 && dtSeconds <= 1.0)) {
          debugPrint('[AnomalyService] CHEAT DETECTED: Teleport jump of ${distMeters.toStringAsFixed(1)}m in ${dtSeconds}s ($stepSpeedKmh km/h)');
          return AnomalyResult(
            isAnomaly: true,
            anomalyScore: 15.0,
            reason: 'Position teleportation detected ($distMeters m jump in ${dtSeconds}s)',
            features: {'stepSpeedKmh': stepSpeedKmh, 'distMeters': distMeters},
          );
        }
      }
    }

    if (positions.length < 3) {
      return AnomalyResult.genuine;
    }

    // --- Tier 2: Multi-Feature Statistical Anomaly Scoring ---
    final Map<String, double> features = _extractFeatures(positions);
    final List<double> fVector = [
      features['avg_speed'] ?? 0.0,
      features['max_accel'] ?? 0.0,
      features['heading_rate'] ?? 0.0,
      features['sinuosity'] ?? 1.0,
      features['stop_freq'] ?? 0.0,
    ];

    double weightedScore = 0.0;
    for (int i = 0; i < 5; i++) {
      final double z = ((fVector[i] - _means[i]) / _stds[i]).abs();
      weightedScore += z * _weights[i];
    }
    final double normalizedScore = weightedScore / 7.5;

    final bool isAnomaly = normalizedScore > _anomalyThreshold;
    final String reason = isAnomaly
        ? 'Unnatural movement telemetry pattern (Score: ${normalizedScore.toStringAsFixed(2)})'
        : 'Genuine running gait';

    if (isAnomaly) {
      debugPrint('[AnomalyService] Suspicious telemetry segment scored: ${normalizedScore.toStringAsFixed(2)} > $_anomalyThreshold');
    }

    return AnomalyResult(
      isAnomaly: isAnomaly,
      anomalyScore: normalizedScore,
      reason: reason,
      features: features,
    );
  }

  Map<String, double> _extractFeatures(List<Position> window) {
    final List<double> speeds = window.map((p) => p.speed * 3.6).toList();
    final double avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;

    // Max acceleration
    double maxAccel = 0.0;
    for (int i = 0; i < window.length - 1; i++) {
      final dt = (window[i + 1].timestamp.difference(window[i].timestamp).inMilliseconds / 1000.0).abs();
      if (dt > 0) {
        final dv = (window[i + 1].speed - window[i].speed).abs();
        final accel = dv / dt;
        if (accel > maxAccel) maxAccel = accel;
      }
    }

    // Heading change rate
    double totalHeadingDelta = 0.0;
    for (int i = 0; i < window.length - 1; i++) {
      double diff = (window[i + 1].heading - window[i].heading).abs();
      if (diff > 180) diff = 360 - diff;
      totalHeadingDelta += diff;
    }
    final double headingRate = totalHeadingDelta / (window.length - 1);

    // Sinuosity (direct distance / total path)
    double totalPath = 0.0;
    for (int i = 0; i < window.length - 1; i++) {
      totalPath += Geolocator.distanceBetween(
        window[i].latitude,
        window[i].longitude,
        window[i + 1].latitude,
        window[i + 1].longitude,
      );
    }
    final double directDist = Geolocator.distanceBetween(
      window.first.latitude,
      window.first.longitude,
      window.last.latitude,
      window.last.longitude,
    );
    final double sinuosity = directDist / (totalPath + 0.01);
    final double stopFreq = speeds.where((s) => s < 1.0).length / speeds.length;

    return {
      'avg_speed': avgSpeed,
      'max_accel': maxAccel,
      'heading_rate': headingRate,
      'sinuosity': sinuosity.clamp(0.0, 1.0),
      'stop_freq': stopFreq,
    };
  }
}
