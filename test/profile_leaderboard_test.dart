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

    testWidgets('ProfileHeroCard renders callsign, level, streak, and tier progress', (tester) async {
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
      expect(find.text('LEVEL 5 ATHLETE'), findsOneWidget);
      expect(find.text('Cyber Vanguard'), findsOneWidget);

      // Verify streak counter
      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);

      // Verify Tier progress text
      expect(find.text('TIER PROGRESSION'), findsOneWidget);
      expect(find.text('1250 / 1250 XP'), findsOneWidget);
    });

    testWidgets('ChallengesShelf renders active quests and badge trophy case', (tester) async {
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
      expect(find.text('ACTIVE CONQUEST QUESTS'), findsOneWidget);
      expect(find.text('RESETS IN 14H'), findsOneWidget);

      // Verify quests appear
      expect(find.text('DAILY SECTOR SCOUT'), findsOneWidget);
      expect(find.text('LOOP CLOSURE'), findsOneWidget);
      expect(find.text('TERRITORY EXPANSION'), findsOneWidget);

      // Verify Trophy Case shelf header
      expect(find.text('TROPHY CASE & BADGES'), findsOneWidget);

      // Verify unlocked and locked badges appear
      expect(find.text('First Conquest'), findsOneWidget);
      expect(find.text('10K Centurion'), findsOneWidget);
    });

    testWidgets('FactionLeaderboard renders turf dominance meter and rank table', (tester) async {
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
                    FactionStanding(faction: 'Cyber Vanguard', totalAreaSqm: 50000, memberCount: 12, percentage: 50.0),
                    FactionStanding(faction: 'Iron Syndicate', totalAreaSqm: 30000, memberCount: 8, percentage: 30.0),
                    FactionStanding(faction: 'Neon Nomads', totalAreaSqm: 20000, memberCount: 5, percentage: 20.0),
                  ],
                ),
                initialLeaderboard: const [
                  LeaderboardEntry(rank: 1, userId: 'u1', username: 'ACE_RUNNER', faction: 'Cyber Vanguard', totalAreaSqm: 50000, level: 10, totalRuns: 25),
                  LeaderboardEntry(rank: 2, userId: 'u2', username: 'GRID_PHANTOM', faction: 'Iron Syndicate', totalAreaSqm: 30000, level: 8, totalRuns: 19),
                  LeaderboardEntry(rank: 3, userId: 'athlete_unit_01', username: 'KAI_VALKYRIE', faction: 'Cyber Vanguard', totalAreaSqm: 20000, level: 5, totalRuns: 12),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dominance meter headers
      expect(find.text('TURF WAR DOMINANCE'), findsOneWidget);
      expect(find.text('CONTESTED'), findsOneWidget);
      expect(find.text('VANGUARD'), findsWidgets);
      expect(find.text('SYNDICATE'), findsWidgets);
      expect(find.text('NOMADS'), findsWidgets);

      // Scope filter pills
      expect(find.text('GLOBAL'), findsOneWidget);
      expect(find.text('CITY'), findsOneWidget);
      expect(find.text('LOCAL'), findsOneWidget);

      // Switch scope to City Grid
      await tester.tap(find.text('CITY'));
      await tester.pumpAndSettle();

      // Check leaderboard rankings
      expect(find.text('CONQUEROR RANKINGS'), findsOneWidget);
      expect(find.text('ACE_RUNNER'), findsOneWidget);
      expect(find.text('GRID_PHANTOM'), findsOneWidget);
    });

    testWidgets('ProfileSettingsList renders tactical haptics and no voice coach controls', (tester) async {
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

      // Tactical haptics & battery saver should be present
      expect(find.text('Tactical Haptics'), findsOneWidget);
      expect(find.text('Tactical Haptic Bursts'), findsOneWidget);
      expect(find.text('Endurance Battery Saver'), findsOneWidget);

      // Tap haptic switch
      final switchTiles = find.byType(Switch);
      expect(switchTiles, findsNWidgets(2));

      await tester.tap(switchTiles.first);
      await tester.pumpAndSettle();
      expect(appPrefs.isHapticsEnabled, !initialHaptics);

      // Restore
      await appPrefs.toggleHaptics(initialHaptics);
    });

    testWidgets('ProfilePage switches tabs between Athlete Profile and Faction Turf War', (tester) async {
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
      expect(find.text('ATHLETE'), findsOneWidget);
      expect(find.text('TURF WAR'), findsOneWidget);
      expect(find.text('LEAGUE'), findsOneWidget);
      expect(find.text('SQUAD'), findsOneWidget);

      // In athlete tab, Hero and Settings are visible
      expect(find.text('KAI_VALKYRIE'), findsOneWidget);
      expect(find.text('SETTINGS & PLATFORM'), findsOneWidget);

      // Tap Faction Turf War tab
      await tester.tap(find.text('TURF WAR'));
      await tester.pumpAndSettle();

      // In Turf War tab, Dominance Meter is visible
      expect(find.text('TURF WAR DOMINANCE'), findsOneWidget);
      expect(find.text('CONQUEROR RANKINGS'), findsOneWidget);

      // Tap League tab
      await tester.tap(find.text('LEAGUE'));
      await tester.pumpAndSettle();

      // Tap back to Athlete Profile
      await tester.tap(find.text('ATHLETE'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS & PLATFORM'), findsOneWidget);
    });
  });
}
