import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Territory Runner Design System Tokens', () {
    test('AppColors token palette definitions', () {
      expect(AppColors.bgDeep, const Color(0xFF0B0C10));
      expect(AppColors.surface, const Color(0xFF161822));
      expect(AppColors.accent, const Color(0xFF00E676));
      expect(AppColors.mine, const Color(0xFF00E676));
      expect(AppColors.rival, const Color(0xFFFF3366));
      expect(AppColors.warning, const Color(0xFFFFB300));
      expect(AppColors.info, const Color(0xFF00F0FF));
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

    test('AppText enforces tabular figures on athletic metrics and timers', () {
      expect(AppText.statHero.fontFamily, 'Oswald');
      expect(AppText.statHero.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(AppText.timer.fontFamily, 'Oswald');
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
              label: 'CLAIM TERRITORY',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('CLAIM TERRITORY'), findsOneWidget);
      await tester.tap(find.text('CLAIM TERRITORY'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('StatTile renders title, unit and formatted value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatTile(
              label: 'TOTAL DISTANCE',
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
      expect(find.text('NO ACTIVE ROUTE'), findsOneWidget);
      expect(find.text('Start running to claim your first sector.'), findsOneWidget);
    });
  });
}
