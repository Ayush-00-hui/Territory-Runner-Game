import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/map/widgets/amoled_battery_saver_overlay.dart';
import 'package:territory_runner/features/map/widgets/hold_to_finish_button.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/models/run_goal.dart';
import 'package:territory_runner/services/battery_saver_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5: Battery Saver Service Tests', () {
    final batteryService = BatterySaverService();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      batteryService.resetForTest(enabled: false);
    });

    test('BatterySaverService defaults and property tuning', () async {
      expect(batteryService.isBatterySaverEnabled, isFalse);
      expect(batteryService.isAmoledHudActive, isFalse);
      expect(batteryService.gpsIntervalMs, equals(1000));
      expect(batteryService.gpsDistanceFilterMeters, equals(2));
      expect(batteryService.shouldDisableAnimations, isFalse);

      await batteryService.setBatterySaver(true);
      expect(batteryService.isBatterySaverEnabled, isTrue);
      expect(batteryService.gpsIntervalMs, equals(3000));
      expect(batteryService.gpsDistanceFilterMeters, equals(8));
      expect(batteryService.shouldDisableAnimations, isTrue);

      batteryService.setAmoledHudActive(true);
      expect(batteryService.isAmoledHudActive, isTrue);

      // Disabling battery saver should also turn off AMOLED overlay
      await batteryService.setBatterySaver(false);
      expect(batteryService.isBatterySaverEnabled, isFalse);
      expect(batteryService.isAmoledHudActive, isFalse);
    });
  });

  group('Phase 5: AMOLED Battery Saver Overlay Widget Tests', () {
    testWidgets('Renders pure black screen with metrics and wakes on double tap', (tester) async {
      bool woken = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmoledBatterySaverOverlay(
              distanceKm: 5.42,
              elapsedSeconds: 1530, // 25:30
              splitPace: "4'42\"",
              currentSpeedKmh: 12.8,
              runGoal: const RunGoal(type: GoalType.distance, targetValue: 10.0),
              onWake: () => woken = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify pure black background
      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      expect(container.color, equals(Colors.black));

      // Verify telemetry display
      expect(find.text('25:30'), findsOneWidget);
      expect(find.text('5.42'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);
      expect(find.text("4'42\""), findsOneWidget);
      expect(find.text('12.8 km/h'), findsOneWidget);
      expect(find.text('10 KM TARGET'), findsOneWidget);
      expect(find.text('Battery saver active'), findsOneWidget);

      // Double tap to wake
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(woken, isTrue);
    });

    testWidgets('Wakes on exit button tap', (tester) async {
      bool woken = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmoledBatterySaverOverlay(
              distanceKm: 2.1,
              elapsedSeconds: 600,
              splitPace: "5'00\"",
              currentSpeedKmh: 12.0,
              onWake: () => woken = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(woken, isTrue);
    });
  });

  group('Phase 5: Accessibility & Semantics Tests', () {
    testWidgets('HoldToFinishButton provides semantic labels in locked & active states', (tester) async {
      // Locked state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HoldToFinishButton(
              isRunActive: false,
              onFinish: () {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label == 'Run tracking inactive. Tap center play button to begin.'),
        findsOneWidget,
      );

      // Active state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HoldToFinishButton(
              isRunActive: true,
              onFinish: () {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Hold for 1.5 seconds to finish and submit run'),
        findsOneWidget,
      );
    });

    testWidgets('RunHud action buttons have semantic button labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunHud(
              isRunActive: true,
              isAutoPaused: true,
              distanceKm: 3.5,
              elapsedSeconds: 1200,
              movingSeconds: 1100,
              splitPace: "5'20\"",
              currentSpeedKmh: 0.0,
              satelliteAccuracyMeters: 5.0,
              territoriesClaimed: 2,
              runGoal: const RunGoal(type: GoalType.distance, targetValue: 5.0),
              onToggleRun: () {},
              onSealShape: () {},
              onFinishRun: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Auto-pause banner semantics
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            (w.properties.label?.contains('Run tracking auto-paused') ?? false)),
        findsOneWidget,
      );

      // Seal shape button semantics
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Seal territory shape'),
        findsOneWidget,
      );

      // Pause button semantics
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Pause run tracking'),
        findsOneWidget,
      );

      // Goal banner semantics
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            (w.properties.label?.contains('5 KM TARGET') ?? false)),
        findsOneWidget,
      );
    });

    test('WCAG AA contrast verification for textMuted on dark surface', () {
      final lBg = AppColors.bgDeep.computeLuminance();
      final lMuted = AppColors.textMuted.computeLuminance();
      final contrast = (math.max(lBg, lMuted) + 0.05) / (math.min(lBg, lMuted) + 0.05);

      // WCAG AA requirement for normal text is >= 4.5:1
      expect(contrast, greaterThanOrEqualTo(4.5));
    });
  });
}
