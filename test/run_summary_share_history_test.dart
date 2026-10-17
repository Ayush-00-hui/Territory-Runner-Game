import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/features/history/widgets/history_run_card.dart';
import 'package:territory_runner/features/history/widgets/run_share_card_modal.dart';
import 'package:territory_runner/features/map/widgets/summary_sheet.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

class FakeCoachService implements LLMCoachService {
  @override
  Future<CoachInsight> generateRunInsight({
    String? runId,
    required double distanceKm,
    required int durationSeconds,
    required int hexesClaimed,
    required RunnerProfile profile,
    String? currentPaceFormatted,
  }) async {
    return const CoachInsight(
      summary: 'Outstanding loop execution! Sector perimeter secured.',
      tip: 'Maintain cadence around 170 SPM for optimal energy expenditure.',
      moodTag: CoachMood.celebratory,
    );
  }
}

void main() {
  group('Phase 3 Run Summary, History & Share Widgets', () {
    testWidgets('SummarySheet renders victory header, stats grid, and coach card', (tester) async {
      final profile = RunnerProfile(
        id: 'test_athlete',
        username: 'ApexStrider',
        totalDistanceKm: 42.0,
        xp: 1500,
        level: 6,
        badges: ['Conqueror'],
        totalHexesClaimed: 24,
        currentStreak: 5,
        faction: 'Cyber Vanguard',
      );

      final routePoints = [
        const LatLng(37.7749, -122.4194),
        const LatLng(37.7755, -122.4194),
        const LatLng(37.7755, -122.4180),
        const LatLng(37.7749, -122.4180),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SummarySheet(
                distanceKm: 3.45,
                durationSeconds: 1120,
                territoriesClaimed: 3,
                profile: profile,
                coachService: FakeCoachService(),
                routePoints: routePoints,
                areaSqMeters: 25000.0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Run complete'), findsOneWidget);
      expect(find.text('ApexStrider • Cyber Vanguard'), findsOneWidget);
      expect(find.text('3.45 km'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('Share run'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('Outstanding loop execution'), findsOneWidget);
    });

    testWidgets('RunShareCardModal displays athletic theme options, stats and card preview', (tester) async {
      final points = [
        const LatLng(37.7749, -122.4194),
        const LatLng(37.7760, -122.4194),
        const LatLng(37.7760, -122.4175),
        const LatLng(37.7749, -122.4175),
      ];

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunShareCardModal(
                distanceKm: 5.20,
                durationSeconds: 1560,
                areaSqMeters: 45000.0,
                points: points,
                callsign: 'NeonPhantom',
                faction: 'Cyber Vanguard',
                capturedAt: DateTime(2026, 10, 15, 14, 30),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Share run'), findsOneWidget);
      expect(find.text('Athletic Dark'), findsOneWidget);
      expect(find.text('Cyber Neon'), findsOneWidget);
      expect(find.text('Stealth'), findsOneWidget);
      expect(find.text('TERRITORY RUNNER'), findsOneWidget);
      expect(find.text('Closed loop'), findsOneWidget);
      expect(find.text('NEONPHANTOM'), findsOneWidget);
      expect(find.text('5.20 KM'), findsOneWidget);

      // Switch to Cyber Neon theme
      await tester.tap(find.text('Cyber Neon'));
      await tester.pumpAndSettle();

      expect(find.text('Share card'), findsOneWidget);
    });

    testWidgets('HistoryRunCard renders conquest details and opens detail sheet', (tester) async {
      final territory = Territory(
        id: 'conquest_001',
        ownerId: 'runner_1',
        polygon: [
          const LatLng(37.7749, -122.4194),
          const LatLng(37.7759, -122.4194),
          const LatLng(37.7759, -122.4184),
        ],
        areaSqMeters: 18500.0,
        capturedAt: DateTime.now(),
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryRunCard(
              territory: territory,
              callsign: 'SpecterOne',
              faction: 'Iron Syndicate',
            ),
          ),
        ),
      );

      expect(find.text('Closed loop'), findsOneWidget);
      expect(find.textContaining('0.02 km² claimed'), findsOneWidget);

      // Tap card to open modal sheet
      await tester.tap(find.text('Closed loop'));
      await tester.pumpAndSettle();

      expect(find.text('Run dossier'), findsOneWidget);
      expect(find.text('Share run'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('RunHistoryScreen displays archive metrics and filter chips', (tester) async {
      final profile = RunnerProfile(
        id: 'test_athlete',
        username: 'ApexStrider',
        totalDistanceKm: 25.0,
        xp: 800,
        level: 4,
        badges: [],
        totalHexesClaimed: 8,
        currentStreak: 3,
        faction: 'Cyber Vanguard',
      );

      final territory = Territory(
        id: 'conquest_t1',
        ownerId: 'test_athlete',
        polygon: [
          const LatLng(37.7749, -122.4194),
          const LatLng(37.7759, -122.4194),
          const LatLng(37.7759, -122.4184),
        ],
        areaSqMeters: 12000.0,
        capturedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RunHistoryScreen(
            initialProfile: profile,
            initialTerritories: [territory],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('Total area'), findsOneWidget);
      expect(find.text('Conquests'), findsOneWidget);
      expect(find.text('All runs'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);

      // Tap filter
      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();

      expect(find.text('Closed loop'), findsOneWidget);
    });
  });
}
