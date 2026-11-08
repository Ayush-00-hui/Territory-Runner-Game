import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:territory_runner/features/profile/widgets/season_crew_view.dart';
import 'package:territory_runner/models/crew.dart';
import 'package:territory_runner/models/season.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/crew_season_service.dart';
import 'package:territory_runner/ui/ui.dart';

class MockApiClient extends Fake implements ApiClient {
  CurrentSeasonData? mockSeason;
  MyCrewData? mockCrew;
  bool shouldThrow = false;
  String? createdCrewName;
  String? joinedCode;
  String? goalTypeSet;
  double? goalTargetSet;

  @override
  Future<CurrentSeasonData?> getCurrentSeason() async {
    if (shouldThrow) throw Exception('Network unreachable');
    return mockSeason;
  }

  @override
  Future<MyCrewData?> getMyCrew() async {
    if (shouldThrow) throw Exception('Network unreachable');
    return mockCrew;
  }

  @override
  Future<Crew?> createCrew(String name) async {
    createdCrewName = name;
    final crew = Crew(
      id: 'crw_new',
      name: name,
      joinCode: 'CRW-NEW1',
      creatorId: 'u1',
      createdAt: DateTime.now().toUtc(),
    );
    mockCrew = MyCrewData(
      crew: crew,
      role: 'leader',
      members: [
        CrewMember(
          crewId: 'crw_new',
          userId: 'u1',
          username: 'Me',
          role: 'leader',
          joinedAt: DateTime.now().toUtc(),
          weeklyDistanceM: 0,
          weeklyAreaSqm: 0,
        ),
      ],
      activeGoal: null,
    );
    return crew;
  }

  @override
  Future<Crew?> joinCrew(String joinCode) async {
    joinedCode = joinCode;
    final crew = Crew(
      id: 'crw_joined',
      name: 'Joined Crew',
      joinCode: joinCode,
      creatorId: 'u2',
      createdAt: DateTime.now().toUtc(),
    );
    mockCrew = MyCrewData(
      crew: crew,
      role: 'member',
      members: [
        CrewMember(
          crewId: 'crw_joined',
          userId: 'u2',
          username: 'Leader',
          role: 'leader',
          joinedAt: DateTime.now().toUtc(),
          weeklyDistanceM: 5000,
          weeklyAreaSqm: 2000,
        ),
        CrewMember(
          crewId: 'crw_joined',
          userId: 'u1',
          username: 'Me',
          role: 'member',
          joinedAt: DateTime.now().toUtc(),
          weeklyDistanceM: 0,
          weeklyAreaSqm: 0,
        ),
      ],
      activeGoal: null,
    );
    return crew;
  }

  @override
  Future<CrewGoal?> setCrewGoal(String goalType, double targetValue) async {
    goalTypeSet = goalType;
    goalTargetSet = targetValue;
    final goal = CrewGoal(
      id: 'g_new',
      crewId: 'crw_alpha',
      goalType: goalType,
      targetValue: targetValue,
      currentValue: 15000,
      weekStart: DateTime.now().toUtc(),
      progressPercent: (15000 / targetValue) * 100,
      createdBy: 'u1',
      createdAt: DateTime.now().toUtc(),
    );
    if (mockCrew != null) {
      mockCrew = MyCrewData(
        crew: mockCrew!.crew,
        role: mockCrew!.role,
        members: mockCrew!.members,
        activeGoal: goal,
      );
    }
    return goal;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Season & Crew Models Serialization', () {
    test('Season and CurrentSeasonData round-trip serialization', () {
      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);
      final ends = DateTime.utc(2026, 12, 1, 0, 0, 0);

      final season = Season(
        id: 'season_2026_11',
        name: 'November 2026 Season',
        startsAt: now,
        endsAt: ends,
        createdAt: now,
      );

      final userStanding = SeasonUserStanding(
        seasonId: 'season_2026_11',
        userId: 'usr_test_1',
        username: 'PacerLead',
        faction: 'Solaris Nomads',
        seasonRank: 3,
        totalAreaSqm: 45000.0,
        totalDistanceM: 32000.0,
        xp: 1500,
        updatedAt: now,
      );

      final factionStanding = SeasonFactionStanding(
        faction: 'Solaris Nomads',
        totalAreaSqm: 120000.0,
        totalDistanceM: 80000.0,
        runnerCount: 5,
      );

      final currentData = CurrentSeasonData(
        season: season,
        timeRemainingSeconds: 150000,
        userStanding: userStanding,
        factionStandings: [factionStanding],
      );

      final json = currentData.toJson();
      final reconstructed = CurrentSeasonData.fromJson(json);

      expect(reconstructed.season.id, equals('season_2026_11'));
      expect(reconstructed.season.name, equals('November 2026 Season'));
      expect(reconstructed.timeRemainingSeconds, equals(150000));
      expect(reconstructed.userStanding?.userId, equals('usr_test_1'));
      expect(reconstructed.userStanding?.seasonRank, equals(3));
      expect(reconstructed.factionStandings.length, equals(1));
      expect(
        reconstructed.factionStandings.first.faction,
        equals('Solaris Nomads'),
      );
    });

