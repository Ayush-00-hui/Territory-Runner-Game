import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/profile/widgets/challenges_shelf.dart';
import 'package:territory_runner/features/profile/widgets/faction_leaderboard.dart';
import 'package:territory_runner/features/profile/widgets/profile_hero.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/leaderboard_entry.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/profile_page.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4: Athlete Hub, Challenges Shelf & Faction Turf War Tests', () {
    final testProfile = RunnerProfile(
      id: 'athlete_unit_01',
      username: 'KAI_VALKYRIE',
      totalDistanceKm: 84.5,
      xp: 1250,
      level: 5,
      badges: ['Conqueror', 'Centurion', 'Night Runner'],
      totalHexesClaimed: 42,
      currentStreak: 12,
      faction: 'Cyber Vanguard',
    );

    final List<Territory> testTerritories = [
      Territory(
        id: 't_vang_1',
        ownerId: 'athlete_unit_01',
        polygon: const [
          LatLng(37.77, -122.41),
          LatLng(37.78, -122.41),
          LatLng(37.78, -122.42),
        ],
        capturedAt: DateTime.now(),
        color: const Color(0xFF00E676),
        areaSqMeters: 45000.0,
      ),
      Territory(
        id: 't_synd_1',
        ownerId: 'syndicate_bot',
        polygon: const [
          LatLng(37.76, -122.40),
          LatLng(37.77, -122.40),
          LatLng(37.77, -122.41),
        ],
        capturedAt: DateTime.now(),
        color: const Color(0xFFFF5252),
        areaSqMeters: 30000.0,
      ),
    ];

    testWidgets(
      'ProfileHeroCard renders callsign, level, streak, and tier progress',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ProfileHeroCard(
                profile: testProfile,
                onEditCallsign: () {},
                onSelectFaction: () {},
              ),
            ),
          ),
        );

        // Verify username/callsign and avatar
        expect(find.text('KAI_VALKYRIE'), findsOneWidget);
        expect(find.text('K'), findsOneWidget); // Avatar initial

        // Verify level and faction badges
        expect(find.text('Level 5 athlete'), findsOneWidget);
        expect(find.text('Cyber Vanguard'), findsOneWidget);

        // Verify streak counter
        expect(find.text('12'), findsOneWidget);
        expect(find.byIcon(Icons.local_fire_department), findsOneWidget);

        // Verify Tier progress text
        expect(find.text('Tier progression'), findsOneWidget);
        expect(find.text('1250 / 1250 XP'), findsOneWidget);
      },
    );

    testWidgets('ChallengesShelf renders active quests and badge trophy case', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengesShelf(
                profile: testProfile,
                territoriesCount: 5,
                totalAreaSqMeters: 75000,
              ),
            ),
          ),
        ),
      );

      // Verify quests shelf header
      expect(find.text('Active territory quests'), findsOneWidget);
      expect(find.text('Resets in 14h'), findsOneWidget);

      // Verify quests appear
      expect(find.text('Daily distance run'), findsOneWidget);
      expect(find.text('Loop closure'), findsOneWidget);
      expect(find.text('Territory expansion'), findsOneWidget);

      // Verify Trophy Case shelf header
      expect(find.text('Trophy case & badges'), findsOneWidget);

      // Verify unlocked and locked badges appear
      expect(find.text('First Claim'), findsOneWidget);
      expect(find.text('10K Centurion'), findsOneWidget);
    });

    testWidgets(
      'FactionLeaderboard renders turf dominance meter and rank table',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: FactionLeaderboard(
                  profile: testProfile,
                  territories: testTerritories,
                  initialStandings: const FactionStandingsResponse(
                    totalAreaSqm: 100000,
                    standings: [
                      FactionStanding(
                        faction: 'Cyber Vanguard',
                        totalAreaSqm: 50000,
                        memberCount: 12,
                        percentage: 50.0,
                      ),
                      FactionStanding(
                        faction: 'Iron Syndicate',
                        totalAreaSqm: 30000,
                        memberCount: 8,
                        percentage: 30.0,
                      ),
                      FactionStanding(
                        faction: 'Neon Nomads',
                        totalAreaSqm: 20000,
                        memberCount: 5,
                        percentage: 20.0,
                      ),
                    ],
                  ),
                  initialLeaderboard: const [
                    LeaderboardEntry(
                      rank: 1,
                      userId: 'u1',
                      username: 'ACE_RUNNER',
                      faction: 'Cyber Vanguard',
                      totalAreaSqm: 50000,
                      level: 10,
                      totalRuns: 25,
                    ),
                    LeaderboardEntry(
                      rank: 2,
                      userId: 'u2',
                      username: 'GRID_PHANTOM',
                      faction: 'Iron Syndicate',
                      totalAreaSqm: 30000,
                      level: 8,
                      totalRuns: 19,
                    ),
                    LeaderboardEntry(
                      rank: 3,
                      userId: 'athlete_unit_01',
                      username: 'KAI_VALKYRIE',
                      faction: 'Cyber Vanguard',
                      totalAreaSqm: 20000,
                      level: 5,
                      totalRuns: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dominance meter headers
        expect(find.text('Team Standings'), findsOneWidget);
        expect(find.text('Contested'), findsOneWidget);
        expect(find.text('Vanguard'), findsWidgets);
        expect(find.text('Syndicate'), findsWidgets);
        expect(find.text('Nomads'), findsWidgets);

        // Scope filter pills
        expect(find.text('Global'), findsOneWidget);
        expect(find.text('City'), findsOneWidget);
        expect(find.text('Local'), findsOneWidget);

        // Switch scope to City Grid
        await tester.tap(find.text('City'));
        await tester.pumpAndSettle();

        // Check leaderboard rankings
        expect(find.text('Leaderboard'), findsOneWidget);
        expect(find.text('ACE_RUNNER'), findsOneWidget);
        expect(find.text('GRID_PHANTOM'), findsOneWidget);
      },
    );

    testWidgets(
      'ProfileSettingsList renders tactical haptics and no voice coach controls',
      (tester) async {
        final appPrefs = AppPreferences();
        await appPrefs.init();
        final initialHaptics = appPrefs.isHapticsEnabled;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileSettingsList(
                  firebaseService: FirebaseService(),
                  territoryService: TerritoryService(),
                  onOpenAuth: () {},
                ),
              ),
            ),
          ),
        );

        // Voice Coach controls should be completely absent
        expect(find.text('Voice Coach Audio Cues'), findsNothing);
        expect(find.text('Audio & Haptics'), findsNothing);

        // Haptics & battery saver should be present
        expect(find.text('Haptics'), findsOneWidget);
        expect(find.text('Haptic feedback'), findsOneWidget);
        expect(find.text('Battery saver'), findsOneWidget);

        // Tap haptic switch
        final switchTiles = find.byType(Switch);
        expect(switchTiles, findsNWidgets(3));

        await tester.tap(switchTiles.first);
        await tester.pumpAndSettle();
        expect(appPrefs.isHapticsEnabled, !initialHaptics);

        // Restore
        await appPrefs.toggleHaptics(initialHaptics);
      },
    );

    testWidgets(
      'ProfilePage switches tabs between Athlete Profile and Faction Turf War',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: ProfilePage(
              initialProfile: testProfile,
              initialTerritories: testTerritories,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // All segment tab buttons exist
        expect(find.text('Profile'), findsNWidgets(2));
        expect(find.text('Teams'), findsOneWidget);
        expect(find.text('League'), findsOneWidget);
        expect(find.text('Friends'), findsOneWidget);

        // In athlete tab, Hero and Settings are visible
        expect(find.text('KAI_VALKYRIE'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // Tap Faction Turf War tab
        await tester.tap(find.text('Teams'));
        await tester.pumpAndSettle();

        // In Turf War tab, Dominance Meter is visible
        expect(find.text('Team Standings'), findsOneWidget);
        expect(find.text('Leaderboard'), findsOneWidget);

        // Tap League tab
        await tester.tap(find.text('League'));
        await tester.pumpAndSettle();

        // Tap back to Athlete Profile
        await tester.tap(find.text('Profile').first);
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
      },
    );
  });
}
