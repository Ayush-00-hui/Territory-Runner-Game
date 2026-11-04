import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/run_goal.dart';
import 'package:territory_runner/services/auto_pause_engine.dart';
import 'package:territory_runner/services/tile_cache_service.dart';
import 'package:territory_runner/features/map/widgets/run_goal_sheet.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Run Goals & Telemetry Tests', () {
    test('RunGoal distance computation and formatting', () {
      const goal = RunGoal(type: GoalType.distance, targetValue: 5.0);
      expect(goal.isActive, isTrue);
      expect(goal.title, equals('5 KM TARGET'));

      // 0 km done
      expect(
        goal.computeProgress(
          currentDistanceKm: 0.0,
          currentDurationSeconds: 0,
          currentAreaSqm: 0,
        ),
        equals(0.0),
      );
      expect(
        goal.formatRemaining(
          currentDistanceKm: 0.0,
          currentDurationSeconds: 0,
          currentAreaSqm: 0,
        ),
        equals('5.00 km remaining'),
      );

      // 2.5 km done (50%)
      expect(
        goal.computeProgress(
          currentDistanceKm: 2.5,
          currentDurationSeconds: 600,
          currentAreaSqm: 0,
        ),
        equals(0.5),
      );
      expect(
        goal.formatRemaining(
          currentDistanceKm: 2.5,
          currentDurationSeconds: 600,
          currentAreaSqm: 0,
        ),
        equals('2.50 km remaining'),
      );

      // 5.0 km done (100%)
      expect(
        goal.computeProgress(
          currentDistanceKm: 5.0,
          currentDurationSeconds: 1500,
          currentAreaSqm: 0,
        ),
        equals(1.0),
      );
      expect(
        goal.formatRemaining(
          currentDistanceKm: 5.0,
          currentDurationSeconds: 1500,
          currentAreaSqm: 0,
        ),
        equals('Goal achieved!'),
      );

      // 6.0 km done (exceeded)
      expect(
        goal.computeProgress(
          currentDistanceKm: 6.0,
          currentDurationSeconds: 1800,
          currentAreaSqm: 0,
        ),
        equals(1.2),
      );
      expect(
        goal.formatRemaining(
          currentDistanceKm: 6.0,
          currentDurationSeconds: 1800,
          currentAreaSqm: 0,
        ),
        equals('Goal achieved!'),
      );
    });

    test('RunGoal duration and area computation', () {
      // 30 min duration goal (1800s)
      const durationGoal = RunGoal(
        type: GoalType.duration,
        targetValue: 1800.0,
      );
      expect(durationGoal.isActive, isTrue);
      expect(durationGoal.title, equals('30 MIN TIME TARGET'));
      expect(
        durationGoal.computeProgress(
          currentDistanceKm: 1.0,
          currentDurationSeconds: 900,
          currentAreaSqm: 0,
        ),
        equals(0.5),
      );
      expect(
        durationGoal.formatRemaining(
          currentDistanceKm: 1.0,
          currentDurationSeconds: 900,
          currentAreaSqm: 0,
        ),
        contains('15m 00s remaining'),
      );

      // 50,000 m² domain area goal
      const areaGoal = RunGoal(type: GoalType.area, targetValue: 50000.0);
      expect(areaGoal.isActive, isTrue);
      expect(areaGoal.title, equals('50K M² TURF GOAL'));
      expect(
        areaGoal.computeProgress(
          currentDistanceKm: 2.0,
          currentDurationSeconds: 600,
          currentAreaSqm: 25000.0,
        ),
        equals(0.5),
      );
      expect(
        areaGoal.formatRemaining(
          currentDistanceKm: 2.0,
          currentDurationSeconds: 600,
          currentAreaSqm: 25000.0,
        ),
        equals('25000 m² to claim'),
      );

      // Open exploration (none)
      expect(RunGoal.none.isActive, isFalse);
      expect(
        RunGoal.none.computeProgress(
          currentDistanceKm: 5.0,
          currentDurationSeconds: 1200,
          currentAreaSqm: 10000,
        ),
        equals(0.0),
      );
      expect(
        RunGoal.none.formatRemaining(
          currentDistanceKm: 5.0,
          currentDurationSeconds: 1200,
          currentAreaSqm: 10000,
        ),
        equals(''),
      );
    });

    test('AutoPauseEngine handles hysteresis correctly with 2.5 km/h threshold', () {
      final engine = AutoPauseEngine();
      expect(engine.isAutoPaused, isFalse);
      expect(engine.consecutiveStationarySeconds, equals(0));

      // Active running at 9.0 km/h: arms initial movement and remains running
      expect(engine.tick(9.0), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isFalse);
      expect(engine.hasInitialMovement, isTrue);

      // Drops below 2.5 km/h: tick 1 (count = 1)
      expect(engine.tick(2.1), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isFalse);
      expect(engine.consecutiveStationarySeconds, equals(1));

      // Drops below 2.5 km/h: tick 2 (count = 2)
      expect(engine.tick(1.8), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isFalse);
      expect(engine.consecutiveStationarySeconds, equals(2));

      // Brief speed spike back to 4.5 km/h: resets counter before 3s threshold
      expect(engine.tick(4.5), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isFalse);
      expect(engine.consecutiveStationarySeconds, equals(0));

      // Now stays stationary for 3 continuous seconds below 2.5 km/h:
      expect(engine.tick(0.5), equals(AutoPauseTransition.none));
      expect(engine.tick(0.2), equals(AutoPauseTransition.none));
      // 3rd second: triggers pause transition
      expect(engine.tick(0.0), equals(AutoPauseTransition.paused));
      expect(engine.isAutoPaused, isTrue);

      // While paused: speed of 2.7 km/h (> 2.5 ceiling but < 3.0 resume threshold) must stay paused (hysteresis)
      expect(engine.tick(2.7), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isTrue);

      // Speed reaches 3.0 km/h (>= 3.0 km/h floor): triggers resume transition
      expect(engine.tick(3.0), equals(AutoPauseTransition.resumed));
      expect(engine.isAutoPaused, isFalse);
      expect(engine.consecutiveStationarySeconds, equals(0));

      // Reset
      engine.reset();
      expect(engine.isAutoPaused, isFalse);
      expect(engine.consecutiveStationarySeconds, equals(0));
      expect(engine.hasInitialMovement, isFalse);
    });

    test('AutoPauseEngine suppresses auto-pause at run start until initial movement is established', () {
      final engine = AutoPauseEngine();
      expect(engine.hasInitialMovement, isFalse);
      expect(engine.isAutoPaused, isFalse);

      // At start line, runner is stationary (0.0 km/h or < 2.5 km/h): must NEVER pause
      for (int i = 0; i < 15; i++) {
        expect(engine.tick(0.0), equals(AutoPauseTransition.none));
        expect(engine.isAutoPaused, isFalse);
        expect(engine.consecutiveStationarySeconds, equals(0));
      }

      // Athlete starts moving and crosses 2.5 km/h: arms initial movement
      expect(engine.tick(2.8), equals(AutoPauseTransition.none));
      expect(engine.hasInitialMovement, isTrue);

      // Now if athlete stops mid-run below 2.5 km/h for 3 seconds: pauses as expected
      expect(engine.tick(1.5), equals(AutoPauseTransition.none));
      expect(engine.tick(1.0), equals(AutoPauseTransition.none));
      expect(engine.tick(0.0), equals(AutoPauseTransition.paused));
      expect(engine.isAutoPaused, isTrue);

      // Force resume on coordinate displacement unpauses immediately
      engine.forceResume();
      expect(engine.isAutoPaused, isFalse);
      expect(engine.hasInitialMovement, isTrue);
    });

    test('TileCacheService slippy coordinate math & paths', () {
      final cacheService = TileCacheService();

      // Zoom 0: entire world is 1 tile (0, 0)
      final p0 = cacheService.latLngToTile(0.0, 0.0, 0);
      expect(p0.x, equals(0));
      expect(p0.y, equals(0));

      // Zoom 1: (0, 0) equator/prime meridian is in tile (1, 1) of 2x2 grid
      final p1 = cacheService.latLngToTile(0.0, 0.0, 1);
      expect(p1.x, equals(1));
      expect(p1.y, equals(1));

      // London (51.5074, -0.1278) at zoom 15:
      final pLondon = cacheService.latLngToTile(51.5074, -0.1278, 15);
      expect(pLondon.x, inInclusiveRange(0, 32767));
      expect(pLondon.y, inInclusiveRange(0, 32767));
      expect(pLondon.x, equals(16372));
      expect(pLondon.y, equals(10896));
    });

    testWidgets('RunGoalSheet renders and allows goal selection', (
      tester,
    ) async {
      RunGoal? selectedGoal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedGoal = await RunGoalSheet.show(ctx);
                },
                child: const Text('Open Goals'),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open Goals'));
      await tester.pumpAndSettle();

      expect(find.text('Run goal'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      // Switch to Distance tab
      await tester.tap(find.text('Distance'));
      await tester.pumpAndSettle();

      // Distance presets visible
      expect(find.text('3.0 km'), findsOneWidget);
      expect(find.text('5.0 km'), findsOneWidget);
      expect(find.text('10.0 km'), findsOneWidget);

      // Select 10.0 km
      await tester.tap(find.text('10.0 km'));
      await tester.pumpAndSettle();

      // Lock in
      await tester.tap(find.text('Set goal'));
      await tester.pumpAndSettle();

      expect(selectedGoal, isNotNull);
      expect(selectedGoal!.type, equals(GoalType.distance));
      expect(selectedGoal!.targetValue, equals(10.0));
    });

    testWidgets('RunHud displays campaign goal progress banner', (
      tester,
    ) async {
      bool goalSelectorOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunHud(
              isRunActive: true,
              isAutoPaused: false,
              distanceKm: 3.5,
              elapsedSeconds: 900,
              movingSeconds: 850,
              splitPace: "4'15\"",
              currentSpeedKmh: 12.0,
              satelliteAccuracyMeters: 4.0,
              territoriesClaimed: 2,
              runGoal: const RunGoal(type: GoalType.distance, targetValue: 5.0),
              onOpenGoalSelector: () {
                goalSelectorOpened = true;
              },
              onToggleRun: () {},
              onSealShape: () {},
              onFinishRun: () {},
            ),
          ),
        ),
      );

      // Verify goal banner elements
      expect(find.text('5 KM TARGET'), findsOneWidget);
      expect(find.text('1.50 km remaining'), findsOneWidget);

      // Tap on goal banner opens goal selector
      await tester.tap(find.text('5 KM TARGET'));
      await tester.pump();
      expect(goalSelectorOpened, isTrue);
    });
  });
}
