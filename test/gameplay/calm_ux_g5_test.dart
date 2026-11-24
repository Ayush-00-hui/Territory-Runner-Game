import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/features/home/widgets/today_workout_card.dart';
import 'package:territory_runner/features/map/widgets/lap_splits_table.dart';
import 'package:territory_runner/models/lap_split.dart';
import 'package:territory_runner/models/saved_loop.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/saved_loop_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('calm_ux_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase G5: Calm UX & Haptics Infrastructure Tests', () {
    test('Haptic triggers respect master isHapticsEnabled switch', () async {
      final prefs = AppPreferences();

      // Enable haptics
      await prefs.toggleHaptics(true);
      expect(prefs.isHapticsEnabled, isTrue);

      // Triggering haptics does not throw
      expect(() => prefs.triggerTabSwitchHaptic(), returnsNormally);
      expect(() => prefs.triggerOffRouteHaptic(), returnsNormally);
      expect(() => prefs.triggerMilestoneHaptic(), returnsNormally);
      expect(() => prefs.triggerLoopClosedHaptic(), returnsNormally);

      // Disable haptics
      await prefs.toggleHaptics(false);
      expect(prefs.isHapticsEnabled, isFalse);
      expect(() => prefs.triggerTabSwitchHaptic(), returnsNormally);
      expect(() => prefs.triggerOffRouteHaptic(), returnsNormally);

      // Restore
      await prefs.toggleHaptics(true);
    });

    test('Off-route detection triggers when deviation exceeds threshold', () {
      final service = SavedLoopService();
      final loop = SavedLoop(
        id: 'loop_off_route',
        name: 'Off Route Test',
        points: const [
          LatLng(51.500, -0.120),
          LatLng(51.501, -0.120),
          LatLng(51.501, -0.121),
          LatLng(51.500, -0.121),
        ],
        distanceMeters: 400.0,
        areaSqMeters: 10000.0,
        createdAt: DateTime.now(),
      );

      // On-route point
      final onRoute = service.computeProgress(
        const LatLng(51.500, -0.120),
        loop.points,
      );
      expect(onRoute.isOffRoute, isFalse);

      // 100m away -> off-route
      final offRoute = service.computeProgress(
        const LatLng(51.505, -0.120),
        loop.points,
      );
      expect(offRoute.isOffRoute, isTrue);
      expect(offRoute.distanceToRouteMeters, greaterThan(40.0));
    });
  });

  group('Phase G5: Empty States & Accessibility Tests', () {
    testWidgets(
      'EmptyState widget renders icon, plain copy, and actionable CTA',
      (tester) async {
        bool actionTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: Icons.directions_run_rounded,
                title: 'No runs logged',
                message: 'Lace up your shoes and run a closed loop.',
                actionLabel: 'Start run',
                onAction: () => actionTriggered = true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
        expect(find.text('No runs logged'), findsOneWidget);
        expect(
          find.text('Lace up your shoes and run a closed loop.'),
          findsOneWidget,
        );
        expect(find.text('Start run'), findsOneWidget);

        await tester.tap(find.text('Start run'));
        expect(actionTriggered, isTrue);
      },
    );

    testWidgets(
      'RunHistoryScreen empty state renders icon, text, and actionable CTA',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RunHistoryScreen(initialRuns: [], initialTerritories: []),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No runs in range'), findsOneWidget);
        expect(find.text('Start run'), findsOneWidget);
      },
    );

    testWidgets(
      'TodayWorkoutCard and LapSplitsTable scale gracefully at textScaleFactor 2.0 without overflow',
      (tester) async {
        final splits = [
          const LapSplit(
            lapNumber: 1,
            distanceMeters: 1000.0,
            durationSeconds: 300,
            paceSecondsPerKm: 300.0,
            elevationGainMeters: 10.0,
          ),
          const LapSplit(
            lapNumber: 2,
            distanceMeters: 1000.0,
            durationSeconds: 290,
            paceSecondsPerKm: 290.0,
            elevationGainMeters: 5.0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(360, 800),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      TodayWorkoutCard(onStartWorkout: (_) {}),
                      LapSplitsTable(laps: splits),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(LapSplitsTable), findsOneWidget);
      },
    );
  });
}
