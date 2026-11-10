import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/profile/widgets/profile_hero.dart';
import 'package:territory_runner/features/social/widgets/social_squad_tab.dart';
import 'package:territory_runner/models/friend.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unique Runner ID & Add Friend By ID/Name Tests', () {
    test('RunnerProfile displayRunnerId prefers server runnerCode and falls back cleanly', () {
      final synced = RunnerProfile(
        id: 'firebase_uid_123',
        runnerCode: 'RUN-7K9M2P',
        username: 'ApexStrider',
      );
      expect(synced.displayRunnerId, equals('RUN-7K9M2P'));

      final unsynced = RunnerProfile(
        id: 'firebase_uid_123',
        username: 'ApexStrider',
      );
      expect(unsynced.displayRunnerId, startsWith('RUN-'));
      expect(unsynced.displayRunnerId.length, equals(10));
      expect(
        unsynced.displayRunnerId,
        equals(RunnerProfile.generateFallbackCode('firebase_uid_123')),
      );
    });

    test(
      'ApiClient updateMe and searchUsers parse Runner ID and search statuses',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/v1/me' && request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': 'uid_alice',
                'runner_code': 'RUN-8X4M2N',
                'username': body['username'],
                'faction': '',
                'xp': 120,
                'level': 2,
                'total_runs': 3,
              }),
              200,
            );
          }

          if (request.url.path == '/v1/users/search' &&
              request.method == 'GET') {
            expect(request.url.queryParameters['q'], equals('RUN-9P2K'));
            return http.Response(
              jsonEncode([
                {
                  'id': 'uid_sarah',
                  'runner_code': 'RUN-9P2K4W',
                  'username': 'SarahPacer',
                  'faction': 'TrailRunners',
                  'level': 6,
                  'total_area_sqm': 24000.0,
                  'friendship_status': '',
                },
              ]),
              200,
            );
          }

          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient.custom(
          httpClient: mockClient,
          baseUrl: 'http://test.local',
        );

        final updated = await apiClient.updateMe(username: 'AliceStrider');
        expect(updated.runnerCode, equals('RUN-8X4M2N'));
        expect(updated.username, equals('AliceStrider'));
        expect(updated.level, equals(2));

        final results = await apiClient.searchUsers('RUN-9P2K');
        expect(results, hasLength(1));
        expect(results.first.runnerCode, equals('RUN-9P2K4W'));
        expect(results.first.username, equals('SarahPacer'));
        expect(results.first.canAdd, isTrue);
      },
    );

    test('TerritoryService syncIdentityWithBackend retrieves permanent server runnerCode', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/me' && request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'id': 'uid_cloud_55',
              'runner_code': 'RUN-55AA77',
              'username': 'CloudRunner',
              'faction': 'Morning Crew',
              'xp': 0,
              'level': 1,
              'total_runs': 0,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final apiClient = ApiClient.custom(
        httpClient: mockClient,
        baseUrl: 'http://test.local',
      );

      final synced = await TerritoryService().syncIdentityWithBackend(
        displayName: 'CloudRunner',
        apiClient: apiClient,
      );
      expect(synced.runnerCode, equals('RUN-55AA77'));
      expect(synced.username, equals('CloudRunner'));
    });

    testWidgets(
      'ProfileHeroCard displays Unique Runner ID pill and copies to clipboard',
      (tester) async {
        String? copiedClipboard;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copiedClipboard =
                    (call.arguments as Map<dynamic, dynamic>)['text']
                        as String?;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final profile = RunnerProfile(
          id: 'uid_hero',
          runnerCode: 'RUN-4K8W2Q',
          username: 'ArnavStrider',
          level: 4,
          xp: 100,
        );

        await tester.pumpWidget(
          MaterialApp(
            scaffoldMessengerKey: AppToast.messengerKey,
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ProfileHeroCard(
                profile: profile,
                onEditCallsign: () {},
                onSelectFaction: () {},
              ),
            ),
          ),
        );

        expect(find.text('ID: RUN-4K8W2Q'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Copy Runner ID RUN-4K8W2Q'),
          findsOneWidget,
        );

        await tester.tap(find.text('ID: RUN-4K8W2Q'));
        await tester.pump();
        expect(copiedClipboard, equals('RUN-4K8W2Q'));
      },
    );

    testWidgets(
      'SocialSquadTab displays Runner ID and Name identity sharing card',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SocialSquadTab(
                friends: const [
                  FriendUser(
                    id: 'f1',
                    runnerCode: 'RUN-9T3M7X',
                    username: 'SarahPacer',
                    faction: 'City Runners',
                    totalAreaSqm: 15000,
                    level: 3,
                    xp: 300,
                    totalRuns: 5,
                  ),
                ],
                requests: const [],
                myCallsign: 'Arnav',
                myRunnerId: 'RUN-2H6N8P',
                onAddFriend: () {},
                onRespondRequest: (_, _) async {},
                onChallengeDuel: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Runner ID: RUN-2H6N8P'), findsOneWidget);
        expect(find.text('Name: Arnav'), findsOneWidget);
        expect(find.textContaining('RUN-9T3M7X'), findsOneWidget);
      },
    );

    testWidgets(
      'AddFriendSheetContent searches by ID or Name and adds friend cleanly',
      (tester) async {
        String? requestedTarget;
        bool onAddedCalled = false;

        final mockClient = MockClient((request) async {
          if (request.url.path == '/v1/users/search') {
            final q = request.url.queryParameters['q'] ?? '';
            if (q.toLowerCase().contains('sarah') ||
                q.toUpperCase() == 'RUN-9T3M7X') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'uid_sarah',
                    'runner_code': 'RUN-9T3M7X',
                    'username': 'SarahPacer',
                    'faction': 'Trail Blazers',
                    'level': 5,
                    'total_area_sqm': 12500.0,
                    'friendship_status': '',
                  },
                ]),
                200,
              );
            }
            return http.Response('[]', 200);
          }

          if (request.url.path == '/v1/friends/request' &&
              request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            requestedTarget = body['target_user_id'] as String?;
            return http.Response(jsonEncode({'status': 'pending'}), 201);
          }

          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient.custom(
          httpClient: mockClient,
          baseUrl: 'http://test.local',
        );

        await tester.pumpWidget(
          MaterialApp(
            scaffoldMessengerKey: AppToast.messengerKey,
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AddFriendSheetContent(
                  apiClient: apiClient,
                  currentCallsign: 'Arnav',
                  currentRunnerId: 'RUN-2H6N8P',
                  onAdded: () => onAddedCalled = true,
                ),
              ),
            ),
          ),
        );

        // Verify identity header & search tips appear initially
        expect(find.text('Your ID: RUN-2H6N8P'), findsOneWidget);
        expect(find.text('Name: Arnav'), findsOneWidget);
        expect(find.text('Two quick ways to connect'), findsOneWidget);

        // Search by friend's Unique Runner ID
        await tester.enterText(find.byType(TextField), 'RUN-9T3M7X');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Match renders with name, code, level, and Add button
        expect(find.text('SarahPacer'), findsOneWidget);
        expect(find.textContaining('RUN-9T3M7X'), findsWidgets);
        expect(find.text('Lvl 5'), findsOneWidget);
        expect(find.text('Add'), findsOneWidget);

        // Tap Add
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(requestedTarget, equals('uid_sarah'));
        expect(onAddedCalled, isTrue);
        expect(find.text('Sent'), findsOneWidget);
      },
    );
  });
}
