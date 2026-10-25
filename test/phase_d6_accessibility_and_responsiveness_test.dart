import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/features/home/home_screen.dart';
import 'package:territory_runner/features/map/widgets/hold_to_finish_button.dart';
import 'package:territory_runner/features/map/widgets/run_goal_sheet.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/features/map/widgets/sos_shield_button.dart';
import 'package:territory_runner/features/map/widgets/summary_sheet.dart';
import 'package:territory_runner/models/run_goal.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/profile_page.dart';
import 'package:territory_runner/ui/ui.dart';

class MockCoachService implements LLMCoachService {
  @override
  Future<CoachInsight> generateRunInsight({
    String? runId,
    required double distanceKm,
    required int durationSeconds,
    int? territoriesClaimed,
    int? hexesClaimed,
    required RunnerProfile profile,
    String? currentPaceFormatted,
  }) async {
    return const CoachInsight(
      summary: 'Strong athletic pacing throughout your run.',
      tip: 'Maintain steady cadence on the turns.',
      moodTag: CoachMood.encouraging,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_d6_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    final profileBox = await Hive.openBox<RunnerProfile>('profile');
    await Hive.openBox<Territory>('territories_v3');
    await profileBox.put(
      'current_runner',
      RunnerProfile(
        id: 'athlete_d6',
        username: 'JordanRunner',
        totalDistanceKm: 52.8,
        xp: 2800,
        level: 6,
        badges: ['First Claim', '5K Finisher'],
        totalHexesClaimed: 18,
        currentStreak: 5,
        faction: 'Vanguard',
      ),
    );
    SharedPreferences.setMockInitialValues({'fcm_permission_prompted': true});
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  final testProfile = RunnerProfile(
    id: 'athlete_d6',
    username: 'JordanRunner',
    totalDistanceKm: 52.8,
    xp: 2800,
    level: 6,
    badges: ['First Claim', '5K Finisher'],
    totalHexesClaimed: 18,
    currentStreak: 5,
    faction: 'Vanguard',
  );

  final testTerritories = [
    Territory(
      id: 'terr_d6_1',
      ownerId: 'athlete_d6',
      polygon: const [
        LatLng(37.7749, -122.4194),
        LatLng(37.7759, -122.4194),
        LatLng(37.7759, -122.4184),
        LatLng(37.7749, -122.4184),
      ],
      areaSqMeters: 22000.0,
      capturedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  group('Phase D6: Color Contrast & WCAG Standards', () {
    test('Calculated contrast ratios satisfy WCAG AAA standards', () {
      double contrastRatio(Color fg, Color bg) {
        final l1 = fg.computeLuminance();
        final l2 = bg.computeLuminance();
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Bone on Graphite Deep
      final textOnBg = contrastRatio(AppColors.textPrimary, AppColors.bgDeep);
      expect(
        textOnBg,
        greaterThanOrEqualTo(7.0),
        reason: 'Primary text must exceed WCAG AAA (7.0:1)',
      );

      // Accent (Moss) on Graphite Deep
      final accentOnBg = contrastRatio(AppColors.accent, AppColors.bgDeep);
      expect(
        accentOnBg,
        greaterThanOrEqualTo(4.5),
        reason: 'Accent token must exceed WCAG AA (4.5:1)',
      );

      // Secondary text on Graphite Deep
      final secondaryOnBg = contrastRatio(
        AppColors.textSecondary,
        AppColors.bgDeep,
      );
      expect(
        secondaryOnBg,
        greaterThanOrEqualTo(4.5),
        reason: 'Secondary text must exceed WCAG AA (4.5:1)',
      );
    });
  });

  group('Phase D6: Minimum 48dp Touch Targets Audit', () {
    testWidgets('HoldToFinishButton is >= 48dp height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: HoldToFinishButton(isRunActive: true, onFinish: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(HoldToFinishButton);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('SosShieldButton is >= 48x48dp touch target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(child: SosShieldButton(onTriggerSos: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(SosShieldButton);
      final size = tester.getSize(buttonFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('PermissionPrimerSheet buttons are >= 48dp height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: PermissionPrimerSheet(onAccept: () {}, onDecline: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final primaryBtn = find.byType(FilledButton);
      final size = tester.getSize(primaryBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('Phase D6: Multi-Device Responsive Screens (360x640, 393x852, 412x915)', () {
    const resolutions = [
      Size(360, 640), // Small Android (compact)
      Size(393, 852), // Modern iPhone (standard)
      Size(412, 915), // Modern Android flagship (tall)
    ];

    for (final res in resolutions) {
      testWidgets(
        'HomeScreen at ${res.width.toInt()}x${res.height.toInt()} textScale 1.0 has zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(res);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.0),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: HomeScreen(onStartRun: () {}),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'RunHistoryScreen at ${res.width.toInt()}x${res.height.toInt()} textScale 1.3 has zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(res);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: RunHistoryScreen(
                  initialProfile: testProfile,
                  initialTerritories: testTerritories,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'ProfilePage at ${res.width.toInt()}x${res.height.toInt()} textScale 1.3 has zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(res);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: ProfilePage(
                  initialProfile: testProfile,
                  initialTerritories: testTerritories,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'SummarySheet at ${res.width.toInt()}x${res.height.toInt()} textScale 1.3 has zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(res);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: SummarySheet(
                      distanceKm: 6.25,
                      durationSeconds: 1950,
                      territoriesClaimed: 2,
                      profile: testProfile,
                      coachService: MockCoachService(),
                      routePoints: const [
                        LatLng(37.77, -122.41),
                        LatLng(37.78, -122.41),
                        LatLng(37.78, -122.42),
                      ],
                      areaSqMeters: 35000.0,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'RunGoalSheet at ${res.width.toInt()}x${res.height.toInt()} textScale 1.3 has zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(res);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: res,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(
                  body: SingleChildScrollView(
                    child: RunGoalSheet(currentGoal: RunGoal.none),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group(
    'Phase D6: Accessibility Text Scaling 2.0x (Extreme Accessibility)',
    () {
      testWidgets(
        'RunHud adapts safely without crash or exception at 2.0x scale',
        (tester) async {
          const res = Size(393, 852);
          await tester.binding.setSurfaceSize(res);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: res,
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: RunHud(
                      isRunActive: true,
                      isSearchingGps: false,
                      isAutoPaused: false,
                      distanceKm: 8.4,
                      elapsedSeconds: 2700,
                      movingSeconds: 2600,
                      splitPace: '5:20',
                      currentSpeedKmh: 11.2,
                      satelliteAccuracyMeters: 4.0,
                      territoriesClaimed: 2,
                      currentAreaSqm: 28000.0,
                      onToggleRun: () {},
                      onSealShape: () {},
                      onFinishRun: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('HoldToFinishButton remains accessible at 2.0x scale', (
        tester,
      ) async {
        const res = Size(393, 852);
        await tester.binding.setSurfaceSize(res);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: res,
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(
                  child: HoldToFinishButton(isRunActive: true, onFinish: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    },
  );
}
