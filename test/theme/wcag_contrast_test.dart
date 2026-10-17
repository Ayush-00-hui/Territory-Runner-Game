import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/theme/app_colors.dart';

/// Calculates WCAG 2.1 relative luminance for an sRGB color.
double _calculateLuminance(Color color) {
  double channelLuminance(double channel) {
    if (channel <= 0.04045) {
      return channel / 12.92;
    } else {
      return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  final r = channelLuminance(color.r);
  final g = channelLuminance(color.g);
  final b = channelLuminance(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculates WCAG 2.1 contrast ratio between two colors (range: 1.0 to 21.0).
double _calculateContrast(Color foreground, Color background) {
  final l1 = _calculateLuminance(foreground);
  final l2 = _calculateLuminance(background);

  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA Contrast Ratios for Ink + Pacer Blue Palette', () {
    test('Body text contrast >= 4.5:1 on surfaces', () {
      final textPrimaryOnSurface = _calculateContrast(AppColors.textPrimary, AppColors.surface);
      final textPrimaryOnSurface2 = _calculateContrast(AppColors.textPrimary, AppColors.surface2);
      final textSecondaryOnSurface = _calculateContrast(AppColors.textSecondary, AppColors.surface);
      final textSecondaryOnSurface2 = _calculateContrast(AppColors.textSecondary, AppColors.surface2);

      expect(textPrimaryOnSurface, greaterThanOrEqualTo(4.5),
          reason: 'textPrimary ($textPrimaryOnSurface:1) must meet WCAG AA body contrast on surface');
      expect(textPrimaryOnSurface2, greaterThanOrEqualTo(4.5),
          reason: 'textPrimary ($textPrimaryOnSurface2:1) must meet WCAG AA body contrast on surface2');
      expect(textSecondaryOnSurface, greaterThanOrEqualTo(4.5),
          reason: 'textSecondary ($textSecondaryOnSurface:1) must meet WCAG AA body contrast on surface');
      expect(textSecondaryOnSurface2, greaterThanOrEqualTo(4.5),
          reason: 'textSecondary ($textSecondaryOnSurface2:1) must meet WCAG AA body contrast on surface2');
    });

    test('onAccent on accent contrast >= 4.5:1', () {
      final onAccentOnAccent = _calculateContrast(AppColors.onAccent, AppColors.accent);
      expect(onAccentOnAccent, greaterThanOrEqualTo(4.5),
          reason: 'onAccent ($onAccentOnAccent:1) must meet WCAG AA on accent fill');
    });

    test('Large text, muted text and UI icons contrast >= 3.0:1', () {
      final textMutedOnSurface = _calculateContrast(AppColors.textMuted, AppColors.surface);
      final accentOnSurface = _calculateContrast(AppColors.accent, AppColors.surface);
      final rivalOnSurface = _calculateContrast(AppColors.rival, AppColors.surface);
      final warningOnSurface = _calculateContrast(AppColors.warning, AppColors.surface);
      final errorOnSurface = _calculateContrast(AppColors.error, AppColors.surface);
      final successOnSurface = _calculateContrast(AppColors.success, AppColors.surface);
      final infoOnSurface = _calculateContrast(AppColors.info, AppColors.surface);

      expect(textMutedOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'textMuted ($textMutedOnSurface:1) must meet WCAG AA large/secondary contrast on surface');
      expect(accentOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'accent ($accentOnSurface:1) must meet WCAG AA graphical UI contrast on surface');
      expect(rivalOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'rival ($rivalOnSurface:1) must meet WCAG AA graphical UI contrast on surface');
      expect(warningOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'warning ($warningOnSurface:1) must meet WCAG AA graphical UI contrast on surface');
      expect(errorOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'error ($errorOnSurface:1) must meet WCAG AA graphical UI contrast on surface');
      expect(successOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'success ($successOnSurface:1) must meet WCAG AA graphical UI contrast on surface');
      expect(infoOnSurface, greaterThanOrEqualTo(3.0),
          reason: 'info ($infoOnSurface:1) must meet WCAG AA graphical UI contrast on surface');
    });
  });
}
