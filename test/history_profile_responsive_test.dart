import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/features/profile/widgets/profile_hero.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/profile_page.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({'fcm_permission_prompted': true});
  });

  final testProfile = RunnerProfile(
    id: 'athlete_test_u5',
    username: 'STRIDE_COMMANDER',
    totalDistanceKm: 42.195,
    xp: 3200,
    level: 7,
    badges: ['First Conquest', '10K Centurion'],
    totalHexesClaimed: 24,
    currentStreak: 12,
    faction: 'Cyber Vanguard',
  );

  final List<Territory> testTerritories = [
    Territory(
      id: 'terr_recent',
      ownerId: 'athlete_test_u5',
      polygon: const [
        LatLng(37.7749, -122.4194),
        LatLng(37.7759, -122.4194),
        LatLng(37.7759, -122.4184),
        LatLng(37.7749, -122.4184),
      ],
      areaSqMeters: 14500.0,
      capturedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Territory(
      id: 'terr_last_week',
      ownerId: 'athlete_test_u5',
      polygon: const [
        LatLng(37.7849, -122.4294),
        LatLng(37.7859, -122.4294),
        LatLng(37.7859, -122.4284),
        LatLng(37.7849, -122.4284),
      ],
      areaSqMeters: 28000.0,
      capturedAt: DateTime.now().subtract(const Duration(days: 9)),
    ),
  ];

  group('U5: History Screen Tests', () {
    testWidgets(
      'renders filter chips, chronological groups and archive metrics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: RunHistoryScreen(
              initialProfile: testProfile,
              initialTerritories: testTerritories,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top metrics
        expect(find.text('Run history'), findsOneWidget);
        expect(find.text('Total area'), findsOneWidget);
        expect(find.text('Conquests'), findsOneWidget);

        // Filter chips
        expect(find.text('All runs'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('Claims'), findsOneWidget);
        expect(find.text('This week'), findsOneWidget);
        expect(find.text('This month'), findsOneWidget);

        // Chronological headers
        expect(find.text('Current week'), findsOneWidget);
        expect(find.text('Last week'), findsOneWidget);

        // Tap Loops filter
        await tester.tap(find.text('Loops'));
        await tester.pumpAndSettle();

        // Tap Claims filter
        await tester.tap(find.text('Claims'));
        await tester.pumpAndSettle();

        // Clean up
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'empty state displays calm sentence-case copy and reset filter action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: RunHistoryScreen(
              initialProfile: testProfile,
              initialTerritories: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No runs in range'), findsOneWidget);
        expect(
          find.text(
            'Try changing your filters or start a new run to claim territory.',
          ),
          findsOneWidget,
        );

        // Clean up
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('U5: Profile Screen Tests', () {
    testWidgets('ProfileHeroCard has >= 48dp edit touch target and semantics', (
      tester,
    ) async {
      bool editTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ProfileHeroCard(
              profile: testProfile,
              onEditCallsign: () => editTapped = true,
              onSelectFaction: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Callsign and faction displayed
      expect(find.text('STRIDE_COMMANDER'), findsOneWidget);
      expect(find.text('Cyber Vanguard'), findsOneWidget);

      // Edit callsign button has Semantics and >= 48dp touch target
      final editButtonFinder = find.bySemanticsLabel('Edit callsign');
      expect(editButtonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(editButtonFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(editButtonFinder);
      expect(editTapped, isTrue);

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Badges grid has zero emojis in unlock status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProfilePage(
            initialProfile: testProfile,
            initialTerritories: testTerritories,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no trophy emoji
      expect(find.textContaining('🏆'), findsNothing);

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ProfileSettingsList renders Export run data option', (
      tester,
    ) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Export run data'), findsOneWidget);
      expect(
        find.text('Export GPS tracks and claimed territory as GeoJSON or GPX'),
        findsOneWidget,
      );

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('U5: Responsiveness across 360x640, 393x852, 412x915 at text scale 1.3', () {
    const screenSizes = [Size(360, 640), Size(393, 852), Size(412, 915)];

    for (final size in screenSizes) {
      testWidgets(
        'RunHistoryScreen at ${size.width.toInt()}x${size.height.toInt()} textScale 1.3 has no overflow',
        (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
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

          // Clean up
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        'ProfilePage at ${size.width.toInt()}x${size.height.toInt()} textScale 1.3 has no overflow',
        (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
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

          // Clean up
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });
}
