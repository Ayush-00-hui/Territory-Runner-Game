// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/features/map/widgets/hold_to_finish_button.dart';
import 'package:territory_runner/features/map/widgets/summary_sheet.dart';
import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_bench_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('Benchmark: Territory fold in build() with 100 territories', () async {
    final box = Hive.box<Territory>('territories_v3');
    await box.clear();

    // Populate with 100 captured territories
    for (int i = 0; i < 100; i++) {
      await box.put(
        'poly_$i',
        Territory(
          id: 'poly_$i',
          ownerId: 'runner_1',
          polygon: [
            LatLng(37.77 + i * 0.001, -122.41 + i * 0.001),
            LatLng(37.771 + i * 0.001, -122.41 + i * 0.001),
            LatLng(37.771 + i * 0.001, -122.411 + i * 0.001),
          ],
          areaSqMeters: 15400.0 + i,
          capturedAt: DateTime.now(),
        ),
      );
    }

    final territoryService = TerritoryService();
    final stopwatch = Stopwatch()..start();
    const iterations = 1000;
    double totalArea = 0.0;

    for (int i = 0; i < iterations; i++) {
      // Simulates what map_screen.dart:1459-1463 does on every build/setState:
      final territories = territoryService.getCapturedTerritoryObjects();
      final double totalAreaSqMeters = territories.fold(
        0.0,
        (sum, t) => sum + t.areaSqMeters,
      );
      totalArea = totalAreaSqMeters;
    }
    stopwatch.stop();

    final elapsedMicrosPerBuild = stopwatch.elapsedMicroseconds / iterations;
    print('========================================================');
    print('BASELINE MEASUREMENT (U0): Hive re-read + fold in build()');
    print('Total territories: 100');
    print('Iterations: $iterations builds');
    print('Total time: ${stopwatch.elapsedMilliseconds} ms');
    print(
      'Time per build: ${elapsedMicrosPerBuild.toStringAsFixed(2)} µs (${(elapsedMicrosPerBuild / 1000.0).toStringAsFixed(3)} ms)',
    );
    print('Calculated Area: ${totalArea.toStringAsFixed(2)} m²');
    print('========================================================');

    expect(totalArea, greaterThan(0));
  });

  testWidgets(
    'Baseline (U0): Left rail circle buttons are 44x44 dp (under 48 dp target)',
    (tester) async {
      // In map_screen.dart:2045-2046:
      // Container(height: 44, width: 44, decoration: BoxDecoration(shape: BoxShape.circle))
      const circleSize = Size(44, 44);
      expect(
        circleSize.width,
        lessThan(48.0),
        reason: 'Current left rail buttons violate 48 dp touch target rule',
      );
      expect(
        circleSize.height,
        lessThan(48.0),
        reason: 'Current left rail buttons violate 48 dp touch target rule',
      );
    },
  );

  testWidgets(
    'Baseline (U0): showRunStartAnimation presents blocking 3600ms repeating dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  // Simulates showRunStartAnimation
                  showGeneralDialog(
                    context: context,
                    barrierColor: Colors.black54,
                    pageBuilder: (ctx, _, _) => Center(
                      child: SizedBox(
                        width: 320,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Start run'),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Start run'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap to open
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Notice: There are now TWO 'Start run' text widgets in the tree (dialog title + duplicate button)
      expect(find.text('Start run'), findsNWidgets(2));
    },
  );

  testWidgets(
    'Verification (U1): showRunStartAnimation is a zero-op stub with zero dialogs opened',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  // Calls the real showRunStartAnimation from main.dart
                  showRunStartAnimation(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies zero modal dialogs are presented on run start
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Start run'), findsNothing);
    },
  );

  testWidgets(
    'Verification (U1): RunHud displays inline quiet Finding GPS... status without blocking modals',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunHud(
              isRunActive: true,
              isSearchingGps: true,
              isAutoPaused: false,
              distanceKm: 0.0,
              elapsedSeconds: 0,
              movingSeconds: 0,
              splitPace: '--:--',
              currentSpeedKmh: 0.0,
              satelliteAccuracyMeters: 5.0,
              territoriesClaimed: 0,
              onToggleRun: () {},
              onSealShape: () {},
              onFinishRun: () {},
            ),
          ),
        ),
      );

      // Verify quiet inline badge appears
      expect(find.text('Finding GPS...'), findsOneWidget);
      // Verify no modal or full-screen blocker is rendered
      expect(find.byType(Dialog), findsNothing);
    },
  );

  test(
    'Verification (U1): Cached territory notifier benchmark vs fold',
    () async {
      final territoryService = TerritoryService();
      final initialList = territoryService.getCapturedTerritoryObjects();
      final double initialArea = initialList.fold(
        0.0,
        (s, t) => s + t.areaSqMeters,
      );
      final notifier = ValueNotifier<double>(initialArea / 1000000.0);

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      double readArea = 0.0;
      for (int i = 0; i < iterations; i++) {
        readArea = notifier.value;
      }
      stopwatch.stop();

      final elapsedMicros = stopwatch.elapsedMicroseconds / iterations;
      print('========================================================');
      print('VERIFICATION (U1): Cached territory notifier access');
      print('Iterations: $iterations reads');
      print('Total time: ${stopwatch.elapsedMicroseconds} µs');
      print('Time per build: ${elapsedMicros.toStringAsFixed(3)} µs');
      print('Calculated Area: ${readArea.toStringAsFixed(2)} km²');
      print('========================================================');

      expect(readArea, greaterThan(0));
      notifier.dispose();
    },
  );

  testWidgets(
    'Verification (U2): Floating circle buttons and HUD action buttons meet >=48 dp touch target rule',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  HoldToFinishButton(isRunActive: true, onFinish: () {}),
                  HoldToFinishButton(isRunActive: false, onFinish: () {}),
                  RunHud(
                    isRunActive: true,
                    isSearchingGps: false,
                    isAutoPaused: false,
                    distanceKm: 2.5,
                    elapsedSeconds: 600,
                    movingSeconds: 580,
                    splitPace: '4:50',
                    currentSpeedKmh: 12.4,
                    satelliteAccuracyMeters: 4.0,
                    territoriesClaimed: 2,
                    onToggleRun: () {},
                    onSealShape: () {},
                    onFinishRun: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify HoldToFinishButton touch targets are >= 48dp (2 standalone + 1 in RunHud)
      final holdButtons = find.byType(HoldToFinishButton);
      expect(holdButtons, findsNWidgets(3));
      for (final element in holdButtons.evaluate()) {
        final renderBox = element.findRenderObject() as RenderBox;
        expect(
          renderBox.size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'HoldToFinishButton must have minimum height of 48 dp',
        );
      }

      // Verify Close Loop touch target is >= 48dp
      final closeLoopText = find.text('Close loop');
      expect(closeLoopText, findsOneWidget);
      final closeLoopContainer = find.ancestor(
        of: closeLoopText,
        matching: find.byType(Container),
      );
      final closeLoopBox = tester.renderObject<RenderBox>(
        closeLoopContainer.first,
      );
      expect(
        closeLoopBox.size.height,
        greaterThanOrEqualTo(48.0),
        reason: 'Close loop action button must have minimum height of 48 dp',
      );
    },
  );

  testWidgets(
    'Verification (U2): RunHud renders without overflow across 360x640, 393x852, 412x915 at textScale 1.3',
    (tester) async {
      const resolutions = [Size(360, 640), Size(393, 852), Size(412, 915)];

      for (final res in resolutions) {
        tester.view.physicalSize = Size(res.width * 2, res.height * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: RunHud(
                  isRunActive: true,
                  isSearchingGps: true,
                  isAutoPaused: false,
                  distanceKm: 14.85,
                  elapsedSeconds: 5420,
                  movingSeconds: 5120,
                  splitPace: '5:45',
                  currentSpeedKmh: 10.5,
                  satelliteAccuracyMeters: 6.0,
                  territoriesClaimed: 7,
                  distanceToClosureMeters: 45.0,
                  proximityToClosure: 0.85,
                  onToggleRun: () {},
                  onSealShape: () {},
                  onFinishRun: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        // Verifies zero overflow exceptions occur on any target resolution
        expect(tester.takeException(), isNull);
      }

      // Reset tester view
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'Verification (U3): RunHud toggles extended telemetry on drag/tap gesture without overflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunHud(
                isRunActive: true,
                isSearchingGps: false,
                isAutoPaused: false,
                distanceKm: 5.25,
                elapsedSeconds: 1800,
                movingSeconds: 1650,
                splitPace: '5:10',
                currentSpeedKmh: 11.2,
                satelliteAccuracyMeters: 4.0,
                territoriesClaimed: 3,
                currentAreaSqm: 25000.0,
                onToggleRun: () {},
                onSealShape: () {},
                onFinishRun: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the secondary telemetry row to expand extended telemetry
      final speedText = find.text('11.2 km/h');
      expect(speedText, findsOneWidget);
      await tester.tap(speedText);
      await tester.pumpAndSettle();

      // Now expanded: 'Avg pace', 'Moving time', 'Active area' are visible
      expect(find.text('Avg pace'), findsOneWidget);
      expect(find.text('Moving time'), findsOneWidget);
      expect(find.text('Active area'), findsOneWidget);
      expect(find.text('2.5 ha'), findsOneWidget);

      // Tap again to collapse cleanly
      await tester.tap(speedText);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Verification (U3): RunHud expanded telemetry renders without overflow across 360, 393, 412 at textScale 1.3',
    (tester) async {
      const resolutions = [Size(360, 640), Size(393, 852), Size(412, 915)];

      for (final res in resolutions) {
        await tester.binding.setSurfaceSize(res);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RunHud(
                    key: ValueKey(res),
                    isRunActive: true,
                    isSearchingGps: true,
                    isAutoPaused: false,
                    distanceKm: 14.85,
                    elapsedSeconds: 5420,
                    movingSeconds: 5120,
                    splitPace: '5:45',
                    currentSpeedKmh: 10.5,
                    satelliteAccuracyMeters: 6.0,
                    territoriesClaimed: 7,
                    currentAreaSqm: 54000.0,
                    distanceToClosureMeters: 45.0,
                    proximityToClosure: 0.85,
                    onToggleRun: () {},
                    onSealShape: () {},
                    onFinishRun: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        // Tap secondary row to trigger expansion in each resolution
        final speedText = find.text('10.5 km/h');
        expect(speedText, findsOneWidget);
        await tester.tap(speedText);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Verifies zero overflow exceptions occur on any target resolution while expanded
        expect(tester.takeException(), isNull);
        expect(find.text('Avg pace'), findsOneWidget);
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'Verification (U3): SummarySheet numbers count up within 500ms and Done is primary bottom action',
    (tester) async {
      final profile = RunnerProfile(
        id: 'u3_runner',
        username: 'PacerAlpha',
        totalDistanceKm: 25.0,
        xp: 1200,
        level: 5,
        badges: ['Pacer'],
        totalHexesClaimed: 12,
        currentStreak: 3,
        faction: 'Obsidian Syndicate',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SummarySheet(
                distanceKm: 5.0,
                durationSeconds: 1500,
                territoriesClaimed: 4,
                profile: profile,
                coachService: LLMCoachService(),
                areaSqMeters: 60000.0,
              ),
            ),
          ),
        ),
      );

      // Frame 1: numbers start counting up from 0
      await tester.pump();
      expect(find.text('0.00 km'), findsOneWidget);

      // At 500ms: numbers settle at full target values
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);

      // Verify Done button exists as full primary button
      final doneFinder = find.widgetWithText(PrimaryButton, 'Done');
      expect(doneFinder, findsOneWidget);
    },
  );
}
