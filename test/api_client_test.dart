import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/services/api_client.dart';

void main() {
  group('ApiClient Tests', () {
    test('submitRun successfully posts GPS track and returns capture result', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.url.path, '/v1/runs');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.headers['X-Dev-User'], isNotEmpty);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['idempotency_key'], 'test_key_123');
        expect(body['points'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'run_id': 'run_mock_001',
            'idempotency_key': 'test_key_123',
            'status': 'accepted',
            'loop_detected': true,
            'area_claimed_sqm': 9180.0,
            'xp_awarded': 459,
            'player_total_area_sqm': 9180.0,
          }),
          201,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mockbackend');

      final result = await apiClient.submitRun(
        idempotencyKey: 'test_key_123',
        points: [
          const LatLng(51.5000, -0.1200),
          const LatLng(51.5009, -0.1200),
          const LatLng(51.5009, -0.1214),
          const LatLng(51.5000, -0.1214),
        ],
        durationSeconds: 300,
        distanceMeters: 400.0,
      );

      expect(requestCount, equals(1));
      expect(result['run_id'], equals('run_mock_001'));
      expect(result['area_claimed_sqm'], equals(9180.0));
    });

    test('submitRun retries on transient 500 error and recovers', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount < 2) {
          // First attempt returns 500 Internal Server Error
          return http.Response('{"error":"DB_BUSY"}', 500);
        }
        // Second attempt succeeds
        return http.Response(
          jsonEncode({
            'run_id': 'run_recovered',
            'idempotency_key': 'test_retry_key',
            'status': 'accepted',
          }),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mockbackend');

      final result = await apiClient.submitRun(
        idempotencyKey: 'test_retry_key',
        points: [const LatLng(51.5, -0.12)],
        durationSeconds: 100,
        distanceMeters: 100.0,
      );

      expect(requestCount, equals(2), reason: 'Should have retried after initial 500 error');
      expect(result['run_id'], equals('run_recovered'));
    });

    test('getTerritoriesInBBox parses GeoJSON FeatureCollection', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/territories');
        expect(request.url.queryParameters['bbox'], equals('-0.13,51.49,-0.11,51.51'));

        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'id': 'poly_usr_99_territory',
                'properties': {
                  'owner_id': 'usr_99',
                  'username': 'RivalRunner',
                  'area_sqm': 12500.0,
                  'updated_at': '2026-10-13T10:00:00Z',
                },
                'geometry': {
                  'type': 'MultiPolygon',
                  'coordinates': [
                    [
                      [
                        [-0.1200, 51.5000],
                        [-0.1200, 51.5010],
                        [-0.1210, 51.5010],
                        [-0.1210, 51.5000],
                        [-0.1200, 51.5000],
                      ]
                    ]
                  ],
                },
              }
            ],
          }),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mockbackend');
      final territories = await apiClient.getTerritoriesInBBox(
        minLng: -0.13,
        minLat: 51.49,
        maxLng: -0.11,
        maxLat: 51.51,
      );

      expect(territories.length, equals(1));
      expect(territories.first.id, equals('poly_usr_99_territory'));
      expect(territories.first.ownerId, equals('usr_99'));
      expect(territories.first.polygons.length, equals(1));
      expect(territories.first.polygons.first.length, equals(5));
      expect(territories.first.areaSqMeters, equals(12500.0));
    });

    test('getLeaderboard parses sorted ranking entries from backend', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/leaderboard');
        expect(request.url.queryParameters['limit'], equals('10'));

        return http.Response(
          jsonEncode({
            'leaderboard': [
              {
                'rank': 1,
                'user_id': 'usr_alpha',
                'username': 'ApexRunner',
                'faction': 'Cyber Vanguard',
                'total_area_sqm': 45000.0,
                'total_runs': 12,
                'xp': 2400,
                'level': 5,
              },
              {
                'rank': 2,
                'user_id': 'usr_beta',
                'username': 'ShadowSprint',
                'faction': 'Neon Syndicate',
                'total_area_sqm': 32000.0,
                'total_runs': 8,
                'xp': 1600,
                'level': 3,
              },
            ],
            'count': 2,
          }),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mockbackend');
      final entries = await apiClient.getLeaderboard(limit: 10);

      expect(entries.length, equals(2));
      expect(entries[0].rank, equals(1));
      expect(entries[0].username, equals('ApexRunner'));
      expect(entries[0].totalAreaSqm, equals(45000.0));
      expect(entries[0].level, equals(5));

      expect(entries[1].rank, equals(2));
      expect(entries[1].username, equals('ShadowSprint'));
    });
  });
}

