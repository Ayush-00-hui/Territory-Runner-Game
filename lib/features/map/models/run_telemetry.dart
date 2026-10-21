import '../../../models/run_goal.dart';

/// Immutable snapshot of live run telemetry for targeted UI repainting.
class RunTelemetry {
  final double distanceKm;
  final int elapsedSeconds;
  final int movingSeconds;
  final String splitPace;
  final double currentSpeedKmh;
  final double satelliteAccuracyMeters;
  final int territoriesClaimed;
  final double? distanceToClosureMeters;
  final double? proximityToClosure;
  final double currentAreaSqm;
  final bool isRunActive;
  final bool isAutoPaused;
  final RunGoal? activeGoal;

  const RunTelemetry({
    this.distanceKm = 0.0,
    this.elapsedSeconds = 0,
    this.movingSeconds = 0,
    this.splitPace = '--:--',
    this.currentSpeedKmh = 0.0,
    this.satelliteAccuracyMeters = 0.0,
    this.territoriesClaimed = 0,
    this.distanceToClosureMeters,
    this.proximityToClosure,
    this.currentAreaSqm = 0.0,
    this.isRunActive = false,
    this.isAutoPaused = false,
    this.activeGoal,
  });

  RunTelemetry copyWith({
    double? distanceKm,
    int? elapsedSeconds,
    int? movingSeconds,
    String? splitPace,
    double? currentSpeedKmh,
    double? satelliteAccuracyMeters,
    int? territoriesClaimed,
    double? distanceToClosureMeters,
    double? proximityToClosure,
    double? currentAreaSqm,
    bool? isRunActive,
    bool? isAutoPaused,
    RunGoal? activeGoal,
    bool clearClosure = false,
  }) {
    return RunTelemetry(
      distanceKm: distanceKm ?? this.distanceKm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      splitPace: splitPace ?? this.splitPace,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      satelliteAccuracyMeters:
          satelliteAccuracyMeters ?? this.satelliteAccuracyMeters,
      territoriesClaimed: territoriesClaimed ?? this.territoriesClaimed,
      distanceToClosureMeters: clearClosure
          ? null
          : (distanceToClosureMeters ?? this.distanceToClosureMeters),
      proximityToClosure: clearClosure
          ? null
          : (proximityToClosure ?? this.proximityToClosure),
      currentAreaSqm: currentAreaSqm ?? this.currentAreaSqm,
      isRunActive: isRunActive ?? this.isRunActive,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      activeGoal: activeGoal ?? this.activeGoal,
    );
  }
}
