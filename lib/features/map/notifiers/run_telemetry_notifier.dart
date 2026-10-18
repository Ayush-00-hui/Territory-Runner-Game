import 'package:flutter/foundation.dart';
import '../models/run_telemetry.dart';
import '../../../models/run_goal.dart';

/// Micro-targeted state notifier for runner telemetry metrics.
/// Isolates high-frequency (1Hz) stopwatch and GPS telemetry updates
/// to specific listener widgets (HUD & AMOLED saver) without triggering
/// full MapScreenFeature rebuilds.
class RunTelemetryNotifier extends ValueNotifier<RunTelemetry> {
  RunTelemetryNotifier([super.initial = const RunTelemetry()]);

  void tick({required bool isAutoPaused}) {
    value = value.copyWith(
      elapsedSeconds: value.elapsedSeconds + 1,
      movingSeconds: isAutoPaused ? value.movingSeconds : value.movingSeconds + 1,
      isAutoPaused: isAutoPaused,
    );
  }

  void updateGps({
    required double speedKmh,
    required double accuracyMeters,
    required double distanceKm,
    required String splitPace,
    double? distanceToClosure,
    double? proximityToClosure,
    double? currentAreaSqm,
  }) {
    value = value.copyWith(
      currentSpeedKmh: speedKmh,
      satelliteAccuracyMeters: accuracyMeters,
      distanceKm: distanceKm,
      splitPace: splitPace,
      distanceToClosureMeters: distanceToClosure,
      proximityToClosure: proximityToClosure,
      currentAreaSqm: currentAreaSqm,
      clearClosure: distanceToClosure == null,
    );
  }

  void setRunActive(bool active) {
    value = value.copyWith(isRunActive: active);
  }

  void setAutoPaused(bool paused) {
    value = value.copyWith(isAutoPaused: paused);
  }

  void setGoal(RunGoal? goal) {
    value = value.copyWith(activeGoal: goal);
  }

  void setTerritoriesClaimed(int count) {
    value = value.copyWith(territoriesClaimed: count);
  }

  void setArea(double area) {
    value = value.copyWith(currentAreaSqm: area);
  }

  void reset() {
    value = const RunTelemetry();
  }
}
