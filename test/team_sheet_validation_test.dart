import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/profile/widgets/profile_dialogs.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RunnerProfile profile;
  late TerritoryService territoryService;
  bool wasUpdated = false;

  setUp(() {
    profile = RunnerProfile(
      id: 'usr_sheet_tester',
      username: 'SheetTester',
      faction: '',
    );
    territoryService = TerritoryService();
    wasUpdated = false;
  });

  tearDown(() {
    ApiClient.resetMockInstance();
  });

  Widget buildSheet() {
    return MaterialApp(
      home: Scaffold(
        body: TeamSelectionSheet(
          profile: profile,
          territoryService: territoryService,
          onUpdated: () {
            wasUpdated = true;
          },
        ),
      ),
    );
  }

  group('TeamSelectionSheet Client & Server Validation Tests', () {
    testWidgets('empty input submission shows inline error and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // Tap Save with empty text
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Team name cannot be empty'), findsOneWidget);
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('too short input shows inline error and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'AB');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Team name must be at least 3 characters long'),
        findsOneWidget,
      );
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('emoji input shows inline error and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Rocket 🚀 Runners');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
        ),
        findsOneWidget,
      );
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('reserved word input shows inline error and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'admin');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Team name cannot be a reserved word (e.g., admin, support, official)',
        ),
        findsOneWidget,
      );
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('HTML markup input shows inline error and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '<b>Hackers</b>');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Team name cannot contain HTML or markup tags'),
        findsOneWidget,
      );
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('URL input shows inline error and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'http://cheat.io');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Team name cannot contain URLs or web links'),
        findsOneWidget,
      );
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('valid team name saves and triggers update', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/factions/standings') {
          return http.Response(
            jsonEncode({'standings': [], 'total_area_sqm': 0.0}),
            200,
          );
        }
        if (request.url.path == '/v1/me/faction') {
          return http.Response(
            jsonEncode({'status': 'ok', 'faction': 'Morning Striders'}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      ApiClient.setMockInstance(
        ApiClient.custom(httpClient: mockClient, baseUrl: 'http://test'),
      );

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Morning   Striders  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profile.faction, 'Morning Striders');
      expect(wasUpdated, isTrue);
    });

    testWidgets('server 429 rate limit error displays inline and toast', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/factions/standings') {
          return http.Response(
            jsonEncode({'standings': [], 'total_area_sqm': 0.0}),
            200,
          );
        }
        if (request.url.path == '/v1/me/faction') {
          return http.Response(
            jsonEncode({
              'error': 'RATE_LIMIT_EXCEEDED',
              'detail': 'Team change rate limit exceeded. You can only change teams 3 times per day.',
              'retry_after': 28800,
            }),
            429,
          );
        }
        return http.Response('Not Found', 404);
      });
      ApiClient.setMockInstance(
        ApiClient.custom(httpClient: mockClient, baseUrl: 'http://test'),
      );

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Fourth Team Today');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Error message from server must be displayed inline
      expect(
        find.text(
          'Team change rate limit exceeded. You can only change teams 3 times per day.',
        ),
        findsOneWidget,
      );
      // Profile must NOT be changed to the rejected team
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('server 400 abusive deny-list error displays inline', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/factions/standings') {
          return http.Response(
            jsonEncode({'standings': [], 'total_area_sqm': 0.0}),
            200,
          );
        }
        if (request.url.path == '/v1/me/faction') {
          return http.Response(
            jsonEncode({
              'error': 'INVALID_TEAM_NAME',
              'detail': 'Team name contains prohibited or abusive terms',
            }),
            400,
          );
        }
        return http.Response('Not Found', 404);
      });
      ApiClient.setMockInstance(
        ApiClient.custom(httpClient: mockClient, baseUrl: 'http://test'),
      );

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Prohibited Clan');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Team name contains prohibited or abusive terms'),
        findsOneWidget,
      );
      expect(profile.faction, '');
      expect(wasUpdated, isFalse);
    });

    testWidgets('Leave Team clears faction to empty', (tester) async {
      profile.faction = 'Solaris Nomads';

      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/factions/standings') {
          return http.Response(
            jsonEncode({'standings': [], 'total_area_sqm': 0.0}),
            200,
          );
        }
        if (request.url.path == '/v1/me/faction') {
          return http.Response(
            jsonEncode({'status': 'ok', 'faction': ''}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      ApiClient.setMockInstance(
        ApiClient.custom(httpClient: mockClient, baseUrl: 'http://test'),
      );

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      expect(find.text('Leave Team (Run Independent)'), findsOneWidget);
      await tester.tap(find.text('Leave Team (Run Independent)'));
      await tester.pumpAndSettle();

      expect(profile.faction, '');
      expect(wasUpdated, isTrue);
    });
  });
}
