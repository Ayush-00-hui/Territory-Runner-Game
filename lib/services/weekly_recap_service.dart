import '../models/weekly_recap.dart';
import 'run_log_service.dart';
import '../features/gameplay/territory_service.dart';

/// Aggregates local run history and territory fortifications to produce
/// comprehensive week-over-week performance recaps every Sunday.
class WeeklyRecapService {
  final RunLogService _runLogService;
  final TerritoryService _territoryService;

  WeeklyRecapService({
    RunLogService? runLogService,
    TerritoryService? territoryService,
  }) : _runLogService = runLogService ?? RunLogService(),
       _territoryService = territoryService ?? TerritoryService();

  /// Computes the weekly recap for the current week ending on the reference date.
  Future<WeeklyRecap> computeRecap({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();

    // Monday of current week at 00:00:00 UTC
    final currentWeekMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final currentWeekSunday = currentWeekMonday.add(const Duration(days: 7));

    // Previous week Monday and Sunday
    final prevWeekMonday = currentWeekMonday.subtract(const Duration(days: 7));
    final prevWeekSunday = currentWeekMonday;

    final allRuns = _runLogService.getAllRuns();

    double currentDistKm = 0.0;
    int currentRunsCount = 0;
    double currentAreaSqm = 0.0;
    double? bestPace;

    double prevDistKm = 0.0;
    int prevRunsCount = 0;
    double prevAreaSqm = 0.0;

    for (final run in allRuns) {
      final started = run.startedAt;
      final distKm = run.distanceM / 1000.0;
      final area = run.claimedAreaSqM;

      if (started.isAfter(currentWeekMonday) &&
          started.isBefore(currentWeekSunday)) {
        currentDistKm += distKm;
        currentRunsCount++;
        currentAreaSqm += area;
        if (run.paceSecondsPerKm > 0) {
          if (bestPace == null || run.paceSecondsPerKm < bestPace) {
            bestPace = run.paceSecondsPerKm;
          }
        }
      } else if (started.isAfter(prevWeekMonday) &&
          started.isBefore(prevWeekSunday)) {
        prevDistKm += distKm;
        prevRunsCount++;
        prevAreaSqm += area;
      }
    }

    // Compute average territory strength
    final territories = _territoryService.getCapturedTerritoryObjects();
    double totalStrength = 0.0;
    for (final t in territories) {
      totalStrength += t.computeCurrentStrength(now: now);
    }
    final avgStrength = territories.isNotEmpty
        ? totalStrength / territories.length
        : 100.0;

    final profile = _territoryService.getProfile();

    return WeeklyRecap(
      weekStart: currentWeekMonday,
      weekEnd: currentWeekSunday,
      totalDistanceKm: currentDistKm,
      prevDistanceKm: prevDistKm,
      totalRuns: currentRunsCount,
      prevRuns: prevRunsCount,
      areaGainedSqm: currentAreaSqm,
      prevAreaGainedSqm: prevAreaSqm,
      bestPaceSecondsPerKm: bestPace,
      currentStreakDays: profile.currentStreak,
      averageTerritoryStrength: avgStrength,
    );
  }
}
