import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/map/widgets/gps_sync_chip.dart';
import 'package:territory_runner/features/map/widgets/map_controls_rail.dart';
import 'package:territory_runner/features/map/widgets/map_layers_sheet.dart';
import 'package:territory_runner/features/map/widgets/map_tools_sheet.dart';
import 'package:territory_runner/features/map/widgets/run_go_cue.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/features/map/widgets/sos_shield_button.dart';
import 'package:territory_runner/models/run_goal.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  group('Phase U1: Map Layout & Ergonomic Touch Targets', () {
    testWidgets('MapControlsRail touch targets meet >= 48x48 dp accessibility requirement', (tester) async {
      bool toolsTapped = false;
      bool layersTapped = false;
      bool recenterTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: MapControlsRail(
                onOpenTools: () => toolsTapped = true,
                onOpenLayers: () => layersTapped = true,
                onRecenter: () => recenterTapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify buttons exist
      final toolsFinder = find.byTooltip('Run tools');
      final layersFinder = find.byTooltip('Map layers');
      final recenterFinder = find.byTooltip('Recenter map');

      expect(toolsFinder, findsOneWidget);
      expect(layersFinder, findsOneWidget);
      expect(recenterFinder, findsOneWidget);

      // Verify touch target sizes >= 48x48 dp
      final toolsSize = tester.getSize(toolsFinder);
      expect(toolsSize.width, greaterThanOrEqualTo(48.0));
      expect(toolsSize.height, greaterThanOrEqualTo(48.0));

      final layersSize = tester.getSize(layersFinder);
      expect(layersSize.width, greaterThanOrEqualTo(48.0));
      expect(layersSize.height, greaterThanOrEqualTo(48.0));

      final recenterSize = tester.getSize(recenterFinder);
      expect(recenterSize.width, greaterThanOrEqualTo(48.0));
      expect(recenterSize.height, greaterThanOrEqualTo(48.0));

      // Tap actions
      await tester.tap(toolsFinder);
      expect(toolsTapped, isTrue);

      await tester.tap(layersFinder);
      expect(layersTapped, isTrue);

      await tester.tap(recenterFinder);
      expect(recenterTapped, isTrue);
    });

    testWidgets('SosShieldButton touch target is >= 48x48 dp and requires 1.5s press-and-hold', (tester) async {
      bool sosTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SosShieldButton(
                onTriggerSos: () => sosTriggered = true,
              ),
            ),
          ),
        ),
      );

      final sosFinder = find.byType(SosShieldButton);
      expect(sosFinder, findsOneWidget);

      final sosSize = tester.getSize(sosFinder);
      expect(sosSize.width, greaterThanOrEqualTo(48.0));
      expect(sosSize.height, greaterThanOrEqualTo(48.0));

      // Short tap should NOT trigger SOS
      await tester.tap(sosFinder);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sosTriggered, isFalse);
    });

    testWidgets('SosShieldButton requires 1.5s press-and-hold to trigger SOS callback', (tester) async {
      bool sosTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SosShieldButton(
                onTriggerSos: () => sosTriggered = true,
              ),
            ),
          ),
        ),
      );

      final sosFinder = find.byType(SosShieldButton);
      expect(sosFinder, findsOneWidget);

      // Long press for 1.6s triggers SOS
      final gesture = await tester.startGesture(tester.getCenter(sosFinder));
      await tester.pump();
      expect(sosTriggered, isFalse);

      await tester.pump(const Duration(milliseconds: 500));
      expect(sosTriggered, isFalse);

      await tester.pump(const Duration(milliseconds: 1100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sosTriggered, isTrue);
    });

    testWidgets('GpsSyncChip renders accuracy and satisfies >= 48 dp height hit target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: GpsSyncChip(
                accuracyMeters: 4.2,
                isGpsSearching: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('4m'), findsOneWidget);
      final chipFinder = find.byType(GpsSyncChip);
      final size = tester.getSize(chipFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('RunGoCue displays athletic cue and completes within <= 400 ms', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RunGoCue(
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('GO'), findsOneWidget);
      expect(dismissed, isFalse);

      // Advances 400ms: should automatically dismiss
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('MapToolsSheet presents secondary tools and dismisses on selection', (tester) async {
      bool pacerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MapToolsSheet.show(
                    context: context,
                    onOpenPacer: () => pacerOpened = true,
                    onOpenGoals: () {},
                    onOpenRoutePlanner: () {},
                    onToggleAmoled: () {},
                    onOpenOfflineMaps: () {},
                    onTriggerSos: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Run tools'), findsOneWidget);
      expect(find.text('Virtual pacer'), findsOneWidget);
      expect(find.text('Run goals'), findsOneWidget);
      expect(find.text('Route suggestions'), findsOneWidget);
      expect(find.text('Low-power display'), findsOneWidget);
      expect(find.text('Offline maps'), findsOneWidget);
      expect(find.text('Emergency SOS'), findsOneWidget);

      // Tap Virtual Pacer
      await tester.tap(find.text('Virtual pacer'));
      await tester.pumpAndSettle();
      expect(pacerOpened, isTrue);
    });

    testWidgets('MapLayersSheet renders layer toggles and locate nearest runner action', (tester) async {
      bool nearestRivalLocated = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MapLayersSheet.show(
                    context: context,
                    onStyleChanged: () {},
                    onLocateNearestRival: () => nearestRivalLocated = true,
                  );
                },
                child: const Text('Open Layers'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Layers'));
      await tester.pumpAndSettle();

      expect(find.text('Map layers'), findsOneWidget);
      expect(find.text('Territories'), findsOneWidget);
      expect(find.text('Nearby runners'), findsOneWidget);
      expect(find.text('High-contrast outdoor mode'), findsOneWidget);
      expect(find.text('Pan to nearest runner'), findsOneWidget);

      await tester.tap(find.text('Pan to nearest runner'));
      await tester.pumpAndSettle();
      expect(nearestRivalLocated, isTrue);
    });
  });

  group('Phase U1: Dynamic Measured Responsive Layout Tests', () {
    final screenSizes = [
      const Size(360, 640), // Compact Android phone
      const Size(411, 891), // Standard modern phone (Pixel / iPhone 15)
      const Size(800, 1280), // Tablet
    ];

    final textScales = [1.0, 1.3, 2.0];

    for (final size in screenSizes) {
      for (final textScale in textScales) {
        testWidgets(
          'Map dynamic layout renders without overflow at ${size.width.toInt()}x${size.height.toInt()} with textScale $textScale',
          (tester) async {
            tester.view.physicalSize = Size(size.width, size.height);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final hudHeightNotifier = ValueNotifier<double>(180.0);
            final leftHandedNotifier = ValueNotifier<bool>(false);

            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.darkTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    padding: const EdgeInsets.only(top: 24, bottom: 20),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: Scaffold(
                    backgroundColor: AppColors.bgDeep,
                    body: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Top bar: Avatar + GpsSyncChip
                        Positioned(
                          top: 24 + 10,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surfaceGlass,
                                child: Text(
                                  'A',
                                  style: AppText.headingSmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const GpsSyncChip(
                                accuracyMeters: 5.0,
                                isGpsSearching: false,
                              ),
                            ],
                          ),
                        ),

                        // 2. Floating Controls anchored dynamically above measured HUD height
                        ValueListenableBuilder<bool>(
                          valueListenable: leftHandedNotifier,
                          builder: (context, isLeftHanded, _) {
                            return ValueListenableBuilder<double>(
                              valueListenable: hudHeightNotifier,
                              builder: (context, hudHeight, _) {
                                final bottomOffset = 20 + 12 + hudHeight + 12;

                                return Stack(
                                  children: [
                                    Positioned(
                                      left: isLeftHanded ? 16 : null,
                                      right: isLeftHanded ? null : 16,
                                      bottom: bottomOffset,
                                      child: MapControlsRail(
                                        onOpenTools: () {},
                                        onOpenLayers: () {},
                                        onRecenter: () {},
                                      ),
                                    ),
                                    Positioned(
                                      left: isLeftHanded ? null : 16,
                                      right: isLeftHanded ? 16 : null,
                                      bottom: bottomOffset,
                                      child: SosShieldButton(
                                        onTriggerSos: () {},
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),

                        // 3. Measured HUD
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 20 + 12,
                          child: MeasureSize(
                            onChange: (measuredSize) {
                              if (hudHeightNotifier.value != measuredSize.height) {
                                hudHeightNotifier.value = measuredSize.height;
                              }
                            },
                            child: RunHud(
                              isRunActive: false,
                              isSearchingGps: false,
                              isAutoPaused: false,
                              distanceKm: 2.45,
                              elapsedSeconds: 720,
                              movingSeconds: 700,
                              splitPace: "4'55\"",
                              currentSpeedKmh: 12.2,
                              satelliteAccuracyMeters: 4.5,
                              territoriesClaimed: 2,
                              runGoal: const RunGoal(type: GoalType.distance, targetValue: 5.0),
                              onOpenGoalSelector: () {},
                              isBatterySaverActive: false,
                              onToggleAmoledSaver: () {},
                              onToggleRun: () {},
                              onSealShape: () {},
                              onFinishRun: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            // Verify no render overflows
            expect(tester.takeException(), isNull);

            // Verify HUD is measured and > 0
            expect(hudHeightNotifier.value, greaterThan(50.0));

            // Verify MapControlsRail bottom is strictly above the top of RunHud
            final hudTop = tester.getRect(find.byType(RunHud)).top;
            final railBottom = tester.getRect(find.byType(MapControlsRail)).bottom;
            expect(railBottom, lessThanOrEqualTo(hudTop));

            // Verify SOS button bottom is strictly above the top of RunHud
            final sosBottom = tester.getRect(find.byType(SosShieldButton)).bottom;
            expect(sosBottom, lessThanOrEqualTo(hudTop));
          },
        );
      }
    }

    testWidgets('Left-handed mode flips control rail to left and SOS to right', (tester) async {
      final leftHandedNotifier = ValueNotifier<bool>(false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: leftHandedNotifier,
              builder: (context, isLeftHanded, _) {
                return Stack(
                  children: [
                    Positioned(
                      left: isLeftHanded ? 16 : null,
                      right: isLeftHanded ? null : 16,
                      bottom: 100,
                      child: MapControlsRail(
                        onOpenTools: () {},
                        onOpenLayers: () {},
                        onRecenter: () {},
                      ),
                    ),
                    Positioned(
                      left: isLeftHanded ? null : 16,
                      right: isLeftHanded ? 16 : null,
                      bottom: 100,
                      child: SosShieldButton(
                        onTriggerSos: () {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Default (right-handed): rail on right, SOS on left
      var railCenter = tester.getCenter(find.byType(MapControlsRail));
      var sosCenter = tester.getCenter(find.byType(SosShieldButton));
      expect(railCenter.dx, greaterThan(sosCenter.dx));

      // Flip to left-handed
      leftHandedNotifier.value = true;
      await tester.pumpAndSettle();

      railCenter = tester.getCenter(find.byType(MapControlsRail));
      sosCenter = tester.getCenter(find.byType(SosShieldButton));
      expect(railCenter.dx, lessThan(sosCenter.dx));
    });
  });
}
