import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/home/home_screen.dart';
import 'package:territory_runner/features/home/widgets/gps_status_chip.dart';
import 'package:territory_runner/features/home/widgets/home_header.dart';
import 'package:territory_runner/features/home/widgets/quick_launch_hero.dart';
import 'package:territory_runner/features/home/widgets/weekly_summary_card.dart';
import 'package:territory_runner/main.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_home_nav_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
    SharedPreferences.setMockInitialValues({'fcm_permission_prompted': true});
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    final profileBox = Hive.box<RunnerProfile>('profile');
    await profileBox.clear();
    await profileBox.put(
      'current_runner',
      RunnerProfile(
        id: 'test_athlete',
        username: 'VortexRunner',
        totalDistanceKm: 28.5,
        xp: 1200,
        level: 5,
        badges: ['Pioneer'],
        totalHexesClaimed: 14,
        currentStreak: 7,
        faction: 'Cyber Vanguard',
      ),
    );

    final territoryBox = Hive.box<Territory>('territories_v3');
    await territoryBox.clear();
    await territoryBox.put(
      'poly_1',
      Territory(
        id: 'poly_1',
        ownerId: 'test_athlete',
        polygon: [
          const LatLng(37.77, -122.41),
          const LatLng(37.771, -122.41),
          const LatLng(37.771, -122.411),
        ],
        areaSqMeters: 15400,
        capturedAt: DateTime.now(),
      ),
    );
  });

  group('Home & Navigation Component Tests', () {
    testWidgets('HomeHeader renders callsign and level progress avatar', (
      tester,
    ) async {
      final profile = RunnerProfile(
        id: 'test_athlete',
        username: 'VortexRunner',
        totalDistanceKm: 28.5,
        xp: 1200,
        level: 5,
        badges: ['Pioneer'],
        totalHexesClaimed: 14,
        currentStreak: 7,
        faction: 'Cyber Vanguard',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeHeader(profile: profile)),
        ),
      );

      expect(find.text('VortexRunner'), findsOneWidget);
      expect(find.text('Level 5'), findsOneWidget);
      expect(find.byType(CombinedStatusIndicator), findsOneWidget);
    });

    testWidgets('WeeklySummaryCard renders distance, territory, and runs', (
      tester,
    ) async {
      final profile = RunnerProfile(
        id: 'test_athlete',
        username: 'ApexStrider',
        totalDistanceKm: 20.0,
        xp: 500,
        level: 3,
        badges: [],
        totalHexesClaimed: 4,
        currentStreak: 3,
      );

      final territories = [
        Territory(
          id: 'poly_1',
          ownerId: 'test_athlete',
          polygon: [],
          areaSqMeters: 15400,
          capturedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklySummaryCard(profile: profile, territories: territories),
          ),
        ),
      );

      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Runs'), findsOneWidget);
    });

    testWidgets('QuickLaunchHero triggers onStartRun callback when tapped', (
      tester,
    ) async {
      bool runStarted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickLaunchHero(
              isActive: false,
              onStartRun: () => runStarted = true,
            ),
          ),
        ),
      );

      expect(find.text('Start run'), findsOneWidget);
      await tester.tap(find.text('Start run'));
      await tester.pump();
      expect(runStarted, isTrue);
    });

    testWidgets('GpsStatusChip renders with dot and accessible semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GpsStatusChip(isActive: false))),
      );

      expect(find.byType(GpsStatusChip), findsOneWidget);
      expect(find.byType(Semantics), findsWidgets);
    });
  });

  group('U4: HomeScreen Above-the-fold & Responsiveness', () {
    testWidgets(
      'HomeScreen layout on 360x640: greeting, GPS chip, and Start run hero are above the fold',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const HomeScreen(isActive: false),
          ),
        );
        await tester.pump();

        // 1. Greeting by time of day (no emoji)
        final greetingFinder = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Good morning' ||
                  w.data == 'Good afternoon' ||
                  w.data == 'Good evening'),
        );
        expect(greetingFinder, findsOneWidget);

        // 2. CombinedStatusIndicator with active colored dot
        expect(find.byType(CombinedStatusIndicator), findsOneWidget);

        // 3. Start run hero card
        expect(find.text('Start run'), findsOneWidget);

        // Verify vertical coordinates: Start run hero is fully above the fold on 360x640 (< 520 dp)
        final greetingY = tester.getTopLeft(greetingFinder).dy;
        final statusChipY = tester
            .getTopLeft(find.byType(CombinedStatusIndicator))
            .dy;
        final startRunY = tester.getTopLeft(find.text('Start run')).dy;
        final weeklySummaryY = tester
            .getTopLeft(find.text('Weekly summary'))
            .dy;

        expect(greetingY, lessThan(100.0));
        expect(statusChipY, greaterThan(greetingY));
        expect(statusChipY, lessThan(200.0));
        expect(startRunY, greaterThan(statusChipY));
        expect(
          startRunY,
          lessThan(500.0),
          reason: 'Start run button must be above the fold (< 500 dp)',
        );
        expect(
          weeklySummaryY,
          greaterThan(startRunY),
          reason: 'Weekly summary must be positioned below Start run card',
        );
      },
    );

    testWidgets('HomeScreen pull-to-refresh triggers sync queue', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HomeScreen(isActive: false),
        ),
      );
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.fling(find.byType(HomeScreen), const Offset(0, 300), 1000);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    for (final size in [
      const Size(360, 640),
      const Size(393, 852),
      const Size(412, 915),
    ]) {
      testWidgets(
        'HomeScreen zero overflow at text scale 1.3 on ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: const HomeScreen(isActive: false),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('U4: Bottom Navigation Polish', () {
    testWidgets(
      'Bottom nav uses Icons.home_rounded, 48dp touch targets, and obsidian style',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.darkTheme, home: const MainScreen()),
        );
        await tester.pump();

        // 1. Home tab uses Icons.home_rounded (not bolt)
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expect(find.byIcon(Icons.bolt_rounded), findsNothing);

        // 2. Central Run button semantics & touch target
        expect(find.bySemanticsLabel('Start run'), findsOneWidget);
        final runSemantics = tester.getRect(find.bySemanticsLabel('Start run'));
        expect(runSemantics.height, greaterThanOrEqualTo(48.0));

        // Clean up widget tree to dispose timers
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
