import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Territory Runner Design System Tokens', () {
    test('AppColors token palette definitions (Ink + Pacer Blue)', () {
      expect(AppColors.bgDeep, const Color(0xFF090B0F));
      expect(AppColors.surface, const Color(0xFF12151B));
      expect(AppColors.accent, const Color(0xFF4C8DFF));
      expect(AppColors.mine, const Color(0xFF4C8DFF));
      expect(AppColors.rival, const Color(0xFFFF7A59));
      expect(AppColors.warning, const Color(0xFFF5B544));
      expect(AppColors.info, const Color(0xFF94A3B8));
      expect(AppColors.error, const Color(0xFFF2677A));
      expect(AppColors.success, const Color(0xFF4FD1A5));
      expect(AppColors.gold, const Color(0xFFD9B45B));
      expect(AppColors.silver, const Color(0xFFB8BCC4));
      expect(AppColors.bronze, const Color(0xFFB98558));
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
          if (entity.path.endsWith('app_toast.dart') || entity.path.endsWith('app_theme.dart')) {
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
  });
}
