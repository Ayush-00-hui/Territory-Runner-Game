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

    test('Standard reference 70kg runner burns ~72.5 kcal/km (ACSM 1.036 factor)', () {
      // 5.0 km * 70.0 kg * 1.036 = 362.6 -> 363 kcal
      final calories = AppPreferences().estimateCalories(distanceKm: 5.0);
      expect(calories, 363);
    });

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

    test('Walking and cycling activity types use appropriate metabolic factors', () {
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
    });

    test('formatCalories appends (est.) label and tilde prefix', () {
      expect(AppPreferences().formatCalories(363), '~363 kcal (est.)');
      expect(
        AppPreferences().formatCalories(363, withPrefixPlus: true),
        '+~363 kcal (est.)',
      );
    });
  });

  group('HUD and Summary Calorie UI Rendering', () {
    testWidgets('RunHudMetricsCard displays calorie estimate with (est.) label', (
      tester,
    ) async {
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

      // 5.0 km * 70 kg * 1.036 = 363 kcal
      expect(find.text('~363 kcal (est.)'), findsOneWidget);
    });

    testWidgets('SummaryRouteReplay displays calorie estimate with (est.) label', (
      tester,
    ) async {
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

      expect(
        find.textContaining('~363 kcal (est.)'),
        findsOneWidget,
      );
    });

    testWidgets('Settings list allows configuring and resetting optional body weight', (
      tester,
    ) async {
      final prefs = AppPreferences();
      prefs.setMockBodyWeight(null);

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

      final weightTile = find.text('Body weight (optional)');
      expect(weightTile, findsOneWidget);
      await tester.ensureVisible(weightTile);
      await tester.pumpAndSettle();

      expect(
        find.text('Default: 70.0 kg (not set) • Tap to customize'),
        findsOneWidget,
      );

      // Open dialog
      await tester.tap(weightTile);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '68.5');
      await tester.pumpAndSettle();

      final saveButton = find.text('Save weight');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(prefs.bodyWeightKg, 68.5);
      expect(
        find.text('68.5 kg • Used for calorie estimates'),
        findsOneWidget,
      );

      // Re-open dialog and reset
      await tester.tap(weightTile);
      await tester.pumpAndSettle();

      final resetButton = find.text('Reset to standard default (70 kg)');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(prefs.bodyWeightKg, isNull);
      expect(
        find.text('Default: 70.0 kg (not set) • Tap to customize'),
        findsOneWidget,
      );
    });
  });
}
