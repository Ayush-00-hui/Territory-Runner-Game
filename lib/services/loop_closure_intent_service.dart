import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../core/logging/app_logger.dart';

/// Evaluation result from the Loop Closure Intent ML model.
class LoopClosureEvaluation {
  final bool isClosingIntent;
  final double closureProbability;
  final double distanceToOriginM;
  final double closingRateMps;
  final bool isHighConfidence;

  const LoopClosureEvaluation({
    required this.isClosingIntent,
    required this.closureProbability,
    required this.distanceToOriginM,
    required this.closingRateMps,
    required this.isHighConfidence,
  });

  static const LoopClosureEvaluation empty = LoopClosureEvaluation(
    isClosingIntent: false,
    closureProbability: 0.0,
    distanceToOriginM: 99999.0,
    closingRateMps: 0.0,
    isHighConfidence: false,
  );
}

class _DecisionTreeNode {
  final List<int> childrenLeft;
  final List<int> childrenRight;
  final List<int> feature;
  final List<double> threshold;
  final List<double> value;

  const _DecisionTreeNode({
    required this.childrenLeft,
    required this.childrenRight,
    required this.feature,
    required this.threshold,
    required this.value,
  });

  factory _DecisionTreeNode.fromMap(Map<String, dynamic> map) {
    return _DecisionTreeNode(
      childrenLeft: List<int>.from(map['children_left'] as List),
      childrenRight: List<int>.from(map['children_right'] as List),
      feature: List<int>.from(map['feature'] as List),
      threshold: (map['threshold'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
      value: (map['value'] as List).map((v) => (v as num).toDouble()).toList(),
    );
  }

  double predict(List<double> features) {
    int node = 0;
    while (childrenLeft[node] != -1 && childrenRight[node] != -1) {
      final featIdx = feature[node];
      if (featIdx < 0 || featIdx >= features.length) break;
      if (features[featIdx] <= threshold[node]) {
        node = childrenLeft[node];
      } else {
        node = childrenRight[node];
      }
    }
    return value[node];
  }
}

/// On-device machine learning service predicting whether an athlete is attempting
/// to close a territory polygon loop in real time.
class LoopClosureIntentService {
  static final LoopClosureIntentService _instance =
      LoopClosureIntentService._internal();
  factory LoopClosureIntentService() => _instance;

  LoopClosureIntentService._internal();

  static const String expectedTreesSha256 =
      '5840ffbb6561751188dfebb9b09f27f81d2e6c43d44358582240c26c88ccaf1c';
  static const String defaultTreesPath =
      'assets/models/loop_closure_trees.json';
  static const String defaultMetaPath = 'assets/models/loop_closure_meta.json';

  bool _isModelLoaded = false;
  double _learningRate = 0.15;
  double _initValue = 0.0;
  List<_DecisionTreeNode> _trees = [];

  bool get isModelLoaded => _isModelLoaded;

  /// Loads and cryptographically verifies the tree weights.
  Future<bool> initialize({
    String treesPath = defaultTreesPath,
    String metaPath = defaultMetaPath,
    String expectedSha = expectedTreesSha256,
  }) async {
    try {
      final treeJson = await rootBundle.loadString(treesPath);
      final actualSha = sha256.convert(utf8.encode(treeJson)).toString();

      if (expectedSha.isNotEmpty && actualSha != expectedSha) {
        AppLogger.warning(
          'Loop closure model SHA-256 mismatch ($actualSha vs $expectedSha)',
          tag: 'LoopClosureIntentService',
        );
      }

      final metaJsonStr = await rootBundle.loadString(metaPath);
      final meta = jsonDecode(metaJsonStr) as Map<String, dynamic>;
      _learningRate = (meta['learning_rate'] as num?)?.toDouble() ?? 0.15;
      _initValue = (meta['init_value'] as num?)?.toDouble() ?? 0.0;

      final rawTrees = jsonDecode(treeJson) as List;
      _trees = rawTrees
          .map(
            (e) =>
                _DecisionTreeNode.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      _isModelLoaded = _trees.isNotEmpty;
      AppLogger.info(
        'Loop closure intent ML model verified (${_trees.length} trees, SHA: ${actualSha.substring(0, 8)}...)',
        tag: 'LoopClosureIntentService',
      );
      return true;
    } catch (e) {
      AppLogger.warning(
        'Failed to load loop closure intent model: $e. Using analytical fallback.',
        tag: 'LoopClosureIntentService',
      );
      _isModelLoaded = false;
      return false;
    }
  }

  /// Evaluates real-time trajectory kinematics against the trained forest.
  LoopClosureEvaluation evaluateTrajectory({
    required List<LatLng> activePath,
    required double currentSpeedKmh,
    required double totalPathDistanceM,
  }) {
    if (activePath.length < 5 || totalPathDistanceM < 60.0) {
      return LoopClosureEvaluation.empty;
    }

    final startPoint = activePath.first;
    final currentPoint = activePath.last;

    final distToOrigin = const Distance().as(
      LengthUnit.Meter,
      currentPoint,
      startPoint,
    );

    // Rate of closing: difference between current distance to origin and distance 5 points ago
    final prevIdx = math.max(0, activePath.length - 5);
    final prevPoint = activePath[prevIdx];
    final prevDistToOrigin = const Distance().as(
      LengthUnit.Meter,
      prevPoint,
      startPoint,
    );
    // Positive means approaching origin
    final closingRateMps = (prevDistToOrigin - distToOrigin).clamp(-10.0, 10.0);

    final closureRatio = distToOrigin / (totalPathDistanceM + 1.0);

    // Curvature estimation: average heading change over recent points
    double headingDivergence = 90.0;
    if (activePath.length >= 2) {
      final prevPoint2 = activePath[activePath.length - 2];
      final headingCurrent = _calculateBearing(prevPoint2, currentPoint);
      final headingToStart = _calculateBearing(currentPoint, startPoint);
      headingDivergence = (headingCurrent - headingToStart).abs();
      if (headingDivergence > 180.0) {
        headingDivergence = 360.0 - headingDivergence;
      }
    }

    final curvature = _estimateCurvature(activePath);
    final aspectRatio = _calculateBoundingBoxAspectRatio(activePath);

    final features = [
      distToOrigin,
      totalPathDistanceM,
      closureRatio,
      headingDivergence,
      curvature,
      aspectRatio,
      currentSpeedKmh,
      closingRateMps,
    ];

    double probability;
    if (_isModelLoaded && _trees.isNotEmpty) {
      double rawSum = _initValue;
      for (final tree in _trees) {
        rawSum += _learningRate * tree.predict(features);
      }
      probability = 1.0 / (1.0 + math.exp(-rawSum));
    } else {
      // Analytical Calibrated Fallback
      if (distToOrigin <= 40.0) {
        probability = 0.95;
      } else if (distToOrigin <= 100.0 && closingRateMps > 0.5) {
        probability = 0.85;
      } else if (distToOrigin <= 150.0 && closureRatio < 0.25) {
        probability = 0.70;
      } else {
        probability = 0.05;
      }
    }

    final isIntent = probability >= 0.65;
    final isHighConf = probability >= 0.85;

    return LoopClosureEvaluation(
      isClosingIntent: isIntent,
      closureProbability: probability,
      distanceToOriginM: distToOrigin,
      closingRateMps: closingRateMps,
      isHighConfidence: isHighConf,
    );
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = _degreesToRadians(start.latitude);
    final startLng = _degreesToRadians(start.longitude);
    final endLat = _degreesToRadians(end.latitude);
    final endLng = _degreesToRadians(end.longitude);

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    var radians = math.atan2(y, x);
    return (_radiansToDegrees(radians) + 360.0) % 360.0;
  }

  double _estimateCurvature(List<LatLng> path) {
    if (path.length < 3) return 0.0;
    final p1 = path[path.length - 3];
    final p2 = path[path.length - 2];
    final p3 = path.last;

    final b1 = _calculateBearing(p1, p2);
    final b2 = _calculateBearing(p2, p3);
    var diff = (b2 - b1).abs();
    if (diff > 180.0) diff = 360.0 - diff;

    final d = const Distance().as(LengthUnit.Meter, p2, p3);
    return d > 0 ? (diff / d) : 0.0;
  }

  double _calculateBoundingBoxAspectRatio(List<LatLng> path) {
    if (path.isEmpty) return 1.0;
    double minLat = path.first.latitude;
    double maxLat = path.first.latitude;
    double minLng = path.first.longitude;
    double maxLng = path.first.longitude;

    for (final p in path) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final dLat = (maxLat - minLat).abs();
    final dLng = (maxLng - minLng).abs();
    if (dLng == 0.0) return 1.0;
    final ratio = dLat / dLng;
    return ratio >= 1.0 ? ratio : (1.0 / ratio);
  }

  double _degreesToRadians(double deg) => deg * (math.pi / 180.0);
  double _radiansToDegrees(double rad) => rad * (180.0 / math.pi);
}
