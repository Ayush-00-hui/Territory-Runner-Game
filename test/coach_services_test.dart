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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PacePredictionService Tests', () {
    final paceService = PacePredictionService();

    test('Beginner profile gets appropriate initial target distance and pace (cold-start)', () {
      final beginner = RunnerProfile(
        id: 'p1',
        username: 'Newbie',
        totalDistanceKm: 0.0,
        level: 1,
        totalTerritoriesClaimed: 0,
      );

      final pred = paceService.predictTarget(beginner);
      expect(pred.predictedDistanceKm, equals(2.5));
      expect(pred.fitnessTier, equals('Beginner Strider'));
      expect(pred.paceFormatted, contains("/km"));
      expect(pred.isColdStart, isTrue);
      expect(pred.sourceLabel, contains('Default baseline'));
      expect(
        pred.distanceInterval.p10,
        lessThanOrEqualTo(pred.distanceInterval.p50),
      );
      expect(
        pred.distanceInterval.p50,
        lessThanOrEqualTo(pred.distanceInterval.p90),
      );
    });

    test('Higher level profile scales up target distance and pace', () {
      final veteran = RunnerProfile(
        id: 'p2',
        username: 'FastGuy',
        totalDistanceKm: 50.0,
        level: 8,
        totalTerritoriesClaimed: 80,
      );

      final pred = paceService.predictTarget(veteran);
      expect(pred.predictedDistanceKm, greaterThan(5.0));
      expect(pred.fitnessTier, equals('Intermediate Pacer'));
      expect(pred.stretchDistanceKm, greaterThan(pred.targetDistanceKm));
      expect(pred.conservativeDistanceKm, lessThan(pred.targetDistanceKm));
    });

    test('Cryptographic SHA256 and model version integrity check', () {
      final treesFile = File('assets/models/pace_distance_trees.json');
      final metaFile = File('assets/models/pace_distance_meta.json');
      expect(treesFile.existsSync(), isTrue);
      expect(metaFile.existsSync(), isTrue);

      final treeStr = treesFile.readAsStringSync();
      final metaStr = metaFile.readAsStringSync();

      // Valid load
      final loaded = paceService.loadModelFromStrings(
        treeJson: treeStr,
        metaJson: metaStr,
      );
      expect(loaded, isTrue);
      expect(paceService.isModelVerified, isTrue);
      expect(paceService.modelVersion, equals('1.0.0'));
      expect(paceService.modelSha256.isNotEmpty, isTrue);

      // Tampered payload check
      final tamperedTreeStr = treeStr.replaceFirst(
        'split_feature',
        'corrupted_key',
      );
      final tamperedLoaded = paceService.loadModelFromStrings(
        treeJson: tamperedTreeStr,
        metaJson: metaStr,
      );
      expect(tamperedLoaded, isFalse);
      expect(paceService.isModelVerified, isFalse);

      // Restore valid model
      paceService.loadModelFromStrings(treeJson: treeStr, metaJson: metaStr);
      expect(paceService.isModelVerified, isTrue);
    });

    test('Synthetic test user with >= 5 runs evaluates Quantile Regressor', () {
      // Synthetic user created strictly for unit testing
      final profile = RunnerProfile(
        id: 'synth_runner_42',
        username: 'SyntheticRunner',
        level: 4,
        totalDistanceKm: 32.0,
        totalTerritoriesClaimed: 15,
        currentStreak: 3,
      );

      final now = DateTime.now();
      // Generate 6 sequential past runs (N >= 5)
      final syntheticRuns = List.generate(6, (i) {
        return PastRun(
          distanceKm: 4.5 + (i * 0.3), // 4.5km to 6.0km
          paceMinKm: 5.4 - (i * 0.05), // ~5.4 min/km down to 5.15 min/km
          elevationGainM: 35.0 + (i * 5.0),
          timestamp: now.subtract(Duration(days: 6 - i, hours: 2)),
        );
      });

      final pred = paceService.predictTarget(
        profile,
        recentRuns: syntheticRuns,
        upcomingRunTime: now,
      );

      // Must be personalized (not cold start)
      expect(pred.isColdStart, isFalse);
      expect(pred.sourceLabel, contains('AI Adaptive'));

      // Non-crossing quantile interval verification
      expect(
        pred.distanceInterval.p10,
        lessThanOrEqualTo(pred.targetDistanceKm),
      );
      expect(pred.targetDistanceKm, lessThanOrEqualTo(pred.stretchDistanceKm));
      expect(pred.distanceInterval.width, greaterThan(0.0));

      expect(pred.paceInterval.p10, lessThanOrEqualTo(pred.targetPaceMinKm));
      expect(pred.targetPaceMinKm, lessThanOrEqualTo(pred.paceInterval.p90));
      expect(pred.paceInterval.width, greaterThan(0.0));

      // Adaptive daily goals alignment: target = p50, stretch = p90
      expect(pred.targetDistanceKm, equals(pred.distanceInterval.p50));
      expect(pred.stretchDistanceKm, equals(pred.distanceInterval.p90));
      expect(pred.conservativeDistanceKm, equals(pred.distanceInterval.p10));

      expect(pred.targetDistanceKm, greaterThan(1.0));
      expect(pred.stretchDistanceKm, greaterThan(pred.targetDistanceKm));
    });

    test('Cold-start boundary: 4 runs falls back to level defaults, 5 runs activates AI', () {
      final profile = RunnerProfile(
        id: 'synth_boundary',
        username: 'BoundaryRunner',
        level: 2,
        totalDistanceKm: 12.0,
      );

      final now = DateTime.now();
      final runs4 = List.generate(
        4,
        (i) => PastRun(
          distanceKm: 3.0,
          paceMinKm: 6.0,
          timestamp: now.subtract(Duration(days: 4 - i)),
        ),
      );

      final pred4 = paceService.predictTarget(profile, recentRuns: runs4);
      expect(pred4.isColdStart, isTrue);
      expect(pred4.sourceLabel, contains('Default baseline'));

      final runs5 = List.generate(
        5,
        (i) => PastRun(
          distanceKm: 3.5,
          paceMinKm: 5.8,
          timestamp: now.subtract(Duration(days: 5 - i)),
        ),
      );

      final pred5 = paceService.predictTarget(profile, recentRuns: runs5);
      expect(pred5.isColdStart, isFalse);
      expect(pred5.sourceLabel, contains('AI Adaptive'));
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

    test('Coach and RunnerProfile rename hexes to territories/zones with full compatibility', () async {
      final profile = RunnerProfile(
        id: 'p_tz',
        username: 'TerritoryRunner',
        level: 3,
        totalTerritoriesClaimed: 10,
      );
      // Property and alias parity
      expect(profile.totalTerritoriesClaimed, equals(10));
      expect(profile.totalHexesClaimed, equals(10));

      profile.claimTerritory();
      expect(profile.totalTerritoriesClaimed, equals(11));
      expect(profile.totalHexesClaimed, equals(11));

      // JSON serialization maintains both fields
      final jsonMap = profile.toJson();
      expect(jsonMap['totalTerritoriesClaimed'], equals(11));
      expect(jsonMap['totalHexesClaimed'], equals(11));

      // Fallback coach text references territories/zones and multi-zone loops
      final fallback = CoachInsight.fallback(
        distanceKm: 5.0,
        territoriesClaimed: 7,
        durationSeconds: 1500,
      );
      expect(fallback.summary, contains('claimed 7 new territories/zones'));
      expect(fallback.tip, contains('multi-zone loops'));
      expect(fallback.moodTag, equals(CoachMood.celebratory));
    });
  });
}
