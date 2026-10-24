import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/home/widgets/home_header.dart';
import 'package:territory_runner/features/home/widgets/quick_launch_hero.dart';
import 'package:territory_runner/features/home/widgets/weekly_summary_card.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Territory Runner Design System Tokens', () {
    test('AppColors token palette definitions (Graphite + Bone + Moss)', () {
      expect(AppColors.bgDeep, const Color(0xFF0D0E0C));
      expect(AppColors.surface, const Color(0xFF141512));
      expect(AppColors.accent, const Color(0xFFA3C586));
      expect(AppColors.mine, const Color(0xFFA3C586));
      expect(AppColors.rival, const Color(0xFF86A5D3));
      expect(AppColors.warning, const Color(0xFFD9A441));
      expect(AppColors.info, const Color(0xFF9AA4B2));
      expect(AppColors.error, const Color(0xFFE0716B));
      expect(AppColors.success, const Color(0xFFA3C586));
      expect(AppColors.gold, const Color(0xFFCDAE6A));
      expect(AppColors.silver, const Color(0xFFB5B6B0));
      expect(AppColors.bronze, const Color(0xFFB0825A));
    });

    test('AppSpacing scale and radii consistency', () {
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);
      expect(AppSpacing.r8, const Radius.circular(8.0));
      expect(AppSpacing.br16, BorderRadius.circular(16.0));
    });

    test('AppText enforces tabular figures on athletic metrics and timers with Inter', () {
      expect(AppText.statHero.fontFamily, 'Inter');
      expect(
        AppText.statHero.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(AppText.timer.fontFamily, 'Inter');
      expect(
        AppText.timer.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(AppText.body.fontFamily, 'Inter');
    });

    test('Zero unbundled font weights (w500, w800, w900) across lib/ directory', () {
      final libDir = Directory('lib');
      final forbiddenPattern = RegExp(r'FontWeight\.(w500|w800|w900)');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (forbiddenPattern.hasMatch(line)) {
              violations.add('${entity.path}:${i + 1} -> ${line.trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'All typography must map to bundled Inter weights (400/600/700). Found violations:\n${violations.join('\n')}',
      );
    });

    test('Zero raw showSnackBar calls across lib/ directory outside AppToast and AppTheme', () {
      final libDir = Directory('lib');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          if (entity.path.endsWith('app_toast.dart') ||
              entity.path.endsWith('app_theme.dart')) {
            continue;
          }
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains('showSnackBar')) {
              violations.add('${entity.path}:${i + 1} -> ${line.trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'All notifications must route through AppToast.show(). Found raw showSnackBar violations:\n${violations.join('\n')}',
      );
    });
  });

  group('Territory Runner Design System Widgets', () {
    testWidgets('PrimaryButton renders label and triggers tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Claim Territory',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Claim Territory'), findsOneWidget);
      await tester.tap(find.text('Claim Territory'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('StatTile renders title, unit and formatted value', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatTile(
              label: 'Total Distance',
              stringValue: '12.4',
              unit: 'KM',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Total Distance'), findsOneWidget);
      expect(find.text('12.4'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
    });

    testWidgets('AppChip renders and handles tap toggle', (tester) async {
      bool selected = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: AppChip(
                  label: '5:00 PACER',
                  isSelected: selected,
                  onTap: () {
                    setState(() => selected = !selected);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('5:00 PACER'), findsOneWidget);
      await tester.tap(find.text('5:00 PACER'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });

    testWidgets('EmptyState renders icon, title and description', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.map_rounded,
              title: 'No Active Route',
              message: 'Start running to claim your first sector.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.text('No Active Route'), findsOneWidget);
      expect(
        find.text('Start running to claim your first sector.'),
        findsOneWidget,
      );
    });

    testWidgets('NeutralChip renders label and triggers tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeutralChip(
              label: 'GPS lock',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('GPS lock'), findsOneWidget);
      await tester.tap(find.text('GPS lock'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    test('FactionStanding.canonicalFaction aliases Cyber Vanguard and persists cleanly', () {
      expect(FactionStanding.canonicalFaction('Cyber Vanguard'), 'Vanguard');
      expect(FactionStanding.canonicalFaction(null), 'Vanguard');
      expect(FactionStanding.canonicalFaction(''), 'Vanguard');
      expect(FactionStanding.canonicalFaction('Vanguard'), 'Vanguard');
      expect(FactionStanding.canonicalFaction('Iron Syndicate'), 'Syndicate');
      expect(FactionStanding.canonicalFaction('Neon Nomads'), 'Nomads');
    });

    testWidgets('SectionHeader aligns title and action on exact same baseline', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Recent runs',
              actionLabel: 'View all',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Recent runs'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);

      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget);
      final Row row = tester.widget(rowFinder);
      expect(row.crossAxisAlignment, CrossAxisAlignment.baseline);
      expect(row.textBaseline, TextBaseline.alphabetic);

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
    });

    testWidgets('NeutralChip renders with leading widget and handles attention state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NeutralChip(
              label: 'GPS searching',
              needsAttention: true,
              leading: Icon(Icons.gps_fixed, size: 12),
            ),
          ),
        ),
      );

      expect(find.text('GPS searching'), findsOneWidget);
      expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    });

    testWidgets('TerritoryArt renders empty canvas gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TerritoryArt(
              polygons: [],
              height: 200,
            ),
          ),
        ),
      );

      expect(find.byType(TerritoryArt), findsOneWidget);
    });

    testWidgets('TerritoryHeroCard renders area and triggers primary action', (
      tester,
    ) async {
      bool runStarted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerritoryHeroCard(
                territories: const [],
                totalAreaSqm: 125000,
                weeklyGainedAreaSqm: 4500,
                onStartRun: () => runStarted = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Start run'), findsOneWidget);
      expect(find.text('125,000'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Start run'));
      await tester.pumpAndSettle();
      expect(runStarted, isTrue);
    });

    testWidgets('PremiumBottomNav renders 5 destinations and triggers tab switch', (
      tester,
    ) async {
      int activeIndex = 0;
      bool runTapped = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                bottomNavigationBar: PremiumBottomNav(
                  selectedIndex: activeIndex,
                  onTabSelected: (idx) {
                    setState(() => activeIndex = idx);
                  },
                  onStartRun: () => runTapped = true,
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Compete'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(activeIndex, 1);

      await tester.tap(find.byIcon(Icons.directions_run_rounded));
      await tester.pumpAndSettle();
      expect(runTapped, isTrue);
    });

    testWidgets(
      'QuickLaunchHero renders quiet Set a goal row when goal is null and zero fake 3.4km',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await AppPreferences().setDailyGoalKm(null);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: QuickLaunchHero(territories: []),
            ),
          ),
        );

        expect(find.text('Set a goal'), findsOneWidget);
        expect(find.text('3.4'), findsNothing);
        expect(find.text('Start run'), findsOneWidget);
      },
    );

    testWidgets(
      'QuickLaunchHero renders goal ring when dailyGoalKm is set',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await AppPreferences().setDailyGoalKm(5.0);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: QuickLaunchHero(territories: []),
            ),
          ),
        );

        expect(find.text('Daily goal'), findsOneWidget);
        expect(find.text('/ 5.0 km'), findsOneWidget);
        expect(find.text('0.0'), findsOneWidget);
        expect(find.text('3.4'), findsNothing);
      },
    );

    testWidgets(
      'HomeHeader renders level ring avatar and CombinedStatusIndicator without faction or streak chip',
      (tester) async {
        final profile = RunnerProfile(
          id: 'runner-1',
          username: 'ApexRunner',
          level: 4,
          xp: 350,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeHeader(profile: profile),
            ),
          ),
        );

        expect(find.text('ApexRunner'), findsOneWidget);
        expect(find.text('Level 4'), findsOneWidget);
        expect(find.byType(CombinedStatusIndicator), findsOneWidget);
        expect(find.text('Cyber Vanguard'), findsNothing);
        expect(
          find.byIcon(Icons.local_fire_department_rounded),
          findsNothing,
        );
      },
    );

    testWidgets(
      'WeeklySummaryCard displays real empty state when no runs logged',
      (tester) async {
        final profile = RunnerProfile(id: 'r1', username: 'Test');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WeeklySummaryCard(
                profile: profile,
                territories: const [],
              ),
            ),
          ),
        );

        expect(find.text('0.0'), findsOneWidget);
        expect(find.text('0'), findsAtLeastNWidgets(1));
        expect(
          find.text('No runs logged this week. Start a run to begin.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Motion and Toast Performance Budgets', () {
    test('AppMotion durations follow responsive athletic design budgets', () {
      expect(AppMotion.fast.inMilliseconds, lessThanOrEqualTo(150));
      expect(AppMotion.standard.inMilliseconds, lessThanOrEqualTo(250));
      expect(AppMotion.sheet.inMilliseconds, lessThanOrEqualTo(250));
      expect(AppMotion.countUp.inMilliseconds, lessThanOrEqualTo(500));
      expect(AppMotion.capture.inMilliseconds, lessThanOrEqualTo(600));
    });
  });
}