    test('Crew and MyCrewData round-trip serialization', () {
      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);

      final crew = Crew(
        id: 'crw_12345',
        name: 'Iron Paces',
        joinCode: 'CRW-PACE',
        creatorId: 'usr_leader',
        createdAt: now,
      );

      final memberLeader = CrewMember(
        crewId: 'crw_12345',
        userId: 'usr_leader',
        username: 'LeadRunner',
        role: 'leader',
        joinedAt: now,
        weeklyDistanceM: 25000.0,
        weeklyAreaSqm: 15000.0,
      );

      final goal = CrewGoal(
        id: 'goal_w1',
        crewId: 'crw_12345',
        goalType: 'distance',
        targetValue: 100000.0,
        currentValue: 25000.0,
        weekStart: now,
        progressPercent: 25.0,
        createdBy: 'usr_leader',
        createdAt: now,
      );

      final crewData = MyCrewData(
        crew: crew,
        role: 'leader',
        members: [memberLeader],
        activeGoal: goal,
      );

      final json = crewData.toJson();
      final reconstructed = MyCrewData.fromJson(json);

      expect(reconstructed.hasCrew, isTrue);
      expect(reconstructed.isLeader, isTrue);
      expect(reconstructed.crew?.name, equals('Iron Paces'));
      expect(reconstructed.crew?.joinCode, equals('CRW-PACE'));
      expect(reconstructed.members.length, equals(1));
      expect(reconstructed.members.first.isLeader, isTrue);
      expect(reconstructed.activeGoal?.progressPercent, equals(25.0));
    });
  });

  group('CrewSeasonService Offline-First Behavior', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Caches season and crew data and recovers offline', () async {
      final mockApi = MockApiClient();
      final service = CrewSeasonService(apiClient: mockApi);

      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);
      mockApi.mockSeason = CurrentSeasonData(
        season: Season(
          id: 'season_1',
          name: 'November 2026 Season',
          startsAt: now,
          endsAt: now.add(const Duration(days: 30)),
          createdAt: now,
        ),
        timeRemainingSeconds: 86400,
        userStanding: null,
        factionStandings: const [],
      );

      mockApi.mockCrew = MyCrewData(
        crew: Crew(
          id: 'crw_1',
          name: 'Frontrunners',
          joinCode: 'CRW-RUNS',
          creatorId: 'u1',
          createdAt: now,
        ),
        role: 'leader',
        members: [
          CrewMember(
            crewId: 'crw_1',
            userId: 'u1',
            username: 'U1',
            role: 'leader',
            joinedAt: now,
            weeklyDistanceM: 10000.0,
            weeklyAreaSqm: 5000.0,
          ),
        ],
        activeGoal: null,
      );

      // 1. Initial refresh online
      await service.refresh();
      expect(service.isOffline.value, isFalse);
      expect(
        service.currentSeason.value?.season.name,
        equals('November 2026 Season'),
      );
      expect(service.currentCrew.value?.crew?.name, equals('Frontrunners'));

      // 2. Simulate complete network offline
      mockApi.shouldThrow = true;
      await service.refresh();

      // State must mark offline but preserve cached data!
      expect(service.isOffline.value, isTrue);
      expect(
        service.currentSeason.value?.season.name,
        equals('November 2026 Season'),
      );
      expect(service.currentCrew.value?.crew?.name, equals('Frontrunners'));

      // 3. Clear cache and reload
      await service.clearLocalCache();
      expect(service.currentSeason.value, isNull);
      expect(service.currentCrew.value, isNull);
    });
  });

  group('SeasonCrewView Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Renders empty crew state when user has no crew', (
      tester,
    ) async {
      final mockApi = MockApiClient();
      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);
      mockApi.mockSeason = CurrentSeasonData(
        season: Season(
          id: 'season_1',
          name: 'November 2026 Season',
          startsAt: now,
          endsAt: now.add(const Duration(days: 10)),
          createdAt: now,
        ),
        timeRemainingSeconds: 864000,
        userStanding: null,
        factionStandings: const [],
      );
      mockApi.mockCrew = const MyCrewData(crew: null);

      final service = CrewSeasonService(apiClient: mockApi);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(body: SeasonCrewView(service: service)),
        ),
      );

      await tester.pumpAndSettle();

      // Verify season card
      expect(find.text('ACTIVE SEASON'), findsOneWidget);
      expect(find.text('November 2026 Season'), findsOneWidget);

      // Verify calm empty crew state
      expect(find.text('Crew Weekly Goals'), findsOneWidget);
      expect(find.text('Create Crew'), findsOneWidget);
      expect(find.text('Join with Code'), findsOneWidget);
    });

    testWidgets('Renders active crew with weekly goal and members', (
      tester,
    ) async {
      final mockApi = MockApiClient();
      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);
      mockApi.mockSeason = CurrentSeasonData(
        season: Season(
          id: 'season_1',
          name: 'November 2026 Season',
          startsAt: now,
          endsAt: now.add(const Duration(days: 10)),
          createdAt: now,
        ),
        timeRemainingSeconds: 864000,
        userStanding: SeasonUserStanding(
          seasonId: 'season_1',
          userId: 'u1',
          faction: 'Solaris Nomads',
          seasonRank: 2,
          totalAreaSqm: 35000,
          totalDistanceM: 20000,
          xp: 800,
          updatedAt: now,
        ),
        factionStandings: const [],
      );

      mockApi.mockCrew = MyCrewData(
        crew: Crew(
          id: 'crw_alpha',
          name: 'Alpha Runners',
          joinCode: 'CRW-ALPH',
          creatorId: 'u1',
          createdAt: now,
        ),
        role: 'leader',
        members: [
          CrewMember(
            crewId: 'crw_alpha',
            userId: 'u1',
            username: 'SpeedMaster',
            role: 'leader',
            joinedAt: now,
            weeklyDistanceM: 20000.0,
            weeklyAreaSqm: 12000.0,
          ),
        ],
        activeGoal: CrewGoal(
          id: 'g1',
          crewId: 'crw_alpha',
          goalType: 'distance',
          targetValue: 50000.0,
          currentValue: 20000.0,
          weekStart: now,
          progressPercent: 40.0,
          createdBy: 'u1',
          createdAt: now,
        ),
      );

      final service = CrewSeasonService(apiClient: mockApi);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(body: SeasonCrewView(service: service)),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Season standing
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('35000 m²'), findsOneWidget);
      expect(find.text('20.0 km'), findsOneWidget);

      // Verify Crew info
      expect(find.text('Alpha Runners'), findsOneWidget);
      expect(find.text('CRW-ALPH'), findsOneWidget);
      expect(find.text('WEEKLY CREW GOAL'), findsOneWidget);
      expect(find.text('20.0 / 50.0 km'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      // Verify Members
      expect(find.text('Members (1/10)'), findsOneWidget);
      expect(find.text('SpeedMaster'), findsOneWidget);
      expect(find.text('Leader'), findsOneWidget);
      expect(find.text('20.0 km • 12000 m²'), findsOneWidget);
    });

    testWidgets('Displays offline banner when service is offline', (
      tester,
    ) async {
      final mockApi = MockApiClient();
      mockApi.shouldThrow = true;

      final service = CrewSeasonService(apiClient: mockApi);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(body: SeasonCrewView(service: service)),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Offline • Showing cached season and crew standings'),
        findsOneWidget,
      );
    });

    testWidgets('Create crew dialog validation and submission', (tester) async {
      final mockApi = MockApiClient();
      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);
      mockApi.mockSeason = CurrentSeasonData(
        season: Season(
          id: 's1',
          name: 'November Season',
          startsAt: now,
          endsAt: now.add(const Duration(days: 10)),
          createdAt: now,
        ),
        timeRemainingSeconds: 50000,
        userStanding: null,
        factionStandings: const [],
      );
      mockApi.mockCrew = const MyCrewData(crew: null);

      final service = CrewSeasonService(apiClient: mockApi);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(body: SeasonCrewView(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Create Crew"
      await tester.tap(find.text('Create Crew'));
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Create Runner Crew'), findsOneWidget);

      // Enter invalid name (too short)
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();
      expect(
        find.text('Team name must be at least 3 characters long'),
        findsOneWidget,
      );

      // Enter valid name
      await tester.enterText(find.byType(TextField), 'Night Owls');
      await tester.pumpAndSettle();

      // Tap Create
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockApi.createdCrewName, equals('Night Owls'));
      // Active crew card now visible
      expect(find.text('Night Owls'), findsOneWidget);
    });

    testWidgets('Join crew dialog submission', (tester) async {
      final mockApi = MockApiClient();
      mockApi.mockSeason = CurrentSeasonData(
        season: Season(
          id: 's1',
          name: 'November Season',
          startsAt: DateTime.now().toUtc(),
          endsAt: DateTime.now().toUtc().add(const Duration(days: 10)),
          createdAt: DateTime.now().toUtc(),
        ),
        timeRemainingSeconds: 50000,
        userStanding: null,
        factionStandings: const [],
      );
      mockApi.mockCrew = const MyCrewData(crew: null);

      final service = CrewSeasonService(apiClient: mockApi);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(body: SeasonCrewView(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Join with Code"
      await tester.tap(find.text('Join with Code'));
      await tester.pumpAndSettle();

      expect(find.text('Join with Code'), findsWidgets);

      // Enter code
      await tester.enterText(find.byType(TextField), 'crw-test');
      await tester.pumpAndSettle();

      // Tap Join Crew
      await tester.tap(find.text('Join Crew'));
      await tester.pumpAndSettle();

      expect(mockApi.joinedCode, equals('CRW-TEST'));
      expect(find.text('Joined Crew'), findsOneWidget);
    });

    testWidgets('Text scaling 1.3 does not overflow SeasonCrewView', (
      tester,
    ) async {
      final mockApi = MockApiClient();
      final now = DateTime.utc(2026, 11, 1, 0, 0, 0);
      mockApi.mockSeason = CurrentSeasonData(
        season: Season(
          id: 's1',
          name: 'November 2026 Season Championship',
          startsAt: now,
          endsAt: now.add(const Duration(days: 20)),
          createdAt: now,
        ),
        timeRemainingSeconds: 150000,
        userStanding: SeasonUserStanding(
          seasonId: 's1',
          userId: 'u1',
          faction: 'Solaris Nomads',
          seasonRank: 1,
          totalAreaSqm: 120000,
          totalDistanceM: 85000,
          xp: 4500,
          updatedAt: now,
        ),
        factionStandings: [
          const SeasonFactionStanding(
            faction: 'Solaris Nomads',
            totalAreaSqm: 500000,
            totalDistanceM: 300000,
            runnerCount: 14,
          ),
        ],
      );

      mockApi.mockCrew = MyCrewData(
        crew: Crew(
          id: 'c1',
          name: 'Apex Predators Fleet',
          joinCode: 'CRW-APEX',
          creatorId: 'u1',
          createdAt: now,
        ),
        role: 'leader',
        members: [
          CrewMember(
            crewId: 'c1',
            userId: 'u1',
            username: 'AlphaOne',
            role: 'leader',
            joinedAt: now,
            weeklyDistanceM: 42000,
            weeklyAreaSqm: 25000,
          ),
        ],
        activeGoal: CrewGoal(
          id: 'g1',
          crewId: 'c1',
          goalType: 'distance',
          targetValue: 100000,
          currentValue: 42000,
          weekStart: now,
          progressPercent: 42.0,
          createdBy: 'u1',
          createdAt: now,
        ),
      );

      final service = CrewSeasonService(apiClient: mockApi);

      // Small screen with textScaleFactor 1.3
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(body: SeasonCrewView(service: service)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No overflow errors
      expect(tester.takeException(), isNull);
      expect(find.text('ACTIVE SEASON'), findsOneWidget);
      expect(find.text('Apex Predators Fleet'), findsOneWidget);
    });
  });
}
