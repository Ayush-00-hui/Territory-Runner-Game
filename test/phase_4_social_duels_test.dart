import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/social/widgets/social_hub_sheet.dart';
import 'package:territory_runner/models/duel.dart';
import 'package:territory_runner/models/friend.dart';
import 'package:territory_runner/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: Friend Models Tests', () {
    test('FriendUser serialization roundtrip', () {
      final json = {
        'id': 'u1',
        'username': 'NeonRacer',
        'faction': 'Cyber Vanguard',
        'total_area_sqm': 150000.0,
        'level': 7,
        'xp': 12500,
        'total_runs': 42,
      };

      final friend = FriendUser.fromJson(json);
      expect(friend.id, equals('u1'));
      expect(friend.username, equals('NeonRacer'));
      expect(friend.faction, equals('Cyber Vanguard'));
      expect(friend.totalAreaSqm, equals(150000.0));
      expect(friend.level, equals(7));
      expect(friend.xp, equals(12500));
      expect(friend.totalRuns, equals(42));

      final output = friend.toJson();
      expect(output['username'], equals('NeonRacer'));
      expect(output['xp'], equals(12500));
    });

    test('FriendRequestDetail serialization roundtrip', () {
      final json = {
        'id': 'req_101',
        'requester_id': 'u_alice',
        'requester_name': 'AliceRunner',
        'requester_faction': 'Solar Syndicate',
        'addressee_id': 'u_bob',
        'addressee_name': 'BobWalker',
        'status': 'pending',
        'created_at': '2026-10-17T12:00:00.000Z',
        'is_incoming': true,
      };

      final req = FriendRequestDetail.fromJson(json);
      expect(req.id, equals('req_101'));
      expect(req.requesterName, equals('AliceRunner'));
      expect(req.isIncoming, isTrue);
      expect(req.status, equals('pending'));

      final output = req.toJson();
      expect(output['id'], equals('req_101'));
      expect(output['is_incoming'], isTrue);
    });
  });

  group('Phase 4: Duel Model Tests', () {
    test('Duel serialization and progress telemetry calculation', () {
      final json = {
        'id': 'duel_01',
        'challenger_id': 'me',
        'challenger_username': 'MyRunner',
        'opponent_id': 'rival',
        'opponent_username': 'RivalRacer',
        'target_type': 'area',
        'target_value': 10000.0,
        'status': 'active',
        'challenger_progress': 7500.0,
        'opponent_progress': 4000.0,
        'xp_stake': 500,
        'expires_at': '2026-10-18T12:00:00.000Z',
        'created_at': '2026-10-17T12:00:00.000Z',
      };

      final duel = Duel.fromJson(json);
      expect(duel.id, equals('duel_01'));
      expect(duel.isActive, isTrue);
      expect(duel.isPending, isFalse);
      expect(duel.isCompleted, isFalse);

      // Challenger perspective
      expect(duel.isChallenger('me'), isTrue);
      expect(duel.opponentName('me'), equals('RivalRacer'));
      expect(duel.myProgress('me'), equals(7500.0));
      expect(duel.theirProgress('me'), equals(4000.0));
      expect(duel.myProgressFraction('me'), closeTo(0.75, 0.001));
      expect(duel.theirProgressFraction('me'), closeTo(0.40, 0.001));

      // Opponent perspective
      expect(duel.isChallenger('rival'), isFalse);
      expect(duel.opponentName('rival'), equals('MyRunner'));
      expect(duel.myProgress('rival'), equals(4000.0));
      expect(duel.theirProgress('rival'), equals(7500.0));
      expect(duel.myProgressFraction('rival'), closeTo(0.40, 0.001));

      // Win verification
      expect(duel.didIWin('me'), isFalse); // not completed yet
      final wonDuel = Duel.fromJson({
        ...json,
        'status': 'completed',
        'winner_id': 'me',
      });
      expect(wonDuel.isCompleted, isTrue);
      expect(wonDuel.didIWin('me'), isTrue);
      expect(wonDuel.didIWin('rival'), isFalse);
    });
  });

  group('Phase 4: ApiClient Social & Duels Integration Tests', () {
    test('getFriends, getFriendRequests, and friend actions', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/friends' && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'f1',
                'username': 'CyberFalcon',
                'faction': 'Cyber Vanguard',
                'total_area_sqm': 20000.0,
                'level': 4,
                'xp': 4000,
                'total_runs': 12,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/v1/friends/requests' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'r1',
                'requester_id': 'req_u',
                'requester_name': 'GhostRunner',
                'requester_faction': 'Shadow Syndicate',
                'addressee_id': 'me',
                'addressee_name': 'Me',
                'status': 'pending',
                'created_at': DateTime.now().toIso8601String(),
                'is_incoming': true,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/v1/friends/request' &&
            request.method == 'POST') {
          return http.Response(jsonEncode({'status': 'pending'}), 201);
        }

        if (request.url.path.startsWith('/v1/friends/request/') &&
            request.method == 'PUT') {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient.custom(
        httpClient: mockClient,
        baseUrl: 'http://test.local',
      );

      final friends = await apiClient.getFriends();
      expect(friends.length, equals(1));
      expect(friends.first.username, equals('CyberFalcon'));

      final requests = await apiClient.getFriendRequests();
      expect(requests.length, equals(1));
      expect(requests.first.requesterName, equals('GhostRunner'));

      final sent = await apiClient.sendFriendRequest('target_99');
      expect(sent, isTrue);

      final responded = await apiClient.respondFriendRequest('r1', 'accept');
      expect(responded, isTrue);
    });

    test('getDuels, createDuel, acceptDuel, and declineDuel', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/duels' && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'duel_123',
                'challenger_id': 'me',
                'challenger_username': 'Me',
                'opponent_id': 'rival',
                'opponent_username': 'Rival',
                'target_type': 'distance',
                'target_value': 5000.0,
                'status': 'active',
                'challenger_progress': 2500.0,
                'opponent_progress': 1200.0,
                'xp_stake': 500,
                'expires_at': DateTime.now()
                    .add(const Duration(hours: 12))
                    .toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/v1/duels' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'duel_new',
              'challenger_id': 'me',
              'challenger_username': 'Me',
              'opponent_id': body['opponent_id'],
              'opponent_username': 'Opponent',
              'target_type': body['target_type'],
              'target_value': body['target_value'],
              'status': 'pending',
              'challenger_progress': 0.0,
              'opponent_progress': 0.0,
              'xp_stake': body['xp_stake'],
              'expires_at': DateTime.now()
                  .add(const Duration(hours: 24))
                  .toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/v1/duels/duel_123/accept' &&
            request.method == 'PUT') {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }

        if (request.url.path == '/v1/duels/duel_123/decline' &&
            request.method == 'PUT') {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient.custom(
        httpClient: mockClient,
        baseUrl: 'http://test.local',
      );

      final duels = await apiClient.getDuels();
      expect(duels.length, equals(1));
      expect(duels.first.id, equals('duel_123'));
      expect(duels.first.targetType, equals('distance'));

      final created = await apiClient.createDuel(
        opponentId: 'rival_99',
        targetType: 'distance',
        targetValue: 10000.0,
      );
      expect(created, isNotNull);
      expect(created!.id, equals('duel_new'));
      expect(created.status, equals('pending'));

      final accepted = await apiClient.acceptDuel('duel_123');
      expect(accepted, isTrue);

      final declined = await apiClient.declineDuel('duel_123');
      expect(declined, isTrue);
    });
  });

  group('Phase 4: SocialHubView Widget Tests', () {
    testWidgets('Renders Squad members and allows tab switching to Duels', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/friends') {
          return http.Response(
            jsonEncode([
              {
                'id': 'f_valkyrie',
                'username': 'ValkyrieRunner',
                'faction': 'Cyber Vanguard',
                'total_area_sqm': 45000.0,
                'level': 5,
                'xp': 8200,
                'total_runs': 19,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/v1/friends/requests') {
          return http.Response(jsonEncode([]), 200);
        }
        if (request.url.path == '/v1/duels') {
          return http.Response(
            jsonEncode([
              {
                'id': 'duel_live',
                'challenger_id': 'test_me',
                'challenger_username': 'TestRunner',
                'opponent_id': 'f_valkyrie',
                'opponent_username': 'ValkyrieRunner',
                'target_type': 'area',
                'target_value': 10000.0,
                'status': 'active',
                'challenger_progress': 6000.0,
                'opponent_progress': 3000.0,
                'xp_stake': 500,
                'expires_at': DateTime.now()
                    .add(const Duration(hours: 18))
                    .toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final apiClient = ApiClient.custom(
        httpClient: mockClient,
        baseUrl: 'http://test.local',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialHubView(apiClient: apiClient, currentUserId: 'test_me'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Squad tab is active and shows ValkyrieRunner
      expect(find.text('Social Syndicate & Duels'), findsOneWidget);
      expect(find.text('ValkyrieRunner'), findsOneWidget);
      expect(find.text('Lvl 5'), findsOneWidget);
      expect(find.text('Duel'), findsOneWidget);

      // Switch to Duels tab
      await tester.tap(find.textContaining('Duels (1)'));
      await tester.pumpAndSettle();

      // Verify active duel details
      expect(find.text('Active conquests (1)'), findsOneWidget);
      expect(find.text('Area: 10000 m²'), findsOneWidget);
      expect(find.text('Battle in progress'), findsOneWidget);
      expect(find.textContaining('VS ValkyrieRunner'), findsOneWidget);
    });

    testWidgets(
      'Shows incoming friend request with Accept and Decline actions',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/v1/friends') {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.url.path == '/v1/friends/requests') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'req_incoming',
                  'requester_id': 'req_alex',
                  'requester_name': 'AlexStriker',
                  'requester_faction': 'Neon Syndicate',
                  'addressee_id': 'test_me',
                  'addressee_name': 'Me',
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                  'is_incoming': true,
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/v1/duels') {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response('[]', 200);
        });

        final apiClient = ApiClient.custom(
          httpClient: mockClient,
          baseUrl: 'http://test.local',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SocialHubView(
                apiClient: apiClient,
                currentUserId: 'test_me',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.textContaining('Incoming squad invitations (1)'),
          findsOneWidget,
        );
        expect(find.text('AlexStriker'), findsOneWidget);
        expect(find.text('Neon Syndicate'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      },
    );

    testWidgets('Renders cached friends and duels when network is offline', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'territory_runner_cached_friends': jsonEncode([
          {
            'id': 'f_offline',
            'username': 'OfflinePacer',
            'faction': 'Iron Legion',
            'total_area_sqm': 30000.0,
            'level': 3,
            'xp': 3000,
            'total_runs': 10,
          },
        ]),
        'territory_runner_cached_duels': jsonEncode([
          {
            'id': 'duel_offline',
            'challenger_id': 'test_me',
            'challenger_username': 'TestRunner',
            'opponent_id': 'f_offline',
            'opponent_username': 'OfflinePacer',
            'target_type': 'area',
            'target_value': 10000.0,
            'status': 'active',
            'challenger_progress': 4500.0,
            'opponent_progress': 2000.0,
            'xp_stake': 250,
            'expires_at': DateTime.now()
                .add(const Duration(hours: 12))
                .toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          },
        ]),
      });

      // ApiClient that fails all requests with network unreachable
      final failingMockClient = MockClient((request) async {
        return http.Response('Network Error', 503);
      });

      final apiClient = ApiClient.custom(
        httpClient: failingMockClient,
        baseUrl: 'http://test.local',
        maxRetries: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialHubView(apiClient: apiClient, currentUserId: 'test_me'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify offline banner is shown
      expect(
        find.text('Network offline: displaying cached syndicates'),
        findsOneWidget,
      );

      // Verify cached friend is displayed
      expect(find.text('OfflinePacer'), findsOneWidget);
      expect(find.text('Lvl 3'), findsOneWidget);

      // Switch to Duels tab and verify cached active duel
      await tester.tap(find.textContaining('Duels (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Active conquests (1)'), findsOneWidget);
      expect(find.text('Area: 10000 m²'), findsOneWidget);
      expect(find.text('Battle in progress'), findsOneWidget);
      expect(find.textContaining('VS OfflinePacer'), findsOneWidget);
    });
  });
}
