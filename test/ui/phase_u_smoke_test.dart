import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/features/map/map_screen.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/features/profile/profile_screen.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/run_log_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final testProfile = RunnerProfile(
    id: 'smoke_runner_1',
    username: 'ApexRunner',
    totalDistanceKm: 120.5,
    xp: 4500,
    level: 9,
    badges: ['Loop Master', 'Pioneer'],
    totalHexesClaimed: 35,
    currentStreak: 14,
    faction: 'Vanguard',
  );

  final testRuns = [
    RunLogEntry(
      id: 'run_smoke_1',
      title: 'River Sunrise Loop',
      notes: 'Strong tempo run around the river',
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      endedAt: DateTime.now().subtract(const Duration(hours: 1)),
      distanceM: 5200.0,
      movingSeconds: 1560,
      totalSeconds: 1620,
      claimedAreaSqM: 18500.0,
      xp: 250,
      samples: const [
        RunSample(timeOffsetMs: 0, lat: 51.5074, lng: -0.1278),
        RunSample(timeOffsetMs: 500, lat: 51.5084, lng: -0.1278),
        RunSample(timeOffsetMs: 1000, lat: 51.5084, lng: -0.1268),
        RunSample(timeOffsetMs: 1500, lat: 51.5074, lng: -0.1278),
      ],
    ),
    RunLogEntry(
      id: 'run_smoke_2',
      title: 'City Park Sprint',
      notes: 'Fast intervals',
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
      endedAt: DateTime.now().subtract(const Duration(days: 3, hours: -1)),
      distanceM: 3400.0,
      movingSeconds: 1020,
      totalSeconds: 1100,
      claimedAreaSqM: 8200.0,
      xp: 120,
      samples: const [
        RunSample(timeOffsetMs: 0, lat: 51.5174, lng: -0.1378),
        RunSample(timeOffsetMs: 500, lat: 51.5184, lng: -0.1378),
        RunSample(timeOffsetMs: 1000, lat: 51.5184, lng: -0.1368),
        RunSample(timeOffsetMs: 1500, lat: 51.5174, lng: -0.1378),
      ],
    ),
  ];

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_phase_u_smoke_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }

    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
    await Hive.openBox<String>('run_log_v1');

    SharedPreferences.setMockInitialValues({
      'is_demo_mode_enabled': false,
      'has_completed_onboarding': true,
      'pref_battery_saver_enabled': false,
    });
    await AppPreferences().init();
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    final profileBox = Hive.box<RunnerProfile>('profile');
    await profileBox.clear();
    await profileBox.put('current_user', testProfile);
    await profileBox.put('current_runner', testProfile);

    RunLogService().runsNotifier.value = List<RunLogEntry>.from(testRuns);
  });

  final viewports = [
    const Size(360, 640), // Compact budget phone
    const Size(411, 891), // Modern standard phone
    const Size(800, 1280), // Tablet
  ];

  final fontScales = [1.0, 1.3, 2.0];

  group('Phase U: Responsive Layout and Text Scaling Smoke Tests', () {
    for (final size in viewports) {
      for (final scale in fontScales) {
        testWidgets(
          'RunHistoryScreen renders without crash at ${size.width}x${size.height} fontScale $scale',
          (tester) async {
            tester.view.physicalSize = size * tester.view.devicePixelRatio;
            addTearDown(() => tester.view.resetPhysicalSize());

            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: RunHistoryScreen(
                    initialProfile: testProfile,
                    initialRuns: testRuns,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Run history'), findsOneWidget);
            expect(find.text('River Sunrise Loop'), findsOneWidget);
            final secondItem = find.text('City Park Sprint');
            if (tester.any(secondItem)) {
              expect(secondItem, findsOneWidget);
            } else {
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0.0, -300.0),
              );
              await tester.pumpAndSettle();
              expect(find.text('City Park Sprint'), findsOneWidget);
            }
          },
        );
      }
    }

    testWidgets('RunHistoryScreen search bar filters runs by title and notes', (
      tester,
    ) async {
      tester.view.physicalSize =
          const Size(800, 1200) * tester.view.devicePixelRatio;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: RunHistoryScreen(
            initialProfile: testProfile,
            initialRuns: List<RunLogEntry>.from(testRuns),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('River Sunrise Loop'), findsOneWidget);
      expect(find.text('City Park Sprint'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField).first, 'Sunrise');
      await tester.pumpAndSettle();

      expect(find.text('River Sunrise Loop'), findsOneWidget);
      expect(find.text('City Park Sprint'), findsNothing);

      // Clear query
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      expect(find.text('River Sunrise Loop'), findsOneWidget);
      expect(find.text('City Park Sprint'), findsOneWidget);
    });

    testWidgets(
      'RunHistoryScreen tapping run opens dossier with GPX and Edit buttons',
      (tester) async {
        tester.view.physicalSize =
            const Size(800, 1200) * tester.view.devicePixelRatio;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: RunHistoryScreen(
              initialProfile: testProfile,
              initialRuns: List<RunLogEntry>.from(testRuns),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap first run
        await tester.tap(find.text('River Sunrise Loop'));
        await tester.pumpAndSettle();

        // Verify dossier details and actions
        expect(find.text('River Sunrise Loop'), findsWidgets);
        expect(find.text('GPX'), findsOneWidget);
        expect(find.textContaining('Share'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        // Tap Done to close modal
        await tester.tap(find.text('Done'), warnIfMissed: false);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'RunHistoryScreen swipe to dismiss run displays Undo SnackBar',
      (tester) async {
        tester.view.physicalSize =
            const Size(800, 1200) * tester.view.devicePixelRatio;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: RunHistoryScreen(
              initialProfile: testProfile,
              initialRuns: List<RunLogEntry>.from(testRuns),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Dismissible), findsNWidgets(2));

        // Drag first run to dismiss
        await tester.drag(
          find.byKey(const ValueKey('run-dismiss-run_smoke_1')),
          const Offset(-500.0, 0.0),
        );
        await tester.pumpAndSettle();

        // Verify SnackBar appeared with Undo action
        expect(find.text('Run deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        // Tap Undo
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // Verify run restored
        expect(find.text('River Sunrise Loop'), findsOneWidget);
      },
    );

    testWidgets(
      'MapScreen controls bar toggles pause and resume without crash',
      (tester) async {
        final controller = MapRunController();

        await tester.pumpWidget(
          ChangeNotifierProvider<MapRunController>.value(
            value: controller,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: MapScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Start run directly
        controller.startRun();
        await tester.pump(const Duration(milliseconds: 200));

        expect(controller.isRunActive, isTrue);
        expect(controller.isPaused, isFalse);

        // Toggle pause
        controller.togglePauseResume();
        await tester.pump(const Duration(milliseconds: 200));

        expect(controller.isPaused, isTrue);
        expect(find.text('Run paused'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);

        // Resume run
        controller.togglePauseResume();
        await tester.pump(const Duration(milliseconds: 200));

        expect(controller.isPaused, isFalse);

        // Low battery prompt check
        controller.checkBatteryLevel(12);
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Battery below 15%'), findsOneWidget);
        expect(find.text('Enable'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Dismiss low battery prompt
        await tester.tap(find.text('Dismiss'));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Battery below 15%'), findsNothing);

        // Stop run
        controller.stopRun();
        await tester.pump(const Duration(milliseconds: 200));

        // Cleanly unmount MapScreen to cancel active tickers and listeners
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets(
      'ProfilePage renders without error at standard and large textScales',
      (tester) async {
        for (final scale in [1.0, 1.5]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(411, 891),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: ProfilePage()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('ApexRunner'), findsOneWidget);
          expect(find.text('Total Distance'), findsOneWidget);
          expect(find.text('Active Streak'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
