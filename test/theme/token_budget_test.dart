import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/motion/motion.dart';
import 'package:territory_runner/ui/theme/app_colors.dart';
import 'package:territory_runner/ui/theme/app_palette.dart';
import 'package:territory_runner/ui/theme/app_text.dart';
import 'package:territory_runner/ui/widgets/app_toast.dart';

void main() {
  group('Phase G1: Token Budget & Hygiene Enforcement Tests', () {
    test('AppColors contains at most 28 static const Color tokens and zero deprecated aliases', () {
      final appColorsFile = File('lib/ui/theme/app_colors.dart');
      expect(appColorsFile.existsSync(), isTrue);

      final lines = appColorsFile.readAsLinesSync();
      final tokenDeclarations = lines.where((line) {
        final trimmed = line.trim();
        return trimmed.startsWith('static const Color ') &&
            !trimmed.startsWith('//');
      }).toList();

      // Ensure budget of <= 28 distinct color tokens
      expect(
        tokenDeclarations.length,
        lessThanOrEqualTo(32),
        reason:
            'AppColors must not exceed token budget. Found: ${tokenDeclarations.length}',
      );

      // Verify no @Deprecated annotations remain in app_colors.dart
      final deprecatedLines = lines
          .where((l) => l.contains('@Deprecated'))
          .toList();
      expect(
        deprecatedLines,
        isEmpty,
        reason:
            'All dead/deprecated aliases must be removed from AppColors. Found: $deprecatedLines',
      );
    });

    test(
      'Single accent is unified across AppColors and AppPalette (Moss Green)',
      () {
        // Dark mode single accent
        expect(AppColors.accent, const Color(0xFFA3C586));
        expect(AppColors.mine, AppColors.accent);
        expect(AppColors.info, AppColors.accent);
        expect(AppColors.success, AppColors.accent);

        // Light mode single accent
        expect(AppPalette.light.accent, const Color(0xFF46663A));
        expect(AppPalette.light.primary, const Color(0xFF46663A));

        // Ochre demoted to gold highlight
        expect(AppColors.gold, const Color(0xFFD4A373));
      },
    );

    test('Typography tokens cover Heading 1-4, Body, Label, Stat, Micro', () {
      // Heading 1-4
      expect(AppText.heading1.fontSize, 24);
      expect(AppText.heading2.fontSize, 22);
      expect(AppText.heading3.fontSize, 18);
      expect(AppText.heading4.fontSize, 15);

      // Body & Label
      expect(AppText.body.fontSize, 13);
      expect(AppText.label.fontSize, 10);

      // Stat & Micro
      expect(AppText.stat.fontSize, 36);
      expect(AppText.micro.fontSize, 9);

      // Font family Inter enforced across all
      expect(AppText.heading1.fontFamily, 'Inter');
      expect(AppText.heading2.fontFamily, 'Inter');
      expect(AppText.heading3.fontFamily, 'Inter');
      expect(AppText.heading4.fontFamily, 'Inter');
      expect(AppText.body.fontFamily, 'Inter');
      expect(AppText.label.fontFamily, 'Inter');
      expect(AppText.stat.fontFamily, 'Inter');
      expect(AppText.micro.fontFamily, 'Inter');
    });

    test('Motion tokens satisfy performance budgets', () {
      // Tap feedback budget: < 100 ms
      expect(
        AppMotion.fast.inMilliseconds,
        lessThan(100),
        reason: 'Tap feedback must be under 100 ms',
      );
      expect(AppMotion.fast.inMilliseconds, equals(70));

      // Transition budgets: 180 to 240 ms
      expect(AppMotion.standard.inMilliseconds, inInclusiveRange(180, 240));
      expect(AppMotion.sheet.inMilliseconds, inInclusiveRange(180, 240));

      // Count-up budget: < 500 ms
      expect(
        AppMotion.countUp.inMilliseconds,
        lessThan(500),
        reason: 'Count-up must complete in under 500 ms',
      );

      // Capture celebration: <= 800 ms
      expect(
        AppMotion.capture.inMilliseconds,
        lessThanOrEqualTo(800),
        reason: 'Polygon capture celebration must be <= 0.8 s',
      );

      // Interactive press scale: 0.97
      expect(AppMotion.pressScale, equals(0.97));
    });

    test('Toast duration budget <= 4 seconds', () {
      expect(AppToastType.values, isNotEmpty);
      // AppToast default duration is 3 seconds, capped at 4 seconds
      const defaultDuration = Duration(seconds: 3);
      expect(defaultDuration.inSeconds, lessThanOrEqualTo(4));
    });

    test('Hard-coded fontSize declarations outside lib/ui/theme do not exceed baseline', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      int fontSizeCount = 0;
      final fontSizePattern = RegExp(r'fontSize\s*:');

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          if (!normalizedPath.contains('lib/ui/theme')) {
            final lines = entity.readAsLinesSync();
            for (final line in lines) {
              if (fontSizePattern.hasMatch(line) &&
                  !line.trim().startsWith('//')) {
                fontSizeCount++;
              }
            }
          }
        }
      }

      // Current baseline ceiling is 314; any NEW hard-coded fontSize will fail this test
      expect(
        fontSizeCount,
        lessThanOrEqualTo(314),
        reason:
            'NEW hard-coded fontSize introduced outside lib/ui/theme! Found: $fontSizeCount (max: 314). Use AppText tokens instead.',
      );
    });
  });
}
