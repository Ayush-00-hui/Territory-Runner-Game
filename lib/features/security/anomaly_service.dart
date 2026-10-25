import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';

import '../../core/logging/app_logger.dart';
import '../../models/activity_type.dart';
import '../../services/motion_sensor_service.dart';

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

/// On-Device Rule-Based & Machine Learning GPS Anomaly Detector.
///
/// Multi-stage verification architecture:
/// - Tier 1: Deterministic Physical Constraints (isMocked, human velocity ceiling,
///   teleport jump, biomechanical acceleration, cadence stillness rule).
/// - Tier 2: Production LightGBM Decision Tree Ensemble with cryptographic SHA256
///   integrity verification and runtime feature-flagging.
class AnomalyService {
  static final AnomalyService _instance = AnomalyService._internal();
  factory AnomalyService() => _instance;

  AnomalyService._internal() {
    loadModelConfig();
    loadProductionModel();
  }

  // Feature Flag: fallback to rules-only when false
  bool useMlModel = true;

  // Tier 2 ML Model State
  String _modelVersion = '3.0.0';
  String _modelSha256 = '';
  bool _isModelVerified = false;
  double _mlThreshold = 0.50;
  List<Map<String, dynamic>> _trees = [];

  String get modelVersion => _modelVersion;
  String get modelSha256 => _modelSha256;
  bool get isModelVerified => _isModelVerified;
  double get mlThreshold => _mlThreshold;

  // Calibrated baseline parameters matching assets/models/gps_anomaly_detector.json
  List<double> _means = [9.8205, 1.0521, 7.2114, 0.772, 0.0];
  List<double> _stds = [1.4204, 1.3905, 5.9006, 0.1767, 0.05];
  List<double> _weights = [2.5, 2.0, 1.2, 1.0, 0.8];
  double _anomalyThreshold = 1.8;
  double _maxHumanSpeedKmh = 25.0;
  bool _isConfigLoaded = false;

  bool get isConfigLoaded => _isConfigLoaded;
  List<double> get means => List.unmodifiable(_means);
  List<double> get stds => List.unmodifiable(_stds);
  List<double> get weights => List.unmodifiable(_weights);
  double get anomalyThreshold => _anomalyThreshold;

  /// Floors standard deviation at a sane minimum:
  /// max(std, 0.05 * |mean|, feature-specific epsilon).
  /// For stop_frequency (index 4) the minimum epsilon is 0.05; never 0.0001.
  static double sanitizeStd(int index, double std, double mean) {
    double floor = 0.05 * mean.abs();
    double minEps = index == 4 ? 0.05 : 0.01;
    if (floor < minEps) floor = minEps;
    if (std < floor) return floor;
    return std;
  }

