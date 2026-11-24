import 'package:flutter/foundation.dart';

import '../core/logging/app_logger.dart';
import '../models/lap_split.dart';

/// Service managing automatic 1 km / 1 mile lap splits during active runs.
class AutoLapService {
  final double lapDistanceMeters;
  final ValueChanged<LapSplit>? onLapTriggered;

  final List<LapSplit> _splits = [];
  double _lastLapDistanceMeters = 0.0;
  int _lastLapTimeSeconds = 0;
  double _lastLapElevationMeters = 0.0;

  AutoLapService({this.lapDistanceMeters = 1000.0, this.onLapTriggered});

  List<LapSplit> get completedLaps => List.unmodifiable(_splits);

  /// Resets the auto-lap accumulator for a fresh run session.
  void reset() {
    _splits.clear();
    _lastLapDistanceMeters = 0.0;
    _lastLapTimeSeconds = 0;
    _lastLapElevationMeters = 0.0;
  }

  /// Processes live run telemetry update and checks for lap boundary crossing.
  LapSplit? processFix({
    required double totalDistanceMeters,
    required int movingDurationSeconds,
    double totalElevationGainMeters = 0.0,
  }) {
    if (lapDistanceMeters <= 0) return null;

    final distanceSinceLastLap = totalDistanceMeters - _lastLapDistanceMeters;
    if (distanceSinceLastLap >= lapDistanceMeters) {
      final lapNumber = _splits.length + 1;
      final lapDuration = movingDurationSeconds - _lastLapTimeSeconds;
      final lapElevation = totalElevationGainMeters - _lastLapElevationMeters;

      // Pace = seconds / km
      final paceSecPerKm = lapDuration > 0 && distanceSinceLastLap > 0
          ? (lapDuration / (distanceSinceLastLap / 1000.0))
          : 0.0;

      final split = LapSplit(
        lapNumber: lapNumber,
        distanceMeters: distanceSinceLastLap,
        durationSeconds: lapDuration,
        paceSecondsPerKm: paceSecPerKm,
        elevationGainMeters: lapElevation,
      );

      _splits.add(split);
      _lastLapDistanceMeters = totalDistanceMeters;
      _lastLapTimeSeconds = movingDurationSeconds;
      _lastLapElevationMeters = totalElevationGainMeters;

      AppLogger.info(
        'Auto-Lap #$lapNumber completed: ${split.formattedDuration} (${split.formattedPace} /km)',
        tag: 'AutoLapService',
      );

      onLapTriggered?.call(split);
      return split;
    }

    return null;
  }
}
