import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/features/coach/pace_prediction_service.dart';
import 'package:territory_runner/models/runner_profile.dart';

void main() {
  group('PacePredictionService Tests', () {
    final paceService = PacePredictionService();

    test('Beginner profile gets appropriate initial target distance and pace', () {
      final beginner = RunnerProfile(
        id: 'p1',
        username: 'Newbie',
        totalDistanceKm: 0.0,
        level: 1,
        totalHexesClaimed: 0,
      );

      final pred = paceService.predictTarget(beginner);
      expect(pred.predictedDistanceKm, equals(2.5));
      expect(pred.fitnessTier, equals('Beginner Strider'));
      expect(pred.paceFormatted, contains("/km"));
    });

    test('Higher level profile scales up target distance and pace', () {
      final veteran = RunnerProfile(
        id: 'p2',
        username: 'FastGuy',
        totalDistanceKm: 50.0,
        level: 8,
        totalHexesClaimed: 80,
      );

      final pred = paceService.predictTarget(veteran);
      expect(pred.predictedDistanceKm, greaterThan(5.0));
      expect(pred.fitnessTier, equals('Intermediate Pacer'));
    });
  });

  group('LLMCoachService Fallback & Parsing Tests', () {
    final coachService = LLMCoachService();

    test('generateRunInsight provides rich fallback when API key is unconfigured', () async {
      final profile = RunnerProfile(id: 'p1', username: 'RunnerX', level: 2, totalHexesClaimed: 5);
      final insight = await coachService.generateRunInsight(
        distanceKm: 3.2,
        durationSeconds: 1200,
        hexesClaimed: 4,
        profile: profile,
      );

      expect(insight.summary, isNotEmpty);
      expect(insight.summary.contains('3.20 km'), isTrue);
      expect(insight.tip, isNotEmpty);
      expect(insight.moodTag, isNotNull);
    });
  });
}