  /// Loads baseline statistical parameters from the asset JSON configuration
  Future<void> loadModelConfig([
    String assetPath = 'assets/models/gps_anomaly_detector.json',
  ]) async {
    try {
      final String jsonStr = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> data =
          jsonDecode(jsonStr) as Map<String, dynamic>;

      if (data.containsKey('means') && data['means'] is List) {
        _means = (data['means'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
      }
      if (data.containsKey('stds') && data['stds'] is List) {
        final rawStds = (data['stds'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        _stds = List.generate(rawStds.length, (i) {
          final mean = i < _means.length ? _means[i] : 0.0;
          return sanitizeStd(i, rawStds[i], mean);
        });
      }
      if (data.containsKey('feature_weights') &&
          data['feature_weights'] is List) {
        _weights = (data['feature_weights'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
      }
      if (data.containsKey('anomaly_threshold') &&
          data['anomaly_threshold'] is num) {
        _anomalyThreshold = (data['anomaly_threshold'] as num).toDouble();
      }
      if (data.containsKey('hard_rules') && data['hard_rules'] is Map) {
        final hardRules = data['hard_rules'] as Map;
        if (hardRules.containsKey('max_human_speed_kmh')) {
          _maxHumanSpeedKmh = (hardRules['max_human_speed_kmh'] as num)
              .toDouble();
        }
      }
      _isConfigLoaded = true;
      AppLogger.info(
        'Statistical anomaly detector configured from $assetPath',
        tag: 'AnomalyService',
      );
    } catch (e) {
      AppLogger.debug(
        'Using calibrated in-memory baseline parameters (asset load deferred): $e',
        tag: 'AnomalyService',
      );
    }
  }

  /// Loads and cryptographically validates the production LightGBM tree ensemble from assets.
  Future<bool> loadProductionModel([
    String treesAssetPath = 'assets/models/anomaly_detector_trees.json',
    String metaAssetPath = 'assets/models/anomaly_detector_meta.json',
  ]) async {
    try {
      final String metaJson = await rootBundle.loadString(metaAssetPath);
      final String treesJson = await rootBundle.loadString(treesAssetPath);
      return loadModelFromStrings(treeJson: treesJson, metaJson: metaJson);
    } catch (e) {
      _isModelVerified = false;
      AppLogger.debug(
        'Tier 2 ML model deferred/unavailable ($e); falling back to Tier 1 rules & Z-score',
        tag: 'AnomalyService',
      );
      return false;
    }
  }

  /// Loads and verifies model trees and metadata from JSON strings with cryptographic SHA256 checking.
  bool loadModelFromStrings({
    required String treeJson,
    required String metaJson,
  }) {
    try {
      final Map<String, dynamic> meta =
          jsonDecode(metaJson) as Map<String, dynamic>;
      final bytes = utf8.encode(treeJson);
      final String actualSha = sha256.convert(bytes).toString();

      final String expectedSha = (meta['sha256_trees'] as String?) ?? '';
      if (expectedSha.isNotEmpty && actualSha != expectedSha) {
        _isModelVerified = false;
        AppLogger.warning(
          'Model integrity check failed: expected SHA256 $expectedSha, got $actualSha',
          tag: 'AnomalyService',
        );
        return false;
      }

      final Map<String, dynamic> model =
          jsonDecode(treeJson) as Map<String, dynamic>;
      final String modelVer = (model['model_version'] as String?) ?? '';
      final String metaVer = (meta['model_version'] as String?) ?? '';
      if (metaVer.isNotEmpty && modelVer != metaVer) {
        _isModelVerified = false;
        AppLogger.warning(
          'Model version mismatch: meta=$metaVer, model=$modelVer',
          tag: 'AnomalyService',
        );
        return false;
      }

      _modelVersion = modelVer.isNotEmpty ? modelVer : '3.0.0';
      _modelSha256 = actualSha;
      if (meta.containsKey('threshold') && meta['threshold'] is num) {
        _mlThreshold = (meta['threshold'] as num).toDouble();
      }

      final rawTrees = model['trees'] as List;
      _trees = rawTrees
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _isModelVerified = true;

      AppLogger.info(
        'LightGBM Tier 2 ML ensemble verified (v$_modelVersion, SHA: ${_modelSha256.substring(0, 8)}..., trees: ${_trees.length})',
        tag: 'AnomalyService',
      );
      return true;
    } catch (e) {
      _isModelVerified = false;
      AppLogger.error(
        'Failed to parse or verify ML model: $e',
        tag: 'AnomalyService',
      );
      return false;
    }
  }

  double _evaluateNode(Map<String, dynamic> node, List<double> features) {
    if (node.containsKey('leaf_value') && node['leaf_value'] != null) {
      return (node['leaf_value'] as num).toDouble();
    }
    final int splitFeature = (node['split_feature'] as num).toInt();
    final double threshold = (node['threshold'] as num).toDouble();
    final double val =
        (splitFeature >= 0 && splitFeature < features.length)
            ? features[splitFeature]
            : 0.0;
    if (val <= threshold) {
      if (node.containsKey('left') && node['left'] != null) {
        return _evaluateNode(node['left'] as Map<String, dynamic>, features);
      }
    } else {
      if (node.containsKey('right') && node['right'] != null) {
        return _evaluateNode(node['right'] as Map<String, dynamic>, features);
      }
    }
    return 0.0;
  }

  /// Evaluates features through the ensemble and returns the anomaly probability in [0, 1].
  double predictProbability(List<double> features) {
    if (_trees.isEmpty) return 0.0;
    double rawLogit = 0.0;
    for (final tree in _trees) {
      rawLogit += _evaluateNode(tree, features);
    }
    return 1.0 / (1.0 + math.exp(-rawLogit));
  }

  static double _initialBearingDeg(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final dlambda = (lon2 - lon1) * math.pi / 180.0;
    final y = math.sin(dlambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dlambda);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  static double _headingChangeDeg(double b1, double b2) {
    final diff = ((b2 - b1).abs()) % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  static double _calcMean(List<double> vals) {
    if (vals.isEmpty) return 0.0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  static double _calcStd(List<double> vals) {
    if (vals.length <= 1) return 0.0;
    final m = _calcMean(vals);
    double sumSq = 0.0;
    for (final v in vals) {
      final d = v - m;
      sumSq += d * d;
    }
    return math.sqrt(sumSq / vals.length);
  }

  static double _calcMax(List<double> vals) {
    if (vals.isEmpty) return 0.0;
    return vals.reduce(math.max);
  }

  static double _calcPercentile(List<double> vals, double p) {
    if (vals.isEmpty) return 0.0;
    final sorted = List<double>.from(vals)..sort();
    final rank = (p / 100.0) * (sorted.length - 1);
    final low = rank.floor();
    final high = rank.ceil();
    if (low == high) return sorted[low];
    final weight = rank - low;
    return sorted[low] * (1.0 - weight) + sorted[high] * weight;
  }

  static double _calcMedian(List<double> vals) => _calcPercentile(vals, 50.0);

  static double _calcShannonEntropy(
    List<double> vals,
    int nBins,
    double minVal,
    double maxVal,
  ) {
    if (vals.isEmpty || nBins <= 0) return 0.0;
    final binWidth = (maxVal - minVal) / nBins;
    final counts = List<int>.filled(nBins, 0);

    for (final v in vals) {
      int idx = ((v - minVal) / binWidth).floor();
      if (idx < 0) idx = 0;
      if (idx >= nBins) idx = nBins - 1;
      counts[idx]++;
    }

    final total = vals.length.toDouble();
    double ent = 0.0;
    for (final c in counts) {
      if (c > 0) {
        final p = c / total;
        ent -= p * (math.log(p) / math.ln2);
      }
    }
    return ent;
  }

  /// Extracts the exact 25 window features matching Python and Go implementations.
  List<double> extract25Features(
    List<Position> window, [
    List<MotionWindow>? motionWindows,
  ]) {
    final n = window.length;
    if (n < 2) return List<double>.filled(25, 0.0);

    final List<double> dists = [];
    final List<double> dts = [];
    final List<double> speedsMs = [];
    final List<double> bearings = [];
    final List<double> accuracies = [];

    for (int i = 1; i < n; i++) {
      final pPrev = window[i - 1];
      final pCurr = window[i];

      double dt =
          (pCurr.timestamp.difference(pPrev.timestamp).inMilliseconds /
                  1000.0)
              .abs();
      if (dt <= 0) dt = 0.001;
      dts.add(dt);

      final d = Geolocator.distanceBetween(
        pPrev.latitude,
        pPrev.longitude,
        pCurr.latitude,
        pCurr.longitude,
      );
      dists.add(d);

      final sMs = d / dt;
      speedsMs.add(sMs);

      final b = _initialBearingDeg(
        pPrev.latitude,
        pPrev.longitude,
        pCurr.latitude,
        pCurr.longitude,
      );
      bearings.add(b);

      final acc = pCurr.accuracy > 0 ? pCurr.accuracy : 4.0;
      accuracies.add(acc);
    }

    final speedsKmh = speedsMs.map((s) => s * 3.6).toList();

    final List<double> accels = [];
    for (int i = 1; i < speedsMs.length; i++) {
      final dtAcc = dts[i];
      accels.add((speedsMs[i] - speedsMs[i - 1]) / dtAcc);
    }
    if (accels.isEmpty) accels.add(0.0);

    final List<double> jerks = [];
    for (int i = 1; i < accels.length; i++) {
      final dtJerk = (i + 1 < dts.length) ? dts[i + 1] : dts[i];
      jerks.add((accels[i] - accels[i - 1]) / dtJerk);
    }
    if (jerks.isEmpty) jerks.add(0.0);

    final List<double> bearingDiffs = [];
    final List<double> turnRates = [];
    for (int i = 1; i < bearings.length; i++) {
      final diff = _headingChangeDeg(bearings[i - 1], bearings[i]);
      bearingDiffs.add(diff);
      turnRates.add(diff / dts[i]);
    }
    if (bearingDiffs.isEmpty) bearingDiffs.add(0.0);
    if (turnRates.isEmpty) turnRates.add(0.0);

    final netDisp = Geolocator.distanceBetween(
      window.first.latitude,
      window.first.longitude,
      window.last.latitude,
      window.last.longitude,
    );
    final totalPath = dists.fold(0.0, (a, b) => a + b);
    double sinuosity = totalPath / math.max(netDisp, 1.0);
    sinuosity = sinuosity.clamp(1.0, 50.0);

    final stops = speedsMs.where((s) => s < 0.5).length;
    final stopRatio = stops / speedsMs.length;

    final absAccels = accels.map((a) => a.abs()).toList();
    final absJerks = jerks.map((j) => j.abs()).toList();

    double cadenceSPM = 0.0;
    double motionEnergy = 0.0;
    double cadenceConf = 0.0;

    if (motionWindows != null && motionWindows.isNotEmpty) {
      double sumC = 0.0;
      double sumE = 0.0;
      double sumConf = 0.0;
      for (final w in motionWindows) {
        sumC += w.cadenceSpm;
        sumE += w.motionEnergy;
        sumConf += w.cadenceConfidence;
      }
      final nw = motionWindows.length.toDouble();
      cadenceSPM = sumC / nw;
      motionEnergy = sumE / nw;
      cadenceConf = sumConf / nw;
    }

    return [
      _calcMean(speedsKmh), // 0: speed_mean_kmh
      _calcStd(speedsKmh), // 1: speed_std_kmh
      _calcMax(speedsKmh), // 2: speed_max_kmh
      _calcPercentile(speedsKmh, 95.0), // 3: speed_p95_kmh
      _calcMedian(speedsKmh), // 4: speed_median_kmh
      _calcMean(absAccels), // 5: accel_mean_ms2
      _calcStd(accels), // 6: accel_std_ms2
      _calcMax(absAccels), // 7: accel_max_ms2
      _calcPercentile(absAccels, 95.0), // 8: accel_p95_ms2
      _calcMean(absJerks), // 9: jerk_mean_ms3
      _calcStd(jerks), // 10: jerk_std_ms3
      _calcMax(absJerks), // 11: jerk_max_ms3
      _calcMean(turnRates), // 12: heading_turn_mean_degs
      _calcStd(turnRates), // 13: heading_turn_std_degs
      _calcShannonEntropy(bearingDiffs, 16, 0.0, 180.0), // 14: heading_entropy
      sinuosity, // 15: sinuosity
      stopRatio, // 16: stop_ratio
      _calcMean(accuracies), // 17: gps_accuracy_mean
      _calcStd(accuracies), // 18: gps_accuracy_std
      _calcMax(accuracies), // 19: gps_accuracy_max
      _calcMedian(dts), // 20: dt_median_s
      _calcStd(dts), // 21: dt_std_s
      cadenceSPM, // 22: cadence_spm
      motionEnergy, // 23: motion_energy
      cadenceConf, // 24: cadence_confidence
    ];
  }

  /// Scores a sliding window of recent GPS positions with activity-specific calibration.
  ///
  /// Multi-stage architecture:
  /// - Tier 1: Fast deterministic physics rules & cadence stillness check.
  /// - Tier 2: Production 25-feature ML tree ensemble when verified and enabled.
  ///   Gracefully falls back to Tier 1 + Z-score when feature-flagged off or unverified.
  AnomalyResult scoreSegment(
    List<Position> positions, [
    ExerciseActivityType? activityType,
    List<MotionWindow>? motionWindows,
  ]) {
    if (positions.isEmpty) return AnomalyResult.genuine;

    final activity = activityType ?? ExerciseActivityType.running;
    final double maxInstantSpeedKmh =
        activity == ExerciseActivityType.running
            ? _maxHumanSpeedKmh
            : activity.maxSpeedKmh;
    final double maxTeleportSpeedKmh =
        activity == ExerciseActivityType.cycling
            ? 65.0
            : (activity == ExerciseActivityType.walking ? 15.0 : 35.0);

    // --- Tier 1: Fast Rule-Based Hard Checks ---
    final Position latest = positions.last;

    // Check 1: Android/iOS isMocked ground-truth indicator
    if (latest.isMocked) {
      AppLogger.warning(
        'CHEAT DETECTED: Device reported isMocked=true',
        tag: 'AnomalyService',
      );
      return const AnomalyResult(
        isAnomaly: true,
        anomalyScore: 99.0,
        reason: 'Mock location provider detected',
        features: {'isMocked': 1.0},
      );
    }

    // Check 2: Instantaneous human speed ceiling
    final double instantSpeedKmh = latest.speed * 3.6;
    if (instantSpeedKmh > maxInstantSpeedKmh) {
      AppLogger.warning(
        'CHEAT DETECTED: Instant speed ${instantSpeedKmh.toStringAsFixed(1)} km/h exceeds ${activity.displayName.toLowerCase()} limits (${maxInstantSpeedKmh.toStringAsFixed(1)} km/h)',
        tag: 'AnomalyService',
      );
      return AnomalyResult(
        isAnomaly: true,
        anomalyScore: 10.0 + (instantSpeedKmh - maxInstantSpeedKmh),
        reason:
            'Instantaneous speed exceeded ${maxInstantSpeedKmh.toStringAsFixed(0)} km/h ($instantSpeedKmh km/h)',
        features: {'speed_kmh': instantSpeedKmh},
      );
    }

    // Check 3: Teleport check against previous position
    if (positions.length >= 2) {
      final Position prev = positions[positions.length - 2];
      final double dtSeconds =
          (latest.timestamp.difference(prev.timestamp).inMilliseconds /
                  1000.0)
              .abs();
      if (dtSeconds > 0 && dtSeconds <= 3.0) {
        final double distMeters = Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          latest.latitude,
          latest.longitude,
        );
        final double stepSpeedKmh = (distMeters / dtSeconds) * 3.6;
        if (stepSpeedKmh > maxTeleportSpeedKmh ||
            (distMeters > 50.0 && dtSeconds <= 1.0)) {
          AppLogger.warning(
            'CHEAT DETECTED: Teleport jump of ${distMeters.toStringAsFixed(1)}m in ${dtSeconds}s ($stepSpeedKmh km/h)',
            tag: 'AnomalyService',
          );
          return AnomalyResult(
            isAnomaly: true,
            anomalyScore: 15.0,
            reason:
                'Position teleportation detected ($distMeters m jump in ${dtSeconds}s)',
            features: {
              'stepSpeedKmh': stepSpeedKmh,
              'distMeters': distMeters,
            },
          );
        }

        // Check 3b: Biomechanical acceleration ceiling check
        if (dtSeconds > 0.2 && dtSeconds <= 3.0) {
          final double dv = (latest.speed - prev.speed).abs();
          final double accel = dv / dtSeconds;
          final double maxAccelLimit =
              activity == ExerciseActivityType.cycling ? 12.0 : 8.0;
          if (accel > maxAccelLimit) {
            AppLogger.warning(
              'CHEAT DETECTED: Acceleration ${accel.toStringAsFixed(2)} m/s² exceeds ${activity.displayName.toLowerCase()} limit (${maxAccelLimit.toStringAsFixed(1)} m/s²)',
              tag: 'AnomalyService',
            );
            return AnomalyResult(
              isAnomaly: true,
              anomalyScore: 45.0 + (accel - maxAccelLimit),
              reason:
                  'Biomechanical acceleration limit exceeded: ${accel.toStringAsFixed(2)} m/s² (max ${maxAccelLimit.toStringAsFixed(1)} m/s² for ${activity.displayName.toLowerCase()})',
              features: {'max_accel': accel},
            );
          }
        }
      }
    }

    // Check 4: Average speed ceiling check across window
    if (positions.length >= 3) {
      final double totalTimeSeconds =
          (latest.timestamp
                      .difference(positions.first.timestamp)
                      .inMilliseconds /
                  1000.0)
              .abs();
      if (totalTimeSeconds >= 3.0) {
        double totalDist = 0.0;
        for (int i = 0; i < positions.length - 1; i++) {
          totalDist += Geolocator.distanceBetween(
            positions[i].latitude,
            positions[i].longitude,
            positions[i + 1].latitude,
            positions[i + 1].longitude,
          );
        }
        final double windowAvgSpeedKmh =
            (totalDist / totalTimeSeconds) * 3.6;
        if (windowAvgSpeedKmh > activity.maxAverageSpeedKmh) {
          AppLogger.warning(
            'CHEAT DETECTED: Average speed ${windowAvgSpeedKmh.toStringAsFixed(1)} km/h exceeds ${activity.displayName.toLowerCase()} endurance ceiling (${activity.maxAverageSpeedKmh} km/h)',
            tag: 'AnomalyService',
          );
          return AnomalyResult(
            isAnomaly: true,
            anomalyScore:
                50.0 + (windowAvgSpeedKmh - activity.maxAverageSpeedKmh),
            reason:
                'Average speed ${windowAvgSpeedKmh.toStringAsFixed(1)} km/h exceeds ${activity.displayName.toLowerCase()} endurance ceiling (${activity.maxAverageSpeedKmh} km/h)',
            features: {'avg_speed_kmh': windowAvgSpeedKmh},
          );
        }
      }
    }

    // Check 4b: Identical-step GPS replay detection
    if (positions.length >= 4) {
      int identicalSteps = 0;
      for (int i = 1; i < positions.length; i++) {
        final p1 = positions[i - 1];
        final p2 = positions[i];
        if (p1.latitude == p2.latitude && p1.longitude == p2.longitude) {
          identicalSteps++;
        }
      }
      if (identicalSteps >= positions.length / 2) {
        AppLogger.warning(
          'CHEAT DETECTED: Excessive frozen GPS replay breadcrumbs',
          tag: 'AnomalyService',
        );
        return const AnomalyResult(
          isAnomaly: true,
          anomalyScore: 8.0,
          reason:
              'Excessive frozen/replay identical GPS breadcrumbs detected',
          features: {'frozenRatio': 1.0},
        );
      }
    }

    // Check 5: Fast Cadence Stillness Rule (speed > 6 km/h with cadence < 30 SPM & motion energy < 0.08)
    if (activity != ExerciseActivityType.cycling &&
        motionWindows != null &&
        motionWindows.isNotEmpty) {
      double avgCadence = 0.0;
      double avgEnergy = 0.0;
      for (final mw in motionWindows) {
        avgCadence += mw.cadenceSpm;
        avgEnergy += mw.motionEnergy;
      }
      avgCadence /= motionWindows.length;
      avgEnergy /= motionWindows.length;

      final double currentSpeedKmh = latest.speed * 3.6;
      if (currentSpeedKmh > 6.0 && avgCadence < 30.0 && avgEnergy < 0.08) {
        AppLogger.warning(
          'CHEAT DETECTED: High speed (${currentSpeedKmh.toStringAsFixed(1)} km/h) with stationary cadence (${avgCadence.toStringAsFixed(1)} SPM) indicates motorized vehicle transit',
          tag: 'AnomalyService',
        );
        return AnomalyResult(
          isAnomaly: true,
          anomalyScore: 60.0 + (currentSpeedKmh - 6.0),
          reason:
              'Vehicle transit detected: speed ${currentSpeedKmh.toStringAsFixed(1)} km/h without running step cadence (${avgCadence.toStringAsFixed(0)} SPM)',
          features: {
            'speed_kmh': currentSpeedKmh,
            'cadence_spm': avgCadence,
            'motion_energy': avgEnergy,
          },
        );
      }
    }

    if (positions.length < 3) {
      return AnomalyResult.genuine;
    }

    // --- Tier 2: Machine Learning Decision Tree Ensemble ---
    if (useMlModel &&
        _isModelVerified &&
        motionWindows != null &&
        motionWindows.isNotEmpty) {
      final List<double> f25 = extract25Features(positions, motionWindows);
      final double prob = predictProbability(f25);
      final bool isMlAnomaly = prob >= _mlThreshold;

      final featuresMap = <String, double>{
        'ml_anomaly_prob': prob,
        'cadence_spm': f25[22],
        'motion_energy': f25[23],
        'cadence_confidence': f25[24],
        'speed_mean_kmh': f25[0],
        'sinuosity': f25[15],
      };

      if (isMlAnomaly) {
        final score = 50.0 + (prob * 50.0);
        AppLogger.warning(
          'Tier 2 ML anomaly flagged: prob=${(prob * 100).toStringAsFixed(1)}% >= ${_mlThreshold * 100}% (score=$score)',
          tag: 'AnomalyService',
        );
        return AnomalyResult(
          isAnomaly: true,
          anomalyScore: score,
          reason:
              'Tier 2 ML Ensemble detected unnatural motion pattern (p=${(prob * 100).toStringAsFixed(1)}%)',
          features: featuresMap,
        );
      }

      return AnomalyResult(
        isAnomaly: false,
        anomalyScore: prob * 10.0,
        reason: 'Normal human gait verified by Tier 2 ML',
        features: featuresMap,
      );
    }

    // --- Tier 2 Fallback: Multi-Feature Statistical Anomaly Scoring (Z-score) ---
    final Map<String, double> features = _extractFeatures(positions);
    final List<double> fVector = [
      features['avg_speed'] ?? 0.0,
      features['max_accel'] ?? 0.0,
      features['heading_rate'] ?? 0.0,
      features['sinuosity'] ?? 1.0,
      features['stop_freq'] ?? 0.0,
    ];

    final double normalizedScore = scoreFeatureVector(fVector);

    final bool isAnomaly = normalizedScore > _anomalyThreshold;
    final String reason =
        isAnomaly
            ? 'Unnatural movement pattern (Score: ${normalizedScore.toStringAsFixed(2)})'
            : 'Genuine running gait';

    if (isAnomaly) {
      AppLogger.warning(
        'Suspicious movement segment scored: ${normalizedScore.toStringAsFixed(2)} > $_anomalyThreshold',
        tag: 'AnomalyService',
      );
    }

    return AnomalyResult(
      isAnomaly: isAnomaly,
      anomalyScore: normalizedScore,
      reason: reason,
      features: features,
    );
  }

  /// Computes the normalized weighted Z-score for a 5-element feature vector,
  /// capping each per-feature |z| at 6.0 so no single feature can dominate the score.
  double scoreFeatureVector(List<double> fVector) {
    double weightedScore = 0.0;
    for (int i = 0; i < 5; i++) {
      double z = ((fVector[i] - _means[i]) / _stds[i]).abs();
      if (z > 6.0) {
        z = 6.0;
      }
      weightedScore += z * _weights[i];
    }
    return weightedScore / 7.5;
  }

  Map<String, double> _extractFeatures(List<Position> window) {
    final List<double> speeds =
        window.map((p) => p.speed * 3.6).toList();
    final double avgSpeed =
        speeds.reduce((a, b) => a + b) / speeds.length;

    // Max acceleration
    double maxAccel = 0.0;
    for (int i = 0; i < window.length - 1; i++) {
      final dt =
          (window[i + 1].timestamp
                      .difference(window[i].timestamp)
                      .inMilliseconds /
                  1000.0)
              .abs();
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
    final double headingRate =
        totalHeadingDelta / (window.length - 1);

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
    final double stopFreq =
        speeds.where((s) => s < 1.0).length / speeds.length;

    return {
      'avg_speed': avgSpeed,
      'max_accel': maxAccel,
      'heading_rate': headingRate,
      'sinuosity': sinuosity.clamp(0.0, 1.0),
      'stop_freq': stopFreq,
    };
  }
}
