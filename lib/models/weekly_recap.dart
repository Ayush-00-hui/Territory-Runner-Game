/// Encapsulates consolidated weekly metrics and week-over-week deltas.
class WeeklyRecap {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double totalDistanceKm;
  final double prevDistanceKm;
  final int totalRuns;
  final int prevRuns;
  final double areaGainedSqm;
  final double prevAreaGainedSqm;
  final double? bestPaceSecondsPerKm;
  final int currentStreakDays;
  final double averageTerritoryStrength;

  const WeeklyRecap({
    required this.weekStart,
    required this.weekEnd,
    required this.totalDistanceKm,
    required this.prevDistanceKm,
    required this.totalRuns,
    required this.prevRuns,
    required this.areaGainedSqm,
    required this.prevAreaGainedSqm,
    this.bestPaceSecondsPerKm,
    required this.currentStreakDays,
    required this.averageTerritoryStrength,
  });

  /// Distance percentage change compared to previous week (e.g. +14.2% or -5.0%).
  double? get distanceDeltaPercent {
    if (prevDistanceKm <= 0.0) return totalDistanceKm > 0 ? 100.0 : 0.0;
    return ((totalDistanceKm - prevDistanceKm) / prevDistanceKm) * 100.0;
  }

  /// Area percentage change compared to previous week.
  double? get areaDeltaPercent {
    if (prevAreaGainedSqm <= 0.0) return areaGainedSqm > 0 ? 100.0 : 0.0;
    return ((areaGainedSqm - prevAreaGainedSqm) / prevAreaGainedSqm) * 100.0;
  }

  String get formattedBestPace {
    if (bestPaceSecondsPerKm == null || bestPaceSecondsPerKm! <= 0) {
      return '--:--';
    }
    final totalSec = bestPaceSecondsPerKm!.round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}
