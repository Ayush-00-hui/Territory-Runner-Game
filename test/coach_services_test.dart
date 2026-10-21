import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/features/coach/pace_prediction_service.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/api_client.dart';

void main() {
  group('PacePredictionService Tests', () {
    final paceService = PacePredictionService();

    test(
      'Beginner profile gets appropriate initial target distance and pace',
      () {
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
      },
    );

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
    test(
      'generateRunInsight provides rich fallback when API key is unconfigured',
      () async {
        final offlineClient = ApiClient(
          httpClient: MockClient(
            (_) async => throw const SocketException('No route to host'),
          ),
          baseUrl: 'http://offline-backend',
        );
        final coachService = LLMCoachService(apiClient: offlineClient);
        final profile = RunnerProfile(
          id: 'p1',
          username: 'RunnerX',
          level: 2,
          totalHexesClaimed: 5,
        );
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
      },
    );

    test('generateRunInsight parses coach insight when backend returns proxy response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/coach'));
        return http.Response(
          jsonEncode({
            'summary': 'Phenomenal run through downtown!',
            'tip': 'Maintain high cadence on your next loop.',
            'mood_tag': 'celebratory',
          }),
          200,
        );
      });
      final coachService = LLMCoachService(
        apiClient: ApiClient(
          httpClient: mockClient,
          baseUrl: 'http://mock-backend',
        ),
      );
      final profile = RunnerProfile(
        id: 'p1',
        username: 'RunnerX',
        level: 2,
        totalHexesClaimed: 5,
      );
      final insight = await coachService.generateRunInsight(
        distanceKm: 4.0,
        durationSeconds: 1200,
        hexesClaimed: 6,
        profile: profile,
      );

      expect(insight.summary, equals('Phenomenal run through downtown!'));
      expect(insight.tip, equals('Maintain high cadence on your next loop.'));
      expect(insight.moodTag, equals(CoachMood.celebratory));
    });
  });
}
