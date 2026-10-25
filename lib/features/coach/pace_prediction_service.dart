import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/logging/app_logger.dart';
import '../../models/runner_profile.dart';

/// A single completed past run session used for sequential feature extraction
class PastRun {
  final double distanceKm;
  final double paceMinKm;
  final double elevationGainM;
  final DateTime timestamp;

  const PastRun({
    required this.distanceKm,
    required this.paceMinKm,
    this.elevationGainM = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'distance_km': distanceKm,
    'pace_min_km': paceMinKm,
    'elevation_gain_m': elevationGainM,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PastRun.fromJson(Map<String, dynamic> json) => PastRun(
    distanceKm: (json['distance_km'] as num).toDouble(),
    paceMinKm: (json['pace_min_km'] as num).toDouble(),
    elevationGainM: (json['elevation_gain_m'] as num?)?.toDouble() ?? 0.0,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// Quantile Prediction Interval [p10, p50, p90]
class PredictionInterval {
  final double p10;
  final double p50;
  final double p90;

  const PredictionInterval({
    required this.p10,
    required this.p50,
    required this.p90,
  });

  /// Width of the 80% coverage interval (p90 - p10)
  double get width => p90 - p10;

  @override
  String toString() =>
      '[p10: ${p10.toStringAsFixed(2)}, p50: ${p50.toStringAsFixed(2)}, p90: ${p90.toStringAsFixed(2)}]';
}

/// Result of pace and distance quantile prediction
class PaceDistancePrediction {
  final PredictionInterval distanceInterval;
  final PredictionInterval paceInterval;
  final double targetDistanceKm; // p50 target
  final double stretchDistanceKm; // p90 stretch goal
  final double conservativeDistanceKm; // p10 conservative baseline
  final double targetPaceMinKm; // p50 pace
  final String paceFormatted;
  final String fitnessTier;
  final bool isColdStart;
  final String sourceLabel;

  const PaceDistancePrediction({
    required this.distanceInterval,
    required this.paceInterval,
    required this.targetDistanceKm,
    required this.stretchDistanceKm,
    required this.conservativeDistanceKm,
    required this.targetPaceMinKm,
    required this.paceFormatted,
    required this.fitnessTier,
    required this.isColdStart,
    required this.sourceLabel,
  });

  // Backward compatibility getters
  double get predictedDistanceKm => targetDistanceKm;
  double get predictedPaceMinKm => targetPaceMinKm;
  double get confidenceScore => isColdStart ? 0.60 : 0.90;
  double get intervalWidthKm => distanceInterval.width;
}

/// Production LightGBM Quantile Regressor for Pace & Achievable Distance.
///
/// Features extracted from user's last N runs:
/// 1. pace_mean_last_n
/// 2. pace_std_last_n
/// 3. pace_min_last_n
/// 4. pace_last_run
/// 5. dist_mean_last_n
/// 6. dist_std_last_n
/// 7. dist_max_last_n
/// 8. dist_last_run
/// 9. volume_last_n
/// 10. elevation_mean_last_n
/// 11. elevation_last_run
/// 12. rest_days
/// 13. time_of_day_hour
/// 14. time_of_day_sin
/// 15. time_of_day_cos
/// 16. streak
class PacePredictionService {
  static final PacePredictionService _instance =
      PacePredictionService._internal();
  factory PacePredictionService() => _instance;

  PacePredictionService._internal() {
    loadProductionModel();
  }

  static const int minRunsForPersonalization = 5;

  String _modelVersion = '1.0.0';
  String _modelSha256 = '';
  bool _isModelVerified = false;

  Map<String, List<Map<String, dynamic>>> _distanceTrees = {};
  Map<String, List<Map<String, dynamic>>> _paceTrees = {};

  String get modelVersion => _modelVersion;
  String get modelSha256 => _modelSha256;
  bool get isModelVerified => _isModelVerified;

  /// Loads and verifies production quantile decision trees from assets.
  Future<bool> loadProductionModel([
    String treesAssetPath = 'assets/models/pace_distance_trees.json',
    String metaAssetPath = 'assets/models/pace_distance_meta.json',
  ]) async {
    try {
      final String metaJson = await rootBundle.loadString(metaAssetPath);
      final String treesJson = await rootBundle.loadString(treesAssetPath);
      return loadModelFromStrings(treeJson: treesJson, metaJson: metaJson);
    } catch (e) {
      _isModelVerified = false;
      AppLogger.debug(
        'Pace/distance ML trees deferred ($e); using level-based baseline fallback.',
        tag: 'PacePredictionService',
      );
      return false;
    }
  }

  /// In-memory loader with cryptographic SHA256 integrity validation
  bool loadModelFromStrings({
    required String treeJson,
    required String metaJson,
  }) {
    try {
      final Map<String, dynamic> meta =
          jsonDecode(metaJson) as Map<String, dynamic>;
      final normalizedTreeJson = treeJson.replaceAll('\r\n', '\n');
      final bytes = utf8.encode(normalizedTreeJson);
      final String actualSha = sha256.convert(bytes).toString();

      final String expectedSha = (meta['sha256_trees'] as String?) ?? '';
      if (expectedSha.isNotEmpty && actualSha != expectedSha) {
        _isModelVerified = false;
        AppLogger.warning(
          'Pace model integrity check failed: expected $expectedSha, got $actualSha',
          tag: 'PacePredictionService',
        );
        return false;
      }

      final Map<String, dynamic> bundle =
          jsonDecode(treeJson) as Map<String, dynamic>;
      final String modelVer = (bundle['model_version'] as String?) ?? '';
      _modelVersion = modelVer.isNotEmpty ? modelVer : '1.0.0';
      _modelSha256 = actualSha;

      final models = bundle['models'] as Map<String, dynamic>;
      final distMap = models['distance'] as Map<String, dynamic>;
      final paceMap = models['pace'] as Map<String, dynamic>;

      _distanceTrees = {};
      for (final q in ['p10', 'p50', 'p90']) {
        if (distMap.containsKey(q)) {
          final raw = distMap[q]['trees'] as List;
          _distanceTrees[q] = raw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      _paceTrees = {};
      for (final q in ['p10', 'p50', 'p90']) {
        if (paceMap.containsKey(q)) {
          final raw = paceMap[q]['trees'] as List;
          _paceTrees[q] = raw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      _isModelVerified = true;
      AppLogger.info(
        'Pace/distance Quantile Regressor verified (v$_modelVersion, SHA: ${_modelSha256.substring(0, 8)}...)',
        tag: 'PacePredictionService',
      );
      return true;
    } catch (e) {
      _isModelVerified = false;
      AppLogger.error(
        'Failed to parse or verify pace/distance model: $e',
        tag: 'PacePredictionService',
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
    final double val = (splitFeature >= 0 && splitFeature < features.length)
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

  double _predictEnsemble(
    List<Map<String, dynamic>> trees,
    List<double> features,
  ) {
    if (trees.isEmpty) return 0.0;
    double sum = 0.0;
    for (final tree in trees) {
      sum += _evaluateNode(tree, features);
    }
    return sum;
  }

  /// Extracts the 16 features from user's last N runs and upcoming run context
  List<double> extract16Features({
    required List<PastRun> recentRuns,
    required RunnerProfile profile,
    DateTime? upcomingRunTime,
  }) {
    final runs = recentRuns.length > 5
        ? recentRuns.sublist(recentRuns.length - 5)
        : recentRuns;

    final paces = runs.map((r) => r.paceMinKm).toList();
    final dists = runs.map((r) => r.distanceKm).toList();
    final elevs = runs.map((r) => r.elevationGainM).toList();

    final double paceMean = paces.reduce((a, b) => a + b) / paces.length;
    double paceStd = 0.0;
    if (paces.length > 1) {
      final sq = paces
          .map((p) => (p - paceMean) * (p - paceMean))
          .reduce((a, b) => a + b);
      paceStd = math.sqrt(sq / paces.length);
    }
    final double paceMin = paces.reduce(math.min);
    final double paceLast = paces.last;

    final double distMean = dists.reduce((a, b) => a + b) / dists.length;
    double distStd = 0.0;
    if (dists.length > 1) {
      final sq = dists
          .map((d) => (d - distMean) * (d - distMean))
          .reduce((a, b) => a + b);
      distStd = math.sqrt(sq / dists.length);
    }
    final double distMax = dists.reduce(math.max);
    final double distLast = dists.last;
    final double volume = dists.reduce((a, b) => a + b);

    final double elevMean = elevs.reduce((a, b) => a + b) / elevs.length;
    final double elevLast = elevs.last;

    final now = upcomingRunTime ?? DateTime.now();
    final lastTime = runs.last.timestamp;
    double restDays = (now.difference(lastTime).inSeconds / 86400.0).abs();
    if (restDays > 30.0) restDays = 30.0;

    final double hour = now.hour + (now.minute / 60.0);
    final double timeSin = math.sin(2 * math.pi * hour / 24.0);
    final double timeCos = math.cos(2 * math.pi * hour / 24.0);
    final double streak = profile.currentStreak.toDouble();

    return [
      paceMean, // 0: pace_mean_last_n
      paceStd, // 1: pace_std_last_n
      paceMin, // 2: pace_min_last_n
      paceLast, // 3: pace_last_run
      distMean, // 4: dist_mean_last_n
      distStd, // 5: dist_std_last_n
      distMax, // 6: dist_max_last_n
      distLast, // 7: dist_last_run
      volume, // 8: volume_last_n
      elevMean, // 9: elevation_mean_last_n
      elevLast, // 10: elevation_last_run
      restDays, // 11: rest_days
      hour, // 12: time_of_day_hour
      timeSin, // 13: time_of_day_sin
      timeCos, // 14: time_of_day_cos
      streak, // 15: streak
    ];
  }

  /// Predicts achievable target run distance & target pace for today's session.
  ///
  /// - Cold-start users (< 5 runs): Falls back to level-based defaults, clearly labelled.
  /// - Trained users (>= 5 runs): Evaluates the LightGBM Quantile Regressors for [p10, p50, p90].
  ///   - Target goal = p50 distance
  ///   - Stretch goal = p90 distance
  ///   - Conservative = p10 distance
  PaceDistancePrediction predictTarget(
    RunnerProfile profile, {
    List<PastRun>? recentRuns,
    DateTime? upcomingRunTime,
  }) {
    final bool isColdStart =
        recentRuns == null ||
        recentRuns.length < minRunsForPersonalization ||
        !_isModelVerified;

    if (isColdStart) {
      return _predictColdStart(profile);
    }

    // Personalized ML Quantile Regression
    final List<double> features = extract16Features(
      recentRuns: recentRuns,
      profile: profile,
      upcomingRunTime: upcomingRunTime,
    );

    double d10 = _predictEnsemble(_distanceTrees['p10'] ?? [], features);
    double d50 = _predictEnsemble(_distanceTrees['p50'] ?? [], features);
    double d90 = _predictEnsemble(_distanceTrees['p90'] ?? [], features);

    double p10 = _predictEnsemble(_paceTrees['p10'] ?? [], features);
    double p50 = _predictEnsemble(_paceTrees['p50'] ?? [], features);
    double p90 = _predictEnsemble(_paceTrees['p90'] ?? [], features);

    // Enforce non-crossing quantile monotonic invariants
    d10 = math.max(1.0, d10);
    d50 = math.max(d10, d50);
    d90 = math.max(d50, d90);

    p10 = math.max(3.0, p10);
    p50 = math.max(p10, p50);
    p90 = math.max(p50, p90);

    final targetDist = double.parse(d50.toStringAsFixed(1));
    final stretchDist = double.parse(d90.toStringAsFixed(1));
    final conservativeDist = double.parse(d10.toStringAsFixed(1));

    final targetPace = double.parse(p50.toStringAsFixed(2));
    final formattedPace = _formatPace(targetPace);
    final fitnessTier = _computeFitnessTier(profile, targetDist, targetPace);

    return PaceDistancePrediction(
      distanceInterval: PredictionInterval(
        p10: conservativeDist,
        p50: targetDist,
        p90: stretchDist,
      ),
      paceInterval: PredictionInterval(
        p10: double.parse(p10.toStringAsFixed(2)),
        p50: targetPace,
        p90: double.parse(p90.toStringAsFixed(2)),
      ),
      targetDistanceKm: targetDist,
      stretchDistanceKm: stretchDist,
      conservativeDistanceKm: conservativeDist,
      targetPaceMinKm: targetPace,
      paceFormatted: formattedPace,
      fitnessTier: fitnessTier,
      isColdStart: false,
      sourceLabel: 'AI Adaptive (p10-p90 Quantile Regressor)',
    );
  }

  PaceDistancePrediction _predictColdStart(RunnerProfile profile) {
    final double levelFactor = (profile.level - 1) * 0.45;
    final double historyFactor = math.min(3.0, profile.totalDistanceKm * 0.05);
    final double streakBonus = math.min(
      1.0,
      math.max(0, profile.currentStreak - 1) * 0.08,
    );

    double targetDist = 2.5 + levelFactor + historyFactor + streakBonus;
    targetDist = double.parse(targetDist.clamp(1.5, 15.0).toStringAsFixed(1));

    final double stretchDist = double.parse(
      math.min(25.0, targetDist * 1.30).toStringAsFixed(1),
    );
    final double conservativeDist = double.parse(
      math.max(1.0, targetDist * 0.80).toStringAsFixed(1),
    );

    double basePace =
        6.8 - (profile.level * 0.15) - (profile.totalDistanceKm * 0.01);
    basePace = double.parse(basePace.clamp(4.2, 7.5).toStringAsFixed(2));

    final double paceP10 = double.parse(
      math.max(3.8, basePace * 0.90).toStringAsFixed(2),
    );
    final double paceP90 = double.parse(
      math.min(8.5, basePace * 1.15).toStringAsFixed(2),
    );

    final formattedPace = _formatPace(basePace);
    final fitnessTier = _computeFitnessTier(profile, targetDist, basePace);

    return PaceDistancePrediction(
      distanceInterval: PredictionInterval(
        p10: conservativeDist,
        p50: targetDist,
        p90: stretchDist,
      ),
      paceInterval: PredictionInterval(
        p10: paceP10,
        p50: basePace,
        p90: paceP90,
      ),
      targetDistanceKm: targetDist,
      stretchDistanceKm: stretchDist,
      conservativeDistanceKm: conservativeDist,
      targetPaceMinKm: basePace,
      paceFormatted: formattedPace,
      fitnessTier: fitnessTier,
      isColdStart: true,
      sourceLabel: 'Default baseline (5 runs needed for personalized AI)',
    );
  }

  static String _formatPace(double paceMinKm) {
    final int minutes = paceMinKm.floor();
    final int seconds = ((paceMinKm - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"/km";
  }

  static String _computeFitnessTier(
    RunnerProfile profile,
    double targetDist,
    double targetPace,
  ) {
    if (profile.level >= 10 ||
        profile.totalDistanceKm >= 100 ||
        targetPace < 4.8) {
      return 'Elite Marathoner';
    } else if (profile.level >= 5 ||
        profile.totalDistanceKm >= 30 ||
        targetDist >= 5.0) {
      return 'Intermediate Pacer';
    } else if (profile.level >= 2 || targetDist >= 3.0) {
      return 'Developing Runner';
    }
    return 'Beginner Strider';
  }
}
