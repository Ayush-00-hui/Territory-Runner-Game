import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Territory Runner Design System Tokens', () {
    test('AppColors token palette definitions (Charcoal + Ember)', () {
      expect(AppColors.bgDeep, const Color(0xFF0C0B0A));
      expect(AppColors.surface, const Color(0xFF151413));
      expect(AppColors.accent, const Color(0xFFFF6A3D));
      expect(AppColors.mine, const Color(0xFFFF6A3D));
      expect(AppColors.rival, const Color(0xFF6EA8FE));
      expect(AppColors.warning, const Color(0xFFF2B84B));
      expect(AppColors.info, const Color(0xFF9B8CFF));
      expect(AppColors.error, const Color(0xFFF2677A));
      expect(AppColors.success, const Color(0xFF5FCB8C));
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
      expect(AppText.statHero.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(AppText.timer.fontFamily, 'Inter');
      expect(AppText.timer.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(AppText.body.fontFamily, 'Inter');
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

    testWidgets('StatTile renders title, unit and formatted value', (tester) async {
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
      expect(find.text('TOTAL DISTANCE'), findsOneWidget);
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

    testWidgets('EmptyState renders icon, title and description', (tester) async {
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
      expect(find.text('Start running to claim your first sector.'), findsOneWidget);
    });
  });
}
