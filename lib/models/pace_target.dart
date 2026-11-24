/// Status of runner pace relative to target band.
enum PaceBandStatus { onPace, tooFast, tooSlow }

/// Target pace configuration and evaluation engine.
class PaceTarget {
  /// Target pace in seconds per kilometer (e.g. 330 = 5:30/km).
  final int targetSecondsPerKm;

  /// Tolerance band buffer in seconds (default ±15s).
  final int toleranceSeconds;

  const PaceTarget({
    required this.targetSecondsPerKm,
    this.toleranceSeconds = 15,
  });

  /// Evaluates current speed against the target pace band.
  PaceBandEvaluation evaluateSpeed(double currentSpeedKmh) {
    if (currentSpeedKmh <= 0.5) {
      return const PaceBandEvaluation(
        status: PaceBandStatus.onPace,
        currentPaceSecondsPerKm: 0,
        deltaSeconds: 0,
      );
    }

    final currentPaceSec = (3600.0 / currentSpeedKmh).round();
    final delta = currentPaceSec - targetSecondsPerKm;

    if (delta > toleranceSeconds) {
      return PaceBandEvaluation(
        status: PaceBandStatus.tooSlow,
        currentPaceSecondsPerKm: currentPaceSec,
        deltaSeconds: delta,
      );
    } else if (delta < -toleranceSeconds) {
      return PaceBandEvaluation(
        status: PaceBandStatus.tooFast,
        currentPaceSecondsPerKm: currentPaceSec,
        deltaSeconds: delta,
      );
    }

    return PaceBandEvaluation(
      status: PaceBandStatus.onPace,
      currentPaceSecondsPerKm: currentPaceSec,
      deltaSeconds: delta,
    );
  }

  String get formattedTarget {
    final m = targetSecondsPerKm ~/ 60;
    final s = targetSecondsPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}

class PaceBandEvaluation {
  final PaceBandStatus status;
  final int currentPaceSecondsPerKm;
  final int deltaSeconds;

  const PaceBandEvaluation({
    required this.status,
    required this.currentPaceSecondsPerKm,
    required this.deltaSeconds,
  });
}
