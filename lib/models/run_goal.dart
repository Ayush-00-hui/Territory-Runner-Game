enum GoalType {
  none,
  distance, // Target in kilometers
  duration, // Target in seconds
  area, // Target in square meters
}

/// Represents an athletic run goal (distance, time, or territory area)
/// with live progress and completion calculations.
class RunGoal {
  final GoalType type;
  final double targetValue;

  const RunGoal({required this.type, required this.targetValue});

  static const RunGoal none = RunGoal(type: GoalType.none, targetValue: 0);

  bool get isActive => type != GoalType.none && targetValue > 0;

  String get title {
    switch (type) {
      case GoalType.distance:
        return '${targetValue.toStringAsFixed(targetValue.truncateToDouble() == targetValue ? 0 : 1)} KM TARGET';
      case GoalType.duration:
        final int minutes = (targetValue / 60).round();
        return '$minutes MIN TIME TARGET';
      case GoalType.area:
        if (targetValue >= 1000000) {
          return '${(targetValue / 1000000).toStringAsFixed(1)} KM² DOMAIN';
        }
        return '${(targetValue / 1000).toStringAsFixed(0)}K M² TURF GOAL';
      case GoalType.none:
        return 'OPEN EXPLORATION';
    }
  }

  /// Calculates completion progress from 0.0 to 1.0+
  double computeProgress({
    required double currentDistanceKm,
    required int currentDurationSeconds,
    required double currentAreaSqm,
  }) {
    if (!isActive) return 0.0;
    switch (type) {
      case GoalType.distance:
        return (currentDistanceKm / targetValue).clamp(0.0, 2.0);
      case GoalType.duration:
        return (currentDurationSeconds / targetValue).clamp(0.0, 2.0);
      case GoalType.area:
        return (currentAreaSqm / targetValue).clamp(0.0, 2.0);
      case GoalType.none:
        return 0.0;
    }
  }

  /// Formats human-readable remaining metric
  String formatRemaining({
    required double currentDistanceKm,
    required int currentDurationSeconds,
    required double currentAreaSqm,
  }) {
    if (!isActive) return '';
    switch (type) {
      case GoalType.distance:
        final double rem = (targetValue - currentDistanceKm).clamp(
          0.0,
          targetValue,
        );
        if (rem <= 0) return 'Goal achieved!';
        return '${rem.toStringAsFixed(2)} km remaining';
      case GoalType.duration:
        final int remSec = (targetValue.round() - currentDurationSeconds).clamp(
          0,
          targetValue.round(),
        );
        if (remSec <= 0) return 'Goal achieved!';
        final int m = remSec ~/ 60;
        final int s = remSec % 60;
        return "${m}m ${s.toString().padLeft(2, '0')}s remaining";
      case GoalType.area:
        final double rem = (targetValue - currentAreaSqm).clamp(
          0.0,
          targetValue,
        );
        if (rem <= 0) return 'Goal achieved!';
        if (rem >= 1000000) {
          return '${(rem / 1000000).toStringAsFixed(2)} km² to claim';
        }
        return '${rem.toStringAsFixed(0)} m² to claim';
      case GoalType.none:
        return '';
    }
  }
}
