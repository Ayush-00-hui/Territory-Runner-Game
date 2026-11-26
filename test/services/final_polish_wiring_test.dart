import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/profile/widgets/faction_leaderboard.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/leaderboard_entry.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/run_log_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Final Polish & Wiring Verification', () {
    testWidgets('TerritoryBrandMark renders crisp custom paint across sizes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TerritoryBrandMark(size: 100),
                  TerritoryBrandMark(
                    size: 36,
                    showContainer: false,
                    loopProgress: 0.65,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TerritoryBrandMark), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    test('ApiClient.submitRun computes non-constant geodesic kinematics & sends step_count', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'run_id': 'r1', 'status': 'accepted'}),
          201,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mockbackend',
      );

      await apiClient.submitRun(
        idempotencyKey: 'k_kin_1',
        points: const [
          LatLng(51.5000, -0.1200),
          LatLng(51.5015, -0.1200), // Due North (~167m -> ~0 deg heading)
          LatLng(51.5015, -0.1180), // Due East (~138m -> ~90 deg heading)
        ],
        durationSeconds: 100,
        distanceMeters: 305.0,
        stepCount: 412,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['step_count'], 412);
      final pts = capturedBody!['points'] as List<dynamic>;
      expect(pts.length, 3);

      final p1 = pts[1] as Map<String, dynamic>;
      final p2 = pts[2] as Map<String, dynamic>;
      expect((p1['speed'] as num).toDouble(), greaterThan(1.5));
      expect((p1['heading'] as num).toDouble(), closeTo(0.0, 2.0));
      expect((p2['heading'] as num).toDouble(), closeTo(90.0, 2.0));
    });

    test('ApiClient.getTerritoriesInBBox parses strength, last_defended_at & cooldown_until', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final shieldIso = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 95))
          .toIso8601String();

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'id': 'poly_rival_1',
                'properties': {
                  'owner_id': 'rival_u1',
                  'area_sqm': 1420.0,
                  'strength': 64.5,
                  'last_defended_at': nowIso,
                  'cooldown_until': shieldIso,
                  'updated_at': nowIso,
                },
                'geometry': {
                  'type': 'MultiPolygon',
                  'coordinates': [
                    [
                      [
                        [-0.120, 51.500],
                        [-0.119, 51.500],
                        [-0.119, 51.501],
                        [-0.120, 51.500],
                      ],
                    ],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mockbackend',
      );

      final territories = await apiClient.getTerritoriesInBBox(
        minLng: -0.2,
        minLat: 51.4,
        maxLng: 0.0,
        maxLat: 51.6,
      );

      expect(territories.length, 1);
      final t = territories.first;
      expect(t.id, 'poly_rival_1');
      expect(t.strength, closeTo(64.5, 0.01));
      expect(t.cooldownUntil, isNotNull);
      expect(t.isShielded(), isTrue);
    });

    test('ApiClient.getRuns and removeFriend call correct endpoints', () async {
      final visited = <String>[];
      final mockClient = MockClient((request) async {
        visited.add('${request.method} ${request.url.path}');
        if (request.url.path == '/v1/runs') {
          return http.Response(
            jsonEncode({
              'runs': [
                {'id': 'srv_1', 'duration_seconds': 600},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 'removed'}), 200);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mockbackend',
      );

      final runs = await apiClient.getRuns(limit: 10);
      final removed = await apiClient.removeFriend('friend_42');

      expect(runs.length, 1);
      expect(runs.first['id'], 'srv_1');
      expect(removed, isTrue);
      expect(visited, ['GET /v1/runs', 'DELETE /v1/friends/friend_42']);
    });

    test('RunLogService.mergeServerRuns syncs pending local runs and imports new remote runs idempotently', () async {
      final tempDir = await Directory.systemTemp.createTemp('run_log_merge_');
      Hive.init(tempDir.path);
      final box = await Hive.openBox<String>('merge_test_box');
      final service = RunLogService.custom(overrideBox: box);

      await service.recordRun(
        id: 'local_key_1',
        startedAt: DateTime(2026, 11, 25, 7, 0),
        endedAt: DateTime(2026, 11, 25, 7, 20),
        movingSeconds: 1200,
        totalSeconds: 1200,
        distanceM: 3200.0,
        samples: const [
          RunSample(timeOffsetMs: 0, lat: 51.5, lng: -0.12),
          RunSample(timeOffsetMs: 1200000, lat: 51.51, lng: -0.11),
        ],
        syncStatus: 'pending',
      );

      final mergedCount = await service.mergeServerRuns([
        {
          'id': 'srv_uuid_1',
          'idempotency_key': 'local_key_1',
          'duration_seconds': 1200,
          'distance_meters': 3200.0,
          'area_claimed': 1400.0,
          'created_at': '2026-11-25T07:20:00Z',
        },
        {
          'id': 'srv_uuid_2',
          'idempotency_key': 'other_device_run',
          'activity_type': 'running',
          'duration_seconds': 900,
          'distance_meters': 2400.0,
          'area_claimed': 800.0,
          'step_count': 2800,
          'created_at': '2026-11-24T06:30:00Z',
        },
      ]);

      expect(mergedCount, 2);
      expect(service.getRun('local_key_1')?.syncStatus, 'synced');
      final imported = service.getRun('srv_uuid_2');
      expect(imported, isNotNull);
      expect(imported!.stepCount, 2800);
      expect(imported.claimedAreaSqM, 800.0);

      final secondPass = await service.mergeServerRuns([
        {
          'id': 'srv_uuid_2',
          'idempotency_key': 'other_device_run',
          'duration_seconds': 900,
          'distance_meters': 2400.0,
          'area_claimed': 800.0,
          'created_at': '2026-11-24T06:30:00Z',
        },
      ]);
      expect(secondPass, 0);

      await box.close();
      await tempDir.delete(recursive: true);
    });

    testWidgets('FactionLeaderboard scope chips filter City and Local tiers', (
      tester,
    ) async {
      final profile = RunnerProfile(
        id: 'u_me',
        username: 'AlexStride',
        faction: 'Apex',
        level: 4,
      );

      final entries = List<LeaderboardEntry>.generate(12, (i) {
        final isMe = i == 6;
        return LeaderboardEntry(
          rank: i + 1,
          userId: isMe ? 'u_me' : 'u_$i',
          username: isMe ? 'AlexStride' : 'Runner_$i',
          faction: (i % 2 == 0 || isMe) ? 'Apex' : 'Volt',
          totalAreaSqm: i >= 10 ? 0.0 : (12 - i) * 1000.0,
          level: 3 + (i % 3),
          totalRuns: 5 + i,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FactionLeaderboard(
                profile: profile,
                territories: const [],
                initialStandings: const FactionStandingsResponse(
                  totalAreaSqm: 55000,
                  standings: [
                    FactionStanding(
                      faction: 'Apex',
                      totalAreaSqm: 30000,
                      memberCount: 6,
                      percentage: 55,
                    ),
                    FactionStanding(
                      faction: 'Volt',
                      totalAreaSqm: 25000,
                      memberCount: 4,
                      percentage: 45,
                    ),
                  ],
                ),
                initialLeaderboard: entries,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Runner_10'), findsOneWidget);

      await tester.tap(find.text('City'));
      await tester.pumpAndSettle();

      // City filters to active contenders with claimed area (top 10), excluding 0 m² Runner_10
      expect(find.text('AlexStride'), findsOneWidget);
      expect(find.text('Runner_1'), findsOneWidget);
      expect(find.text('Runner_10'), findsNothing);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      // Local windows +/- 3 ranks around index 6 -> excludes rank 1 (Runner_0)
      expect(find.text('AlexStride'), findsOneWidget);
      expect(find.text('Runner_0'), findsNothing);
    });
  });
}
