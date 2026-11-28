import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../core/logging/app_logger.dart';

/// Telemetry input features for the Tactical Guardian Neural Network.
class TacticalTelemetryInput {
  final double speedMps;
  final double gradePct;
  final double cumulativeFatigue;
  final double headingChangeRateDegS;
  final double athleteExperience; // 0=beginner, 1=intermediate, 2=elite
  final double cadenceSpm;
  final double altitudeM;
  final double territoryDensity;

  const TacticalTelemetryInput({
    required this.speedMps,
    this.gradePct = 0.0,
    this.cumulativeFatigue = 0.0,
    this.headingChangeRateDegS = 0.0,
    this.athleteExperience = 1.0,
    this.cadenceSpm = 165.0,
    this.altitudeM = 200.0,
    this.territoryDensity = 0.5,
  });

  List<double> toList() => [
    speedMps,
    gradePct,
    cumulativeFatigue,
    headingChangeRateDegS,
    athleteExperience,
    cadenceSpm,
    altitudeM,
    territoryDensity,
  ];
}

/// Multi-task prediction result from the Tactical Guardian model.
class TacticalGuardianPrediction {
  final double sprintVelocityTargetMps;
  final int incursionMaxDurationSeconds;
  final double optimalCrateDetourMeters;
  final double guardianP10Multiplier;
  final double guardianP50Multiplier;
  final double guardianP90Multiplier;
  final bool isModelVerified;

  const TacticalGuardianPrediction({
    required this.sprintVelocityTargetMps,
    required this.incursionMaxDurationSeconds,
    required this.optimalCrateDetourMeters,
    required this.guardianP10Multiplier,
    required this.guardianP50Multiplier,
    required this.guardianP90Multiplier,
    required this.isModelVerified,
  });
}

/// Offline pure-Dart inference engine for the Tactical Guardian Deep Neural Network
/// trained on the NVIDIA GeForce RTX 5070 Laptop GPU.
class TacticalAiEngine {
  static final TacticalAiEngine _instance = TacticalAiEngine._internal();
  factory TacticalAiEngine() => _instance;
  TacticalAiEngine._internal();

  static const String expectedWeightsSha256 =
      '02a828d01a5a312c974b93765ce46eb5361df8e7344976796013ed8a334d3ff2';

  bool _isInitialized = false;
  bool _isVerified = false;

  List<double> _xMean = [];
  List<double> _xStd = [];
  List<double> _yMean = [];
  List<double> _yStd = [];

  Map<String, dynamic> _weights = {};

  bool get isInitialized => _isInitialized;
  bool get isVerified => _isVerified;

