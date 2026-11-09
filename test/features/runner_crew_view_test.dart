import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:territory_runner/features/profile/widgets/runner_crew_view.dart';
import 'package:territory_runner/models/crew.dart';
import 'package:territory_runner/models/season.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/crew_season_service.dart';
import 'package:territory_runner/ui/ui.dart';

class _MockApiForCrew extends Fake implements ApiClient {
  MyCrewData? mockCrew;
  String? createdCrewName;
  String? joinedCode;

  @override
  Future<CurrentSeasonData?> getCurrentSeason() async => null;

  @override
  Future<MyCrewData?> getMyCrew() async => mockCrew;

  @override
  Future<Crew?> createCrew(String name) async {
    createdCrewName = name;
    final crew = Crew(
      id: 'crw_101',
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
          crewId: 'crw_101',
          userId: 'u1',
          username: 'ApexRunner',
          role: 'leader',
          joinedAt: DateTime.now().toUtc(),
          weeklyDistanceM: 12000,
          weeklyAreaSqm: 5000,
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
      name: 'Cyber Striders',
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
          username: 'CaptainPacer',
          role: 'leader',
          joinedAt: DateTime.now().toUtc(),
          weeklyDistanceM: 15000,
          weeklyAreaSqm: 8000,
        ),
      ],
      activeGoal: null,
    );
    return crew;
  }

  @override
  Future<CrewGoal?> setCrewGoal(String goalType, double targetValue) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RunnerCrewView Widget Tests', () {
    testWidgets('Renders empty state with Create Team and Join Team buttons', (
      tester,
    ) async {
      final mockApi = _MockApiForCrew();
      mockApi.mockCrew = const MyCrewData(crew: null);
      final service = CrewSeasonService(apiClient: mockApi);
      service.currentCrew.value = mockApi.mockCrew;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunnerCrewView(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Runner Teams & Crews'), findsOneWidget);
      expect(find.text('Create Team'), findsOneWidget);
      expect(find.text('Join Team with Code'), findsOneWidget);
    });

    testWidgets('Opens Create Team dialog, validates input, and submits', (
      tester,
    ) async {
      final mockApi = _MockApiForCrew();
      mockApi.mockCrew = const MyCrewData(crew: null);
      final service = CrewSeasonService(apiClient: mockApi);
      service.currentCrew.value = mockApi.mockCrew;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.bgDeep,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunnerCrewView(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Create Team
      await tester.tap(find.text('Create Team'));
      await tester.pumpAndSettle();

      expect(find.text('Create Runner Team'), findsOneWidget);

      // Short invalid name
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();
      expect(
        find.text('Team name must be at least 3 characters long'),
        findsOneWidget,
      );

      // Valid name
      await tester.enterText(find.byType(TextField), 'Speed Demons');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Team').last);
      await tester.pumpAndSettle();

      expect(mockApi.createdCrewName, equals('Speed Demons'));
      expect(find.text('Speed Demons'), findsOneWidget);
      expect(find.text('Leader'), findsOneWidget);
    });

    testWidgets(
      'Renders active team card with join code and member contributions',
      (tester) async {
        final mockApi = _MockApiForCrew();
        final crew = Crew(
          id: 'crw_active',
          name: 'Storm Runners',
          joinCode: 'CRW-STRM',
          creatorId: 'u1',
          createdAt: DateTime.now().toUtc(),
        );
        mockApi.mockCrew = MyCrewData(
          crew: crew,
          role: 'leader',
          members: [
            CrewMember(
              crewId: 'crw_active',
              userId: 'u1',
              username: 'SprintMaster',
              role: 'leader',
              joinedAt: DateTime.now().toUtc(),
              weeklyDistanceM: 21000,
              weeklyAreaSqm: 14000,
            ),
          ],
          activeGoal: CrewGoal(
            id: 'goal_1',
            crewId: 'crw_active',
            goalType: 'distance',
            targetValue: 50000,
            currentValue: 21000,
            progressPercent: 42.0,
            createdBy: 'u1',
            weekStart: DateTime.now().toUtc(),
            createdAt: DateTime.now().toUtc(),
          ),
        );
        final service = CrewSeasonService(apiClient: mockApi);
        service.currentCrew.value = mockApi.mockCrew;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: AppColors.bgDeep,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RunnerCrewView(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('YOUR TEAM'), findsOneWidget);
        expect(find.text('Storm Runners'), findsOneWidget);
        expect(find.text('CRW-STRM'), findsOneWidget);
        expect(find.text('42%'), findsOneWidget);
        expect(find.text('SprintMaster'), findsOneWidget);
        expect(find.text('Members (1/10)'), findsOneWidget);
      },
    );
  });
}
