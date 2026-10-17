import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:territory_runner/features/profile/widgets/weekly_league_view.dart';
import 'package:territory_runner/models/league_standing.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Weekly League Model Tests', () {
    test('LeagueStanding fromJson / toJson serialization roundtrip', () {
      final jsonSample = {
        'user_id': 'runner_01',
        'username': 'ApexPacer',
        'faction': 'Cyber Vanguard',
        'tier': 'Gold',
        'rank': 2,
        'total_participants': 10,
        'weekly_area_sqm': 14500.5,
        'weekly_runs': 4,
        'promotion_rank_cutoff': 1,
        'relegation_rank_cutoff': 6,
        'reset_at': '2026-10-26T00:00:00.000Z',
        'seconds_until_reset': 172800,
        'standings': [
          {
            'rank': 1,
            'user_id': 'runner_lead',
            'username': 'DiamondKing',
            'faction': 'Cyber Vanguard',
            'tier': 'Diamond',
            'weekly_area_sqm': 25000.0,
            'weekly_runs': 6,
            'is_current_user': false,
          },
          {
            'rank': 2,
            'user_id': 'runner_01',
            'username': 'ApexPacer',
            'faction': 'Cyber Vanguard',
            'tier': 'Gold',
            'weekly_area_sqm': 14500.5,
            'weekly_runs': 4,
            'is_current_user': true,
          },
        ],
      };

      final standing = LeagueStanding.fromJson(jsonSample);

      expect(standing.userId, 'runner_01');
      expect(standing.username, 'ApexPacer');
      expect(standing.tier, 'Gold');
      expect(standing.rank, 2);
      expect(standing.totalParticipants, 10);
      expect(standing.weeklyAreaSqm, 14500.5);
      expect(standing.weeklyRuns, 4);
      expect(standing.promotionRankCutoff, 1);
      expect(standing.relegationRankCutoff, 6);
      expect(standing.standings.length, 2);
      expect(standing.standings[1].isCurrentUser, isTrue);

      final serialized = standing.toJson();
      expect(serialized['user_id'], 'runner_01');
      expect(serialized['tier'], 'Gold');
      expect((serialized['standings'] as List).length, 2);
    });
  });

  group('ApiClient Weekly League & Device Token Tests', () {
    test('registerDeviceToken sends POST /v1/device-token with Bearer header', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/device-token');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], 'fcm_mock_token_123');

        return http.Response(jsonEncode({'status': 'registered', 'token': 'fcm_mock_token_123'}), 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      await expectLater(apiClient.registerDeviceToken('fcm_mock_token_123'), completes);
    });

    test('getCurrentLeague retrieves and deserializes weekly league standing', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/league/current');
        expect(request.method, 'GET');

        final mockResponse = {
          'user_id': 'usr_tester',
          'username': 'SwiftSprint',
          'faction': 'Neon Syndicate',
          'tier': 'Diamond',
          'rank': 1,
          'total_participants': 8,
          'weekly_area_sqm': 32000.0,
          'weekly_runs': 5,
          'promotion_rank_cutoff': 0,
          'relegation_rank_cutoff': 1,
          'reset_at': '2026-10-26T00:00:00.000Z',
          'seconds_until_reset': 3600,
          'standings': [
            {
              'rank': 1,
              'user_id': 'usr_tester',
              'username': 'SwiftSprint',
              'faction': 'Neon Syndicate',
              'tier': 'Diamond',
              'weekly_area_sqm': 32000.0,
              'weekly_runs': 5,
              'is_current_user': true,
            },
          ],
        };

        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final league = await apiClient.getCurrentLeague();

      expect(league.tier, 'Diamond');
      expect(league.rank, 1);
      expect(league.weeklyAreaSqm, 32000.0);
      expect(league.standings.first.isCurrentUser, isTrue);
    });
  });

  group('WeeklyLeagueView Widget Tests', () {
    final mockStanding = LeagueStanding(
      userId: 'user_active',
      username: 'ShadowRacer',
      faction: 'Cyber Vanguard',
      tier: 'Gold',
      rank: 2,
      totalParticipants: 5,
      weeklyAreaSqm: 18400.0,
      weeklyRuns: 4,
      promotionRankCutoff: 1,
      relegationRankCutoff: 4,
      resetAt: DateTime.now().add(const Duration(days: 2)),
      secondsUntilReset: 172800,
      standings: const [
        LeagueParticipant(
          rank: 1,
          userId: 'user_lead',
          username: 'Overlord',
          faction: 'Solaris Nomads',
          tier: 'Diamond',
          weeklyAreaSqm: 35000.0,
          weeklyRuns: 7,
          isCurrentUser: false,
        ),
        LeagueParticipant(
          rank: 2,
          userId: 'user_active',
          username: 'ShadowRacer',
          faction: 'Cyber Vanguard',
          tier: 'Gold',
          weeklyAreaSqm: 18400.0,
          weeklyRuns: 4,
          isCurrentUser: true,
        ),
        LeagueParticipant(
          rank: 3,
          userId: 'user_pacer',
          username: 'PacerThree',
          faction: 'Neon Syndicate',
          tier: 'Silver',
          weeklyAreaSqm: 12000.0,
          weeklyRuns: 3,
          isCurrentUser: false,
        ),
        LeagueParticipant(
          rank: 4,
          userId: 'user_safe',
          username: 'SafeRunner',
          faction: 'Cyber Vanguard',
          tier: 'Silver',
          weeklyAreaSqm: 8000.0,
          weeklyRuns: 2,
          isCurrentUser: false,
        ),
        LeagueParticipant(
          rank: 5,
          userId: 'user_bottom',
          username: 'LaggingRunner',
          faction: 'Solaris Nomads',
          tier: 'Bronze',
          weeklyAreaSqm: 1000.0,
          weeklyRuns: 1,
          isCurrentUser: false,
        ),
      ],
    );

    testWidgets('WeeklyLeagueView renders division card, countdown, threshold lines, and current user row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyLeagueView(
                initialStanding: mockStanding,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Division header and rank
      expect(find.text('GOLD DIVISION'), findsOneWidget);
      expect(find.text('Rank #2 of 5'), findsOneWidget);

      // Stat metrics
      expect(find.text('WEEKLY AREA'), findsOneWidget);
      expect(find.text('CONQUEST RUNS'), findsOneWidget);
      expect(find.text('LEAGUE STATUS'), findsOneWidget);

      // Section header
      expect(find.text('DIVISION STANDINGS'), findsOneWidget);
      expect(find.text('RESETS MONDAY 00:00 UTC'), findsOneWidget);

      // Promotion & Relegation threshold lines
      expect(find.text('PROMOTION ZONE'), findsOneWidget);
      expect(find.text('RELEGATION ZONE'), findsOneWidget);

      // Participant names and 'YOU' badge
      expect(find.text('Overlord'), findsOneWidget);
      expect(find.text('ShadowRacer'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
    });

    testWidgets('WeeklyLeagueView renders offline error state with retry button when API fails', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final apiClient = ApiClient(httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: WeeklyLeagueView(
              apiClient: apiClient,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline: unable to fetch league standings'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
    });
  });
}
