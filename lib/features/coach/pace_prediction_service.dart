import 'dart:math' as math;
import '../../models/runner_profile.dart';

class PaceDistancePrediction {
  final double predictedDistanceKm;
  final double predictedPaceMinKm;
  final String paceFormatted;
  final String fitnessTier;
  final double confidenceScore;

  const PaceDistancePrediction({
    required this.predictedDistanceKm,
    required this.predictedPaceMinKm,
    required this.paceFormatted,
    required this.fitnessTier,
    required this.confidenceScore,
  });
}

/// Pace and Distance Prediction Engine.
///
/// Predicts optimal achievable distance and pace target based on:
/// - User's historical total distance
/// - Runner level & streak momentum
/// - Standard physiological athletic decay curves
class PacePredictionService {
  static final PacePredictionService _instance = PacePredictionService._internal();
  factory PacePredictionService() => _instance;

  PacePredictionService._internal();

  /// Predicts achievable target run distance & target pace for today's session
  PaceDistancePrediction predictTarget(RunnerProfile profile) {
    // Baseline calculations
    // Base distance starts at 2.5km for Level 1, scaling gradually with level and logged distance
    final double levelFactor = (profile.level - 1) * 0.45;
    final double historyFactor = math.min(3.0, profile.totalDistanceKm * 0.05);
    final double streakBonus = math.min(1.0, math.max(0, profile.currentStreak - 1) * 0.08);

    double targetDist = 2.5 + levelFactor + historyFactor + streakBonus;
    targetDist = double.parse(targetDist.clamp(1.5, 15.0).toStringAsFixed(1));

    // Base pace in minutes per km: 6.8 min/km for beginners, lowering down to ~4.5 min/km for advanced
    double basePace = 6.8 - (profile.level * 0.15) - (profile.totalDistanceKm * 0.01);
    basePace = basePace.clamp(4.2, 7.5);

    final int minutes = basePace.floor();
    final int seconds = ((basePace - minutes) * 60).round();
    final String formattedPace = "$minutes'${seconds.toString().padLeft(2, '0')}\"/km";

    String tier = 'Beginner Strider';
    if (profile.level >= 10 || profile.totalDistanceKm >= 100) {
      tier = 'Elite Marathoner';
    } else if (profile.level >= 5 || profile.totalDistanceKm >= 30) {
      tier = 'Intermediate Pacer';
    } else if (profile.level >= 2) {
      tier = 'Developing Runner';
    }

    final double confidence = math.min(0.95, 0.60 + (profile.totalHexesClaimed * 0.01));

    return PaceDistancePrediction(
      predictedDistanceKm: targetDist,
      predictedPaceMinKm: basePace,
      paceFormatted: formattedPace,
      fitnessTier: tier,
      confidenceScore: confidence,
    );
  }
}
