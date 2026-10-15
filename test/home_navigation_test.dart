import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/home/widgets/home_header.dart';
import 'package:territory_runner/features/home/widgets/quick_launch_hero.dart';
import 'package:territory_runner/features/home/widgets/weekly_summary_card.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  group('Phase 1 Home & Navigation Widgets', () {
    testWidgets('HomeHeader renders callsign, level, and streak', (tester) async {
      final profile = RunnerProfile(
        id: 'test_athlete',
        username: 'VortexRunner',
        totalDistanceKm: 28.5,
        xp: 1200,
        level: 5,
        badges: ['Pioneer'],
        totalHexesClaimed: 14,
        currentStreak: 7,
        faction: 'Cyber Vanguard',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeader(profile: profile),
          ),
        ),
      );

      expect(find.text('VORTEXRUNNER'), findsOneWidget);
      expect(find.text('LVL 5'), findsOneWidget);
      expect(find.text('CYBER VANGUARD'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('WeeklySummaryCard renders distance, territory, and runs', (tester) async {
      final profile = RunnerProfile(
        id: 'test_athlete',
        username: 'ApexStrider',
        totalDistanceKm: 20.0,
        xp: 500,
        level: 3,
        badges: [],
        totalHexesClaimed: 4,
        currentStreak: 3,
      );

      final territories = [
        Territory(
          id: 'poly_1',
          ownerId: 'test_athlete',
          polygon: [],
          areaSqMeters: 15400,
          capturedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklySummaryCard(
              profile: profile,
              territories: territories,
            ),
          ),
        ),
      );

      expect(find.text('WEEKLY PERFORMANCE'), findsOneWidget);
      expect(find.text('LAST 7 DAYS'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('TERRITORY'), findsOneWidget);
      expect(find.text('RUNS'), findsOneWidget);
    });

    testWidgets('QuickLaunchHero triggers onStartRun callback when tapped', (tester) async {
      bool runStarted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickLaunchHero(
              onStartRun: () => runStarted = true,
            ),
          ),
        ),
      );

      expect(find.text('START CONQUEST RUN'), findsOneWidget);
      await tester.tap(find.text('START CONQUEST RUN'));
      await tester.pump();
      expect(runStarted, isTrue);
    });
  });
}
