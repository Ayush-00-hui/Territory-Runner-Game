import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/map/widgets/run_hud_metrics_card.dart';
import 'package:territory_runner/features/map/widgets/summary_route_replay.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppPreferences().setMockBodyWeight(null);
  });

  group('AppPreferences Calorie Estimation (Documented ACSM / Margaria)', () {
    test('Zero distance produces 0 kcal', () {
      final calories = AppPreferences().estimateCalories(distanceKm: 0.0);
      expect(calories, 0);
    });

    test(
      'Standard reference 70kg runner burns ~72.5 kcal/km (ACSM 1.036 factor)',
      () {
        // 5.0 km * 70.0 kg * 1.036 = 362.6 -> 363 kcal
        final calories = AppPreferences().estimateCalories(distanceKm: 5.0);
        expect(calories, 363);
      },
    );

    test('Custom weight adjusts calorie calculation proportionally', () {
      // 5.0 km * 60.0 kg * 1.036 = 310.8 -> 311 kcal
      final lightRunner = AppPreferences().estimateCalories(
        distanceKm: 5.0,
        customWeightKg: 60.0,
      );
      expect(lightRunner, 311);

      // 5.0 km * 85.0 kg * 1.036 = 440.3 -> 440 kcal
      final heavyRunner = AppPreferences().estimateCalories(
        distanceKm: 5.0,
        customWeightKg: 85.0,
      );
      expect(heavyRunner, 440);
    });

    test('Saved body weight preference applies automatically when set', () {
      AppPreferences().setMockBodyWeight(80.0);
      // 10.0 km * 80.0 kg * 1.036 = 828.8 -> 829 kcal
      final calories = AppPreferences().estimateCalories(distanceKm: 10.0);
      expect(calories, 829);

      // Resetting weight falls back to 70.0 kg standard default
      AppPreferences().setMockBodyWeight(null);
      // 10.0 km * 70.0 kg * 1.036 = 725.2 -> 725 kcal
      final defaultCal = AppPreferences().estimateCalories(distanceKm: 10.0);
      expect(defaultCal, 725);
    });

    test(
      'Walking and cycling activity types use appropriate metabolic factors',
      () {
        // Walking: 5.0 km * 70.0 kg * 0.73 = 255.5 -> 256 kcal
        final walkCalories = AppPreferences().estimateCalories(
          distanceKm: 5.0,
          activityType: 'walking',
        );
        expect(walkCalories, 256);

        // Cycling: 20.0 km * 70.0 kg * 0.40 = 560 kcal
        final cycleCalories = AppPreferences().estimateCalories(
          distanceKm: 20.0,
          activityType: 'cycling',
        );
        expect(cycleCalories, 560);
      },
    );

    test('formatCalories appends (est.) label and tilde prefix', () {
      expect(AppPreferences().formatCalories(363), '~363 kcal (est.)');
      expect(
        AppPreferences().formatCalories(363, withPrefixPlus: true),
        '+~363 kcal (est.)',
      );
    });
  });

  group('HUD and Summary Calorie UI Rendering', () {
    testWidgets(
      'RunHudMetricsCard displays calorie estimate with (est.) label',
      (tester) async {
        AppPreferences().setMockBodyWeight(null);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RunHudMetricsCard(
                isRunActive: true,
                isAutoPaused: false,
                distanceKm: 5.0,
                elapsedSeconds: 1500,
                movingSeconds: 1450,
                splitPace: "5'00\"",
                currentSpeedKmh: 12.0,
                satelliteAccuracyMeters: 4.5,
                stepCount: 5200,
                territoriesClaimed: 2,
                onToggleExpanded: () {},
              ),
            ),
          ),
        );

        // With 1450s duration and 12 km/h speed, ACSM physiological model computes:
        // VO2 = 0.2 * 200 + 3.5 = 43.5 mL/kg/min => 14.80 kcal/min * 24.167 min = 358 kcal
        expect(find.text('~358 kcal (est.)'), findsOneWidget);
      },
    );

    testWidgets(
      'SummaryRouteReplay displays calorie estimate with (est.) label',
      (tester) async {
        final animationController = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(seconds: 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SummaryRouteReplay(
                routePoints: const [LatLng(37.7749, -122.4194)],
                effectiveArea: 15000.0,
                calories: 363,
                replayController: animationController,
              ),
            ),
          ),
        );

        expect(find.textContaining('~363 kcal (est.)'), findsOneWidget);
      },
    );

    testWidgets(
      'Settings list allows configuring and resetting optional body details',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = AppPreferences();
        await prefs.clearBodyProfile();

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

        final detailsTile = find.text('Body details');
        expect(detailsTile, findsOneWidget);
        await tester.ensureVisible(detailsTile);
        await tester.pumpAndSettle();

        expect(
          find.text('Default: 70 kg, 170 cm (not set) • Tap to customize'),
          findsOneWidget,
        );

        // Open sheet
        await tester.tap(detailsTile);
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsWidgets);
        await tester.enterText(find.byType(TextField).at(0), '68.5');
        await tester.enterText(find.byType(TextField).at(1), '175');
        await tester.pumpAndSettle();

        final saveButton = find.text('Save details');
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(prefs.bodyWeightKg, 68.5);
        expect(prefs.bodyProfile, isNotNull);
        expect(prefs.bodyProfile!.weightKg, 68.5);

        // Re-open sheet and remove
        await tester.tap(detailsTile);
        await tester.pumpAndSettle();

        final removeButton = find.text('Remove my body details');
        expect(removeButton, findsOneWidget);
        await tester.ensureVisible(removeButton);
        await tester.pumpAndSettle();
        await tester.tap(removeButton);
        await tester.pumpAndSettle();

        expect(prefs.bodyProfile, isNull);
        expect(
          find.text('Default: 70 kg, 170 cm (not set) • Tap to customize'),
          findsOneWidget,
        );
      },
    );
  });
}
