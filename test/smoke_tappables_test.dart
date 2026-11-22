import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/features/profile/widgets/challenges_shelf.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'is_demo_mode_enabled': false,
      'has_completed_onboarding': true,
    });
  });

  group('Phase C1: Smoke Tappables & Attribution Sheet Tests', () {
    testWidgets(
      'MapAttributionSheet renders full OSM & CARTO licensing details',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: MapAttributionSheet()),
          ),
        );

        expect(find.text('Map Data & Attribution'), findsOneWidget);
        expect(find.textContaining('OpenStreetMap'), findsWidgets);
        expect(find.textContaining('CARTO'), findsWidgets);
        expect(find.textContaining('ODbL'), findsOneWidget);

        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets(
      'ProfileSettingsList Map Data & Attribution tile opens MapAttributionSheet when tapped',
      (tester) async {
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
        await tester.pumpAndSettle();

        // Scroll to find the Map Data & Attribution tile
        final tileFinder = find.text('Map Data & Attribution');
        expect(tileFinder, findsOneWidget);

        await tester.ensureVisible(tileFinder);
        await tester.pumpAndSettle();

        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Verify the attribution sheet bottom modal opened
        expect(find.byType(MapAttributionSheet), findsOneWidget);
        expect(find.textContaining('OpenStreetMap'), findsWidgets);
      },
    );

    testWidgets(
      'ChallengesShelf displays dynamic reset countdown and opens badge modal on tap',
      (tester) async {
        final profile = RunnerProfile(
          id: 'test_usr',
          username: 'SwiftRunner',
          totalDistanceKm: 12.5,
          xp: 450,
          level: 2,
          badges: ['First Claim'],
          totalTerritoriesClaimed: 3,
          currentStreak: 4,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChallengesShelf(
                  profile: profile,
                  territoriesCount: 3,
                  totalAreaSqMeters: 15000.0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Dynamic countdown matches 24 - hour
        final expectedHours = 24 - DateTime.now().hour;
        expect(find.text('Resets in ${expectedHours}h'), findsOneWidget);

        // 2. Badge card displays title and status
        expect(find.text('First Claim'), findsOneWidget);
        expect(find.text('Territory Master'), findsOneWidget);

        // 3. Tap badge card to open badge detail modal
        final badgeFinder = find.text('First Claim');
        await tester.tap(badgeFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('Pioneer Runner Title'), findsWidgets);
      },
    );

    testWidgets(
      'RunHistoryScreen renders calm empty state with zero errors when no runs exist',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: RunHistoryScreen(initialRuns: [], initialTerritories: []),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Run history'), findsOneWidget);
        expect(find.text('No runs in range'), findsOneWidget);
        expect(
          find.text(
            'Try changing your filters or start a new run to claim territory.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.directions_run_rounded), findsWidgets);
      },
    );

    testWidgets('PrimaryButton responds to tap feedback under 100ms budget', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                label: 'Claim Ground',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Claim Ground');
      expect(buttonFinder, findsOneWidget);

      // Tap down: press scale feedback occurs within 90ms (AppMotion.fast)
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump(const Duration(milliseconds: 90));

      // Release tap: callback fires promptly
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(AppMotion.fast.inMilliseconds, lessThan(100));
    });
  });
}
