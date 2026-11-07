import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../core/logging/app_logger.dart';
import '../models/user_body_profile.dart';
import 'calorie_engine_service.dart';

/// Result of a quantile calorie estimation containing uncertainty bounds.
class CalorieQuantileResult {
  /// 10th percentile conservative energy expenditure (kcal).
  final double p10Kcal;

  /// 50th percentile median expected energy expenditure (kcal).
  final double p50Kcal;

  /// 90th percentile elevated energy expenditure (kcal).
  final double p90Kcal;

  /// Predicted energy burn rate (kcal/min) at 50th percentile.
  final double burnRateKcalPerMin;

  /// Comparison baseline using historical flat factor (kcal).
  final double legacyFlatKcal;

  /// True if computed via verified on-device ML trees; false if analytical fallback.
  final bool isModelVerified;

  const CalorieQuantileResult({
    required this.p10Kcal,
    required this.p50Kcal,
    required this.p90Kcal,
    required this.burnRateKcalPerMin,
    required this.legacyFlatKcal,
    required this.isModelVerified,
  });

  /// Single integer for glanceable HUD metrics (median).
  int get displayCalories => p50Kcal.round();

  /// Honest range string for post-run summary card (e.g. "380–440 kcal (est.)").
  String get displayRange {
    final low = p10Kcal.round();
    final high = p90Kcal.round();
    if (low == high || high <= 0) {
      return '~$displayCalories kcal (est.)';
    }
    return '$low–$high kcal (est.)';
  }
}

/// Offline pure Dart inference engine for the Calorie ML Surrogate Model.
///
/// Evaluates pre-compiled LightGBM decision trees with monotonic constraints.
/// Enforces non-crossing quantile guarantees (P10 <= P50 <= P90) and performs
/// cryptographic SHA-256 integrity verification on model assets.
class CalorieModelEngine {
  static final CalorieModelEngine _instance = CalorieModelEngine._internal();
  factory CalorieModelEngine() => _instance;
  CalorieModelEngine._internal();

  /// Cryptographic SHA-256 hash expected for assets/models/calorie_trees.json
  static const String expectedTreesSha256 =
      '6ef0429cf529b8267a635631ffec9e3bab027423f1376519739eda47071037e4';

  static const String defaultTreesAssetPath =
      'assets/models/calorie_trees.json';
  static const String defaultMetaAssetPath = 'assets/models/calorie_meta.json';

  bool _isModelVerified = false;
  String _modelVersion = '1.0.0';
  String _modelSha256 = '';
  bool _hasLoggedFallbackWarning = false;

  Map<String, List<Map<String, dynamic>>> _treesByQuantile = {};

  bool get isModelVerified => _isModelVerified;
  String get modelVersion => _modelVersion;
  String get modelSha256 => _modelSha256;

  /// Loads and cryptographically validates the decision tree bundle from assets.
  Future<bool> loadProductionModel([
    String treesPath = defaultTreesAssetPath,
    String metaPath = defaultMetaAssetPath,
  ]) async {
    try {
      final metaJson = await rootBundle.loadString(metaPath);
      final treesJson = await rootBundle.loadString(treesPath);
      return loadModelFromStrings(treeJson: treesJson, metaJson: metaJson);
    } catch (e) {
      _isModelVerified = false;
      if (!_hasLoggedFallbackWarning) {
        _hasLoggedFallbackWarning = true;
        AppLogger.warning(
          'Calorie ML trees asset load failed ($e). Falling back to analytical equations.',
          tag: 'CalorieModelEngine',
        );
      }
      return false;
    }
  }

