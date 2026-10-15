import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Phase 5: Polish & Proof - Contrast, Motion, Typography & Offline Audits', () {
    test('WCAG Contrast & Color Palette Verification', () {
      // Helper function to calculate relative luminance
      double luminance(Color color) {
        return color.computeLuminance();
      }

      // Helper function to calculate contrast ratio between foreground and background
      double contrastRatio(Color fg, Color bg) {
        final l1 = luminance(fg);
        final l2 = luminance(bg);
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Base backgrounds
      const bgDeep = AppColors.bgDeep; // #0B0C10
      const surface = AppColors.surface; // #161822

      // Neon Accent & Semantic Status Colors against deep dark bg
      final accentContrastBg = contrastRatio(AppColors.accent, bgDeep);
      final infoContrastBg = contrastRatio(AppColors.info, bgDeep);
      final warningContrastBg = contrastRatio(AppColors.warning, bgDeep);
      final rivalContrastBg = contrastRatio(AppColors.rival, bgDeep);
      final textPrimaryContrastBg = contrastRatio(AppColors.textPrimary, bgDeep);

      // Verify WCAG AA Large (>3.0) and Normal (>4.5) minimum requirements
      expect(accentContrastBg, greaterThan(7.0), reason: 'Accent must exceed WCAG AAA (7.0)');
      expect(infoContrastBg, greaterThan(7.0), reason: 'Info cyan must exceed WCAG AAA (7.0)');
      expect(warningContrastBg, greaterThan(7.0), reason: 'Warning amber must exceed WCAG AAA (7.0)');
      expect(rivalContrastBg, greaterThan(4.5), reason: 'Rival coral must exceed WCAG AA (4.5)');
      expect(textPrimaryContrastBg, greaterThan(10.0), reason: 'Primary white text on deep bg is ultra crisp');

      // Check contrast against surface cards
      final accentContrastSurface = contrastRatio(AppColors.accent, surface);
      final textPrimaryContrastSurface = contrastRatio(AppColors.textPrimary, surface);
      expect(accentContrastSurface, greaterThan(6.0));
      expect(textPrimaryContrastSurface, greaterThan(8.0));
    });

    test('Athletic Typography enforces Tabular Figures on big metric stats', () {
      // Big bold athletic numbers must have tabular figures to prevent timer & distance jitter
      final statLarge = AppText.statLarge;
      final statMedium = AppText.statMedium;
      final statDisplay = AppText.statDisplay;

      expect(statLarge.fontFamily, 'Oswald');
      expect(statMedium.fontFamily, 'Oswald');
      expect(statDisplay.fontFamily, 'Oswald');

      // Verify tabular figures font feature is applied
      expect(statLarge.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(statMedium.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(statDisplay.fontFeatures, contains(const FontFeature.tabularFigures()));

      // Body typography uses clean sans-serif Inter
      expect(AppText.bodyMedium.fontFamily, 'Inter');
      expect(AppText.bodySmall.fontFamily, 'Inter');
    });

    test('Offline-first asset audit: verified physical presence of bundled fonts', () {
      final requiredFonts = [
        'assets/fonts/Inter-Regular.ttf',
        'assets/fonts/Inter-SemiBold.ttf',
        'assets/fonts/Inter-Bold.ttf',
        'assets/fonts/Oswald-Medium.ttf',
        'assets/fonts/Oswald-Bold.ttf',
      ];

      for (final fontPath in requiredFonts) {
        final file = File(fontPath);
        expect(file.existsSync(), isTrue, reason: 'Font file $fontPath must exist locally for 100% offline runners');
        expect(file.lengthSync(), greaterThan(10000), reason: 'Font file $fontPath must be a valid non-empty TTF');
      }
    });

    testWidgets('AppMotion respects reduced motion user preferences', (tester) async {
      late BuildContext capturedContext;

      // Normal mode (animations enabled)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AppMotion.shouldReduceMotion(capturedContext), isFalse);
      expect(AppMotion.duration(capturedContext, AppMotion.standard), AppMotion.standard);
      expect(AppMotion.duration(capturedContext, AppMotion.capture), AppMotion.capture);

      // Accessibility mode (animations disabled / reduced motion)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AppMotion.shouldReduceMotion(capturedContext), isTrue);
      expect(AppMotion.duration(capturedContext, AppMotion.standard), Duration.zero);
      expect(AppMotion.duration(capturedContext, AppMotion.capture), Duration.zero);
    });

    test('Spacing and Radii design scale consistency', () {
      // 4/8/12/16/24/32 scale
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);

      // Radii scale
      expect(AppSpacing.r8.x, 8.0);
      expect(AppSpacing.r16.x, 16.0);
      expect(AppSpacing.r24.x, 24.0);
      expect(AppSpacing.rFull.x, 999.0);
    });
  });
}
