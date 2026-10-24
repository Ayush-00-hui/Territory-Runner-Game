import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/history/widgets/history_run_card.dart';
import 'package:territory_runner/features/map/widgets/hold_to_finish_button.dart';
import 'package:territory_runner/features/profile/widgets/challenges_shelf.dart';
import 'package:territory_runner/features/profile/widgets/faction_leaderboard.dart';
import 'package:territory_runner/features/profile/widgets/weekly_league_view.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/leaderboard_entry.dart';
import 'package:territory_runner/models/league_standing.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Phase 5 Accessibility & Reduced Motion Tests', () {
    testWidgets(
      'AppMotion honors reduced motion flag and collapses durations to zero',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  final isReduced = AppMotion.shouldReduceMotion(context);
                  final duration = AppMotion.duration(
                    context,
                    const Duration(milliseconds: 250),
                  );
                  return Scaffold(
                    body: Center(
                      child: Text(
                        'reduced=$isReduced, duration=${duration.inMilliseconds}ms',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('reduced=true, duration=0ms'), findsOneWidget);
      },
    );

    testWidgets(
      'AppMotion sharedAxisTransition returns child directly when animations are disabled',
      (tester) async {
        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    body: AppMotion.sharedAxisTransition(
                      context: context,
                      animation: controller,
                      child: const Text('Direct Content'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Direct Content'), findsOneWidget);
      },
    );

    testWidgets(
      'PrimaryButton and SecondaryButton meet minimum 48px touch target height',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Column(
                children: [
                  PrimaryButton(label: 'Action', onPressed: () {}),
                  const SizedBox(height: 12),
                  SecondaryButton(label: 'Cancel', onPressed: () {}),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final primarySize = tester.getSize(find.byType(PrimaryButton));
        final secondarySize = tester.getSize(find.byType(SecondaryButton));

        expect(primarySize.height, greaterThanOrEqualTo(48.0));
        expect(secondarySize.height, greaterThanOrEqualTo(48.0));
      },
    );
  });

  group(
    'Phase 5 Small Screen Overflow & Responsiveness Tests (320px width)',
    () {
      testWidgets(
        'WeeklyLeagueView renders on 320px narrow screen without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final mockStanding = LeagueStanding(
            userId: 'u1',
            username: 'NarrowRunner',
            faction: 'Cyber Vanguard',
            tier: 'Gold',
            rank: 1,
            totalParticipants: 5,
            weeklyAreaSqm: 12500,
            weeklyRuns: 3,
            promotionRankCutoff: 1,
            relegationRankCutoff: 4,
            resetAt: DateTime.now().add(const Duration(days: 2)),
            secondsUntilReset: 172800,
            standings: const [
              LeagueParticipant(
                rank: 1,
                userId: 'u1',
                username: 'NarrowRunner',
                faction: 'Cyber Vanguard',
                tier: 'Gold',
                weeklyAreaSqm: 12500,
                weeklyRuns: 3,
                isCurrentUser: true,
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WeeklyLeagueView(initialStanding: mockStanding),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Gold Division'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'FactionLeaderboard renders on 320px narrow screen without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final profile = RunnerProfile(
            id: 'u1',
            username: 'NarrowAthlete',
            totalDistanceKm: 12.0,
            xp: 500,
            level: 2,
            badges: ['First Conquest'],
            totalHexesClaimed: 2,
            currentStreak: 3,
            faction: 'Cyber Vanguard',
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: FactionLeaderboard(
                    profile: profile,
                    territories: const <Territory>[],
                    initialStandings: const FactionStandingsResponse(
                      totalAreaSqm: 50000,
                      standings: [
                        FactionStanding(
                          faction: 'Cyber Vanguard',
                          totalAreaSqm: 30000,
                          memberCount: 5,
                          percentage: 60,
                        ),
                        FactionStanding(
                          faction: 'Iron Syndicate',
                          totalAreaSqm: 20000,
                          memberCount: 3,
                          percentage: 40,
                        ),
                      ],
                    ),
                    initialLeaderboard: const [
                      LeaderboardEntry(
                        rank: 1,
                        userId: 'u1',
                        username: 'NarrowAthlete',
                        faction: 'Cyber Vanguard',
                        totalAreaSqm: 30000,
                        level: 2,
                        totalRuns: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Team Standings'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'ChallengesShelf renders on 320px narrow screen without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final profile = RunnerProfile(
            id: 'u1',
            username: 'NarrowAthlete',
            totalDistanceKm: 5.0,
            xp: 200,
            level: 1,
            badges: const [],
            totalHexesClaimed: 1,
            currentStreak: 1,
            faction: 'Cyber Vanguard',
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ChallengesShelf(
                    profile: profile,
                    territoriesCount: 1,
                    totalAreaSqMeters: 5000,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Active territory quests'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'HistoryRunCard renders on 320px narrow screen without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final sampleTerritory = Territory(
            id: 't_hist_1',
            ownerId: 'u1',
            polygon: const [
              LatLng(37.77, -122.41),
              LatLng(37.78, -122.41),
              LatLng(37.78, -122.42),
            ],
            areaSqMeters: 18500.0,
            capturedAt: DateTime.now(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HistoryRunCard(
                    territory: sampleTerritory,
                    callsign: 'NarrowRunner',
                    faction: 'Cyber Vanguard',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Closed loop'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'HoldToFinishButton renders on 320px screen without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

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

          expect(find.text('Hold to finish'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'AppIconButton satisfies >= 48x48 dp hit target, tooltip, and semantics label',
        (tester) async {
          bool tapped = false;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(
                  child: AppIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Tools',
                    semanticLabel: 'Open tools',
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final btnFinder = find.byType(AppIconButton);
          expect(btnFinder, findsOneWidget);

          final renderBox = tester.renderObject<RenderBox>(btnFinder);
          expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
          expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

          expect(find.byTooltip('Tools'), findsOneWidget);
          expect(find.bySemanticsLabel('Open tools'), findsOneWidget);

          await tester.tap(btnFinder);
          expect(tapped, isTrue);
        },
      );
    },
  );
}
