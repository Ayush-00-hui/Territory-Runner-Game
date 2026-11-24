import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/social/widgets/report_dialog.dart';
import 'package:territory_runner/features/social/widgets/social_feed_tab.dart';
import 'package:territory_runner/models/feed_item.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pref_share_runs_with_friends': false,
    });
    await AppPreferences().init();
  });

  group('Phase G4: FeedItem Model Tests', () {
    test(
      'FeedItem serializes and deserializes accurately with privacy route',
      () {
        final item = FeedItem(
          id: 'run_test_1',
          userId: 'usr_alice',
          username: 'AliceRunner',
          faction: 'Cyber Vanguard',
          activityType: 'running',
          durationSeconds: 1500,
          distanceMeters: 5200.0,
          areaClaimed: 4500.0,
          createdAt: DateTime.utc(2026, 11, 24, 10, 0),
          routeThumbnail: [
            const LatLng(12.9716, 77.5946),
            const LatLng(12.9760, 77.6000),
          ],
          kudosCounts: {'kudos': 3, 'fire': 1},
          myKudos: 'kudos',
        );

        final json = item.toJson();
        final fromJson = FeedItem.fromJson(json);

        expect(fromJson.id, 'run_test_1');
        expect(fromJson.username, 'AliceRunner');
        expect(fromJson.distanceMeters, 5200.0);
        expect(fromJson.totalKudosCount, 4);
        expect(fromJson.myKudos, 'kudos');
        expect(fromJson.routeThumbnail.length, 2);
        expect(fromJson.routeThumbnail[0].latitude, 12.9716);
      },
    );

    test('FeedItem copyWith updates reactions cleanly', () {
      final item = FeedItem(
        id: 'run_test_2',
        userId: 'usr_bob',
        username: 'Bob',
        durationSeconds: 1200,
        distanceMeters: 4000.0,
        areaClaimed: 2000.0,
        createdAt: DateTime.now(),
        kudosCounts: {'kudos': 1},
        myKudos: 'kudos',
      );

      final updated = item.copyWith(
        myKudos: 'fire',
        kudosCounts: {'kudos': 0, 'fire': 1},
      );

      expect(updated.myKudos, 'fire');
      expect(updated.kudosCounts['fire'], 1);

      final cleared = updated.copyWith(clearMyKudos: true);
      expect(cleared.myKudos, isNull);
    });
  });

  group('Phase G4: SocialFeedTab Widget Tests', () {
    testWidgets(
      'Renders empty state and privacy banner when feed is empty and sharing is off',
      (tester) async {
        final mockClient = ApiClient(
          httpClient: MockClient((req) async {
            if (req.url.path == '/v1/feed') {
              return http.Response('{"feed": []}', 200);
            }
            return http.Response('{"error": "not_found"}', 404);
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SocialFeedTab(apiClient: mockClient)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Your runs are private'), findsOneWidget);
        expect(find.text('No friend activities yet'), findsOneWidget);
        expect(find.text('Add friends'), findsOneWidget);
      },
    );

    testWidgets('Renders friend run card with metrics and reaction chips', (
      tester,
    ) async {
      final mockClient = ApiClient(
        httpClient: MockClient((req) async {
          if (req.url.path == '/v1/feed') {
            return http.Response('''
            {
              "feed": [
                {
                  "id": "run_shared_100",
                  "user_id": "usr_friend_1",
                  "username": "SwiftRunner",
                  "faction": "Neon Nomads",
                  "activityType": "running",
                  "duration_seconds": 1800,
                  "distance_meters": 6500.0,
                  "area_claimed": 8200.0,
                  "created_at": "2026-11-24T12:00:00Z",
                  "route_thumbnail": [[12.9716, 77.5946], [12.9750, 77.6000]],
                  "kudos_counts": {"kudos": 2, "fire": 1},
                  "my_kudos": null
                }
              ]
            }
            ''', 200);
          }
          if (req.url.path == '/v1/feed/run_shared_100/kudos' &&
              req.method == 'POST') {
            return http.Response('{"status": "ok", "reaction": "clap"}', 200);
          }
          return http.Response('{"error": "not_found"}', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SocialFeedTab(apiClient: mockClient)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SwiftRunner'), findsOneWidget);
      expect(find.text('6.50 km'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('8200 m²'), findsOneWidget);
      expect(find.text('3 kudos'), findsOneWidget);

      // Tap 'clap' reaction chip
      final clapFinder = find.text('👏');
      expect(clapFinder, findsOneWidget);
      await tester.tap(clapFinder);
      await tester.pumpAndSettle();

      // State updated optimistically to reflect 1 clap
      expect(find.text('4 kudos'), findsOneWidget);
    });
  });

  group('Phase G4: ReportDialog Tests', () {
    testWidgets('Report dialog renders reason choices and submit CTA', (
      tester,
    ) async {
      var wasSubmitted = false;
      final mockClient = ApiClient(
        httpClient: MockClient((req) async {
          if (req.url.path == '/v1/moderation/report' && req.method == 'POST') {
            wasSubmitted = true;
            return http.Response(
              '{"status": "reported", "id": "rep_123"}',
              201,
            );
          }
          return http.Response('{"error": "not_found"}', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportDialog(
              userId: 'usr_bad_actor',
              runId: 'run_flagged_1',
              apiClient: mockClient,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report Activity'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Submit report'), findsOneWidget);

      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(wasSubmitted, isTrue);
    });
  });
}
