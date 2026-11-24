import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/weekly_recap.dart';

void main() {
  group('WeeklyRecap Model Tests', () {
    test('WeeklyRecap computes percentage deltas correctly', () {
      final recap = WeeklyRecap(
        weekStart: DateTime(2026, 1, 5),
        weekEnd: DateTime(2026, 1, 11),
        totalDistanceKm: 25.0,
        prevDistanceKm: 20.0, // +25%
        totalRuns: 3,
        prevRuns: 2,
        areaGainedSqm: 20000.0,
        prevAreaGainedSqm: 10000.0, // +100%
        bestPaceSecondsPerKm: 280,
        currentStreakDays: 5,
        averageTerritoryStrength: 85.0,
      );

      expect(recap.distanceDeltaPercent, closeTo(25.0, 0.01));
      expect(recap.areaDeltaPercent, closeTo(100.0, 0.01));
      expect(recap.formattedBestPace, '4:40 /km');
    });

    test('WeeklyRecap handles zero previous week gracefully', () {
      final recap = WeeklyRecap(
        weekStart: DateTime(2026, 1, 5),
        weekEnd: DateTime(2026, 1, 11),
        totalDistanceKm: 10.0,
        prevDistanceKm: 0.0,
        totalRuns: 1,
        prevRuns: 0,
        areaGainedSqm: 5000.0,
        prevAreaGainedSqm: 0.0,
        currentStreakDays: 1,
        averageTerritoryStrength: 90.0,
      );

      expect(recap.distanceDeltaPercent, 100.0);
      expect(recap.areaDeltaPercent, 100.0);
    });
  });
}