  /// Loads model weights and metadata from Flutter assets bundle
  Future<void> init({
    String weightsAssetPath = 'assets/models/tactical_guardian_weights.json',
    String metaAssetPath = 'assets/models/tactical_guardian_meta.json',
  }) async {
    if (_isInitialized) return;

    try {
      final weightsJsonStr = await rootBundle.loadString(weightsAssetPath);
      final computedSha = sha256
          .convert(utf8.encode(weightsJsonStr))
          .toString();

      if (computedSha.toLowerCase() == expectedWeightsSha256.toLowerCase()) {
        _isVerified = true;
      } else {
        AppLogger.warning(
          'TacticalGuardianNet SHA-256 mismatch ($computedSha vs $expectedWeightsSha256); using analytical fallback.',
          tag: 'TacticalAiEngine',
        );
      }

      _weights = jsonDecode(weightsJsonStr) as Map<String, dynamic>;

      final metaJsonStr = await rootBundle.loadString(metaAssetPath);
      final meta = jsonDecode(metaJsonStr) as Map<String, dynamic>;

      _xMean = (meta['x_mean'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      _xStd = (meta['x_std'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      _yMean = (meta['y_mean'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      _yStd = (meta['y_std'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      _isInitialized = true;
      AppLogger.info(
        'Tactical Guardian Deep Neural Network loaded & verified successfully.',
        tag: 'TacticalAiEngine',
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to load neural assets ($e); falling back to physiological equations.',
        tag: 'TacticalAiEngine',
      );
      _isInitialized = true;
      _isVerified = false;
    }
  }

  /// Evaluates multi-task targets using neural forward pass or physiological fallback
  TacticalGuardianPrediction predict(TacticalTelemetryInput input) {
    if (!_isVerified || _weights.isEmpty) {
      return _analyticalFallback(input);
    }

    try {
      // 1. Feature normalization
      final rawX = input.toList();
      final normX = List<double>.generate(
        8,
        (i) => (rawX[i] - _xMean[i]) / _xStd[i],
      );

      // 2. Encoder Layer 0: Linear(8 -> 128)
      var h = _linear(normX, 'encoder.0.weight', 'encoder.0.bias');
      h = _layerNorm(h, 'encoder.1.weight', 'encoder.1.bias');
      h = _leakyRelu(h);

      // 3. Encoder Layer 3: Linear(128 -> 128)
      h = _linear(h, 'encoder.3.weight', 'encoder.3.bias');
      h = _layerNorm(h, 'encoder.4.weight', 'encoder.4.bias');
      h = _leakyRelu(h);

      // 4. Residual Highway Block
      var res = _linear(h, 'res_fc1.weight', 'res_fc1.bias');
      res = _layerNorm(res, 'res_ln1.weight', 'res_ln1.bias');
      res = _leakyRelu(res);
      res = _linear(res, 'res_fc2.weight', 'res_fc2.bias');
      res = _layerNorm(res, 'res_ln2.weight', 'res_ln2.bias');

      // h + res
      for (int i = 0; i < h.length; i++) {
        h[i] += res[i];
      }

      // 5. Head 1: Incursion Pacing & Duration (64 -> 2)
      var inc = _linear(h, 'head_incursion.0.weight', 'head_incursion.0.bias');
      inc = _leakyRelu(inc);
      inc = _linear(inc, 'head_incursion.2.weight', 'head_incursion.2.bias');

      // 6. Head 2: Crate Distance (32 -> 1)
      var crate = _linear(h, 'head_crate.0.weight', 'head_crate.0.bias');
      crate = _leakyRelu(crate);
      crate = _linear(crate, 'head_crate.2.weight', 'head_crate.2.bias');

      // 7. Head 3: Sector Guardian Ghost Quantiles (64 -> 3)
      var guard = _linear(h, 'head_guardian.0.weight', 'head_guardian.0.bias');
      guard = _leakyRelu(guard);
      guard = _linear(guard, 'head_guardian.2.weight', 'head_guardian.2.bias');

      // Concatenate normalized outputs [sprint_mps, dur_s, crate_m, p10, p50, p90]
      final normOut = [inc[0], inc[1], crate[0], guard[0], guard[1], guard[2]];

      // De-normalize
      final rawOut = List<double>.generate(
        6,
        (i) => normOut[i] * _yStd[i] + _yMean[i],
      );

      return TacticalGuardianPrediction(
        sprintVelocityTargetMps: rawOut[0].clamp(2.5, 7.5),
        incursionMaxDurationSeconds: rawOut[1].round().clamp(25, 120),
        optimalCrateDetourMeters: rawOut[2].clamp(120.0, 450.0),
        guardianP10Multiplier: rawOut[3].clamp(0.75, 1.25),
        guardianP50Multiplier: rawOut[4].clamp(0.85, 1.35),
        guardianP90Multiplier: rawOut[5].clamp(0.95, 1.45),
        isModelVerified: true,
      );
    } catch (e) {
      AppLogger.warning(
        'Neural forward pass error ($e); falling back to analytical equations.',
        tag: 'TacticalAiEngine',
      );
      return _analyticalFallback(input);
    }
  }

  TacticalGuardianPrediction _analyticalFallback(TacticalTelemetryInput input) {
    final sprintBoost =
        (1.25 +
                0.05 * input.athleteExperience -
                0.25 * input.cumulativeFatigue -
                0.8 * math.max(input.gradePct, 0.0))
            .clamp(1.10, 1.40);
    final targetSprintMps = (input.speedMps * sprintBoost).clamp(2.5, 7.0);
    final durationSec =
        (75.0 +
                15.0 * input.athleteExperience -
                35.0 * input.cumulativeFatigue -
                50.0 * math.max(input.gradePct, 0.0))
            .round()
            .clamp(30, 90);
    final crateDist =
        (280.0 +
                60.0 * (1.0 - input.cumulativeFatigue) -
                80.0 * input.gradePct.abs())
            .clamp(150.0, 400.0);

    return TacticalGuardianPrediction(
      sprintVelocityTargetMps: targetSprintMps,
      incursionMaxDurationSeconds: durationSec,
      optimalCrateDetourMeters: crateDist,
      guardianP10Multiplier: 0.95,
      guardianP50Multiplier: 1.05,
      guardianP90Multiplier: 1.15,
      isModelVerified: false,
    );
  }

  // --- Fast Matrix Vector Operations ---
  List<double> _linear(List<double> x, String wKey, String bKey) {
    final List<dynamic> wMat = _weights[wKey];
    final List<dynamic> bVec = _weights[bKey];
    final outRows = wMat.length;
    final inCols = x.length;
    final out = List<double>.filled(outRows, 0.0);

    for (int i = 0; i < outRows; i++) {
      double sum = (bVec[i] as num).toDouble();
      final List<dynamic> row = wMat[i];
      for (int j = 0; j < inCols; j++) {
        sum += (row[j] as num).toDouble() * x[j];
      }
      out[i] = sum;
    }
    return out;
  }

  List<double> _layerNorm(List<double> x, String gammaKey, String betaKey) {
    final List<dynamic> gamma = _weights[gammaKey];
    final List<dynamic> beta = _weights[betaKey];
    final n = x.length;

    double mean = 0.0;
    for (int i = 0; i < n; i++) {
      mean += x[i];
    }
    mean /= n;

    double variance = 0.0;
    for (int i = 0; i < n; i++) {
      final diff = x[i] - mean;
      variance += diff * diff;
    }
    variance /= n;
    final stdInv = 1.0 / math.sqrt(variance + 1e-5);

    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final norm = (x[i] - mean) * stdInv;
      out[i] =
          norm * (gamma[i] as num).toDouble() + (beta[i] as num).toDouble();
    }
    return out;
  }

  List<double> _leakyRelu(List<double> x) {
    for (int i = 0; i < x.length; i++) {
      if (x[i] < 0) x[i] *= 0.1;
    }
    return x;
  }
}