  /// In-memory loader with cryptographic SHA-256 validation.
  bool loadModelFromStrings({
    required String treeJson,
    required String metaJson,
  }) {
    try {
      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      final normalizedTreeJson = treeJson.replaceAll('\r\n', '\n');
      final actualSha = sha256
          .convert(utf8.encode(normalizedTreeJson))
          .toString();

      final expectedSha =
          (meta['sha256_trees'] as String?) ?? expectedTreesSha256;
      if (actualSha != expectedSha && actualSha != expectedTreesSha256) {
        _isModelVerified = false;
        AppLogger.warning(
          'Calorie ML tree SHA-256 mismatch (got $actualSha, expected $expectedSha). Asset corrupted.',
          tag: 'CalorieModelEngine',
        );
        return false;
      }

      final bundle = jsonDecode(treeJson) as Map<String, dynamic>;
      _modelVersion = (bundle['model_version'] as String?) ?? '1.0.0';
      _modelSha256 = actualSha;

      final models = bundle['models'] as Map<String, dynamic>;
      final loadedTrees = <String, List<Map<String, dynamic>>>{};

      for (final q in ['p10', 'p50', 'p90']) {
        if (models.containsKey(q)) {
          final rawList = models[q]['trees'] as List;
          loadedTrees[q] = rawList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      if (loadedTrees.containsKey('p50')) {
        _treesByQuantile = loadedTrees;
        _isModelVerified = true;
        AppLogger.info(
          'Calorie Surrogate ML model loaded & verified (v$_modelVersion, SHA: ${_modelSha256.substring(0, 8)}...)',
          tag: 'CalorieModelEngine',
        );
        return true;
      } else {
        _isModelVerified = false;
        return false;
      }
    } catch (e) {
      _isModelVerified = false;
      AppLogger.error(
        'Failed to parse Calorie ML trees: $e',
        tag: 'CalorieModelEngine',
      );
      return false;
    }
  }

  /// Evaluates an individual decision tree node against input feature vector.
  double _evaluateNode(Map<String, dynamic> node, List<double> features) {
    if (node.containsKey('leaf_value') && node['leaf_value'] != null) {
      return (node['leaf_value'] as num).toDouble();
    }
    final splitFeature = (node['split_feature'] as num).toInt();
    final threshold = (node['threshold'] as num).toDouble();
    final val = (splitFeature >= 0 && splitFeature < features.length)
        ? features[splitFeature]
        : 0.0;

    if (val <= threshold) {
      final left = node['left'] as Map<String, dynamic>?;
      return left != null ? _evaluateNode(left, features) : 0.0;
    } else {
      final right = node['right'] as Map<String, dynamic>?;
      return right != null ? _evaluateNode(right, features) : 0.0;
    }
  }

  /// Predicts energy expenditure burn rate (kcal/min) across quantiles.
  Map<String, double> predictRates({
    required double massKg,
    required double speedKmh,
    required double grade,
    required double cadenceSpm,
    required double climbRateMMin,
  }) {
    if (!_isModelVerified || _treesByQuantile.isEmpty) {
      // Fallback: Analytical ACSM rate
      final phys = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: (speedKmh / 60.0),
        durationSeconds: 60.0,
        speedKmh: speedKmh,
        grade: grade,
        profile: UserBodyProfile.referenceAdult(weightKg: massKg),
      );
      final rate = phys.burnRateKcalPerMin;
      return {'p10': rate * 0.85, 'p50': rate, 'p90': rate * 1.15};
    }

    final features = [massKg, speedKmh, grade, cadenceSpm, climbRateMMin];

    double p10 = 0.0;
    double p50 = 0.0;
    double p90 = 0.0;

    if (_treesByQuantile.containsKey('p10')) {
      for (final tree in _treesByQuantile['p10']!) {
        p10 += _evaluateNode(tree, features);
      }
    }
    if (_treesByQuantile.containsKey('p50')) {
      for (final tree in _treesByQuantile['p50']!) {
        p50 += _evaluateNode(tree, features);
      }
    }
    if (_treesByQuantile.containsKey('p90')) {
      for (final tree in _treesByQuantile['p90']!) {
        p90 += _evaluateNode(tree, features);
      }
    }

    // Monotonic quantile enforcement: P10 <= P50 <= P90
    p50 = math.max(p10, p50);
    p90 = math.max(p50, p90);

    return {'p10': p10, 'p50': p50, 'p90': p90};
  }

  /// Estimates energy expenditure for a run segment with uncertainty intervals
  /// and personal watch calibration.
  CalorieQuantileResult estimateSegment({
    required double distanceKm,
    required double durationSeconds,
    required double speedKmh,
    double grade = 0.0,
    double cadenceSpm = 0.0,
    String activityType = 'running',
    UserBodyProfile? profile,
    double? watchCalibrationFactor,
  }) {
    final massKg =
        profile?.weightKg ?? PhysiologicalCalorieEngine.defaultWeightKg;
    final clampedGrade = grade.clamp(-0.20, 0.20);
    final clampedCadence = cadenceSpm.clamp(0.0, 240.0);
    final climbRate = math.max(0.0, clampedGrade * (speedKmh * 1000.0 / 60.0));
    final durationMin = durationSeconds / 60.0;

    // Legacy baseline
    final legacyFlat = PhysiologicalCalorieEngine.computeLegacyFlatCalories(
      distanceKm: distanceKm,
      weightKg: massKg,
      activityType: activityType,
    );

    if (durationSeconds <= 0 && distanceKm <= 0) {
      return CalorieQuantileResult(
        p10Kcal: 0.0,
        p50Kcal: 0.0,
        p90Kcal: 0.0,
        burnRateKcalPerMin: 0.0,
        legacyFlatKcal: 0.0,
        isModelVerified: _isModelVerified,
      );
    }

    // Stationary / Paused case
    if (speedKmh < 0.2) {
      final rmrPerMin = PhysiologicalCalorieEngine.computeRMRKcalPerMin(
        profile: profile,
      );
      final rmrTotal = rmrPerMin * durationMin;
      return CalorieQuantileResult(
        p10Kcal: rmrTotal,
        p50Kcal: rmrTotal,
        p90Kcal: rmrTotal,
        burnRateKcalPerMin: rmrPerMin,
        legacyFlatKcal: legacyFlat,
        isModelVerified: _isModelVerified,
      );
    }

    // Active movement
    final rates = predictRates(
      massKg: massKg,
      speedKmh: speedKmh,
      grade: clampedGrade,
      cadenceSpm: clampedCadence,
      climbRateMMin: climbRate,
    );

    double p10 = rates['p10']! * durationMin;
    double p50 = rates['p50']! * durationMin;
    double p90 = rates['p90']! * durationMin;

    // Apply personal watch calibration if present (clamped strictly to [0.8, 1.2])
    if (watchCalibrationFactor != null && watchCalibrationFactor > 0) {
      final factor = watchCalibrationFactor.clamp(0.8, 1.2);
      p10 *= factor;
      p50 *= factor;
      p90 *= factor;
    }

    return CalorieQuantileResult(
      p10Kcal: p10,
      p50Kcal: p50,
      p90Kcal: p90,
      burnRateKcalPerMin: rates['p50']!,
      legacyFlatKcal: legacyFlat,
      isModelVerified: _isModelVerified,
    );
  }

  /// Injects test mock models or resets verification for test isolation.
  void resetForTesting({bool isVerified = false}) {
    _isModelVerified = isVerified;
    _treesByQuantile = {};
    _hasLoggedFallbackWarning = false;
  }
}
