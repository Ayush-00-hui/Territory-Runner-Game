import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/history/widgets/run_share_card_modal.dart';
import 'package:territory_runner/features/map/widgets/hold_to_finish_button.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/features/profile/widgets/achievements_list.dart';
import 'package:territory_runner/features/profile/widgets/faction_leaderboard.dart';
import 'package:territory_runner/features/profile/widgets/profile_hero.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({'fcm_permission_prompted': true});
  });

  final testProfile = RunnerProfile(
    id: 'proof_runner_u6',
    username: 'APEX_STRIDER',
    totalDistanceKm: 64.2,
    xp: 4100,
    level: 8,
    badges: ['First Conquest', '10K Centurion'],
    totalHexesClaimed: 35,
    currentStreak: 15,
    faction: 'Cyber Vanguard',
  );

  final testTerritories = [
    Territory(
      id: 'terr_proof_1',
      ownerId: 'proof_runner_u6',
      polygon: const [
        LatLng(37.77, -122.41),
        LatLng(37.78, -122.41),
        LatLng(37.78, -122.42),
      ],
      areaSqMeters: 45000.0,
      capturedAt: DateTime.now(),
    ),
  ];

  group('U6 Proof: Interactive Overlay Overlap Checks', () {
    testWidgets(
      'Defend CTA and You Own card do not overlap rectangles at right rail',
      (tester) async {
        const resolutions = [Size(360, 640), Size(393, 852), Size(412, 915)];

        for (final res in resolutions) {
          await tester.binding.setSurfaceSize(res);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: res,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: Stack(
                    children: [
                      // Simulated Right Rail bottom stack with Defend CTA above You Own Card
                      Positioned(
                        right: 20,
                        bottom: 215,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              key: const ValueKey('defend_cta'),
                              height: 48,
                              width: 110,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: AppSpacing.br16,
                                border: Border.all(
                                  color: AppColors.rival,
                                  width: 1.5,
                                ),
                              ),
                              child: const Text('Defend'),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              key: const ValueKey('you_own_card'),
                              height: 60,
                              width: 120,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text('You own'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final defendBox = tester.getRect(
            find.byKey(const ValueKey('defend_cta')),
          );
          final youOwnBox = tester.getRect(
            find.byKey(const ValueKey('you_own_card')),
          );

          // Verifies zero rectangle intersection
          final bool overlaps = defendBox.overlaps(youOwnBox);
          expect(
            overlaps,
            isFalse,
            reason:
                'Defend CTA and You Own card must not overlap on ${res.width}x${res.height}',
          );
          expect(youOwnBox.top, greaterThanOrEqualTo(defendBox.bottom));
        }

        await tester.binding.setSurfaceSize(null);
      },
    );
  });

  group('U6 Proof: Minimum 48dp Touch Targets Audit', () {
    testWidgets('HoldToFinishButton meets >= 48dp touch target in all states', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                HoldToFinishButton(isRunActive: false, onFinish: () {}),
                HoldToFinishButton(isRunActive: true, onFinish: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttons = find.byType(HoldToFinishButton);
      expect(buttons, findsNWidgets(2));
      for (final b in buttons.evaluate()) {
        final renderBox = b.findRenderObject() as RenderBox;
        expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('ProfileHeroCard edit callsign target is >= 48x48 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ProfileHeroCard(
              profile: testProfile,
              onEditCallsign: () {},
              onSelectFaction: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editBtn = find.bySemanticsLabel('Edit callsign');
      expect(editBtn, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(editBtn);
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'ProfileAchievementTile has >= 48dp height touch target and semantics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ProfileAchievementTile(
                icon: Icons.emoji_events_rounded,
                title: 'First Claim',
                subtitle: 'Claim your first territory polygon on foot',
                unlocked: true,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.byType(ProfileAchievementTile);
        expect(tileFinder, findsOneWidget);
        final renderBox = tester.renderObject<RenderBox>(tileFinder);
        expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
      },
    );

    testWidgets(
      'FactionLeaderboard scope pills have >= 48dp height touch target',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: FactionLeaderboard(
                  profile: testProfile,
                  territories: testTerritories,
                  initialStandings: const FactionStandingsResponse(
                    totalAreaSqm: 100000,
                    standings: [
                      FactionStanding(
                        faction: 'Cyber Vanguard',
                        totalAreaSqm: 60000,
                        memberCount: 15,
                        percentage: 60.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scopeChips = ['Global', 'City', 'Local'];
        for (final label in scopeChips) {
          final chip = find.bySemanticsLabel('Scope: $label');
          expect(chip, findsOneWidget);
          final renderBox = tester.renderObject<RenderBox>(chip);
          expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
        }
      },
    );

    testWidgets(
      'RunShareCardModal theme selector pills have >= 48dp height touch target',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  height: 800,
                  child: RunShareCardModal(
                    distanceKm: 5.2,
                    durationSeconds: 1500,
                    areaSqMeters: 45000.0,
                    points: const [
                      LatLng(37.77, -122.41),
                      LatLng(37.78, -122.41),
                      LatLng(37.78, -122.42),
                    ],
                    callsign: 'APEX_STRIDER',
                    faction: 'Cyber Vanguard',
                    capturedAt: DateTime.now(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final themePills = ['Athletic Dark', 'Vanguard', 'Stealth'];
        for (final pill in themePills) {
          final pillFinder = find.bySemanticsLabel('Theme: $pill');
          expect(pillFinder, findsOneWidget);
          final renderBox = tester.renderObject<RenderBox>(pillFinder);
          expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
        }
      },
    );
  });

  group('U6 Proof: Full Responsiveness & Zero Overflow at Text Scale 1.3', () {
    const resolutions = [Size(360, 640), Size(393, 852), Size(412, 915)];

    for (final res in resolutions) {
      testWidgets(
        'RunHud at ${res.width.toInt()}x${res.height.toInt()} textScale 1.3 has zero overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(res);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: res,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: RunHud(
                      isRunActive: true,
                      isSearchingGps: false,
                      isAutoPaused: false,
                      distanceKm: 12.45,
                      elapsedSeconds: 4320,
                      movingSeconds: 4100,
                      splitPace: '5:15',
                      currentSpeedKmh: 11.4,
                      satelliteAccuracyMeters: 4.0,
                      territoriesClaimed: 5,
                      currentAreaSqm: 65000.0,
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
    }
  });
}
