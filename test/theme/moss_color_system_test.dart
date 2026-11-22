import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/map/widgets/map_layers.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/ui/theme/app_colors.dart';
import 'package:territory_runner/ui/theme/app_palette.dart';
import 'package:territory_runner/ui/theme/app_theme.dart';

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
  group('Phase C2: Minimal Calm Moss Color System Tests', () {
    test(
      'Dark theme tokens match minimal Moss and neutral Obsidian specification',
      () {
        expect(AppColors.primary, const Color(0xFFA3C586)); // Moss Green
        expect(AppColors.accent, const Color(0xFFD4A373)); // Warm Ochre / Sand
        expect(AppColors.bgDeep, const Color(0xFF0D0F11)); // Deep Canvas
        expect(
          AppColors.surface,
          const Color(0xFF16191D),
        ); // Obsidian Surface 1
        expect(
          AppColors.surface2,
          const Color(0xFF1F2328),
        ); // Obsidian Surface 2
        expect(
          AppColors.bgElevated,
          const Color(0xFF262B32),
        ); // Elevated Surface
        expect(AppColors.border, const Color(0xFF30363D)); // Subtle Border
        expect(AppColors.borderSubtle, const Color(0xFF252A31));
        expect(AppColors.rival, const Color(0xFFC25946)); // Muted Terracotta
        expect(AppColors.onPrimary, const Color(0xFF0D0F11));
        expect(AppColors.onAccent, const Color(0xFF0D0F11));
      },
    );

    test('Light theme palette matches calm daylight specification with Moss #46663A', () {
      const palette = AppPalette.light;
      expect(palette.primary, const Color(0xFF46663A)); // Moss Light
      expect(palette.accent, const Color(0xFF9E6C3B)); // Warm Ochre Light
      expect(palette.bgDeep, const Color(0xFFF7F8F6)); // Calm daylight base
      expect(palette.surface, const Color(0xFFFFFFFF)); // Pure white
      expect(palette.surface2, const Color(0xFFF0F2EE)); // Soft container
      expect(palette.bgElevated, const Color(0xFFE5E7EB));
      expect(palette.border, const Color(0xFFD1D5DB));
      expect(palette.borderSubtle, const Color(0xFFE5E7EB));
      expect(palette.rival, const Color(0xFFA3412E)); // Terracotta Light
      expect(palette.onPrimary, const Color(0xFFFFFFFF));
      expect(palette.onAccent, const Color(0xFFFFFFFF));
    });

    test('Map territory fill is 18% opacity and outline stroke is 2.0 dp', () {
      // 18% of 255 is ~46 = 0x2E
      final darkFillAlpha = AppColors.territoryMineFill.a;
      expect((darkFillAlpha * 100).round(), closeTo(18, 1));

      final rivalFillAlpha = AppColors.territoryRivalFill.a;
      expect((rivalFillAlpha * 100).round(), closeTo(18, 1));

      final territory = Territory(
        id: 'test_territory_01',
        ownerId: 'player_01',
        areaSqMeters: 5000.0,
        polygon: [
          const LatLng(37.77, -122.41),
          const LatLng(37.78, -122.41),
          const LatLng(37.78, -122.40),
          const LatLng(37.77, -122.40),
        ],
        capturedAt: DateTime.now(),
        color: AppColors.mine,
      );

      final layer = MapLayers.buildPolygonLayer(
        [territory],
        currentUserId: 'player_01',
        palette: AppPalette.dark,
      );

      expect(layer.polygons, isNotEmpty);
      final poly = layer.polygons.first;
      expect(poly.borderStrokeWidth, equals(2.0));
      expect(poly.borderColor.toARGB32(), equals(AppColors.primary.toARGB32()));
    });

    test('WCAG AAA contrast verified for Dark Mode (> 7.0:1 text, > 3.0:1 graphical)', () {
      final textOnSurface = _calculateContrast(
        AppColors.textPrimary,
        AppColors.surface,
      );
      expect(
        textOnSurface,
        greaterThanOrEqualTo(7.0),
        reason: 'Primary text must exceed WCAG AAA (7.0:1)',
      );

      final textOnSurface2 = _calculateContrast(
        AppColors.textPrimary,
        AppColors.surface2,
      );
      expect(
        textOnSurface2,
        greaterThanOrEqualTo(7.0),
        reason: 'Primary text on surface2 must exceed WCAG AAA (7.0:1)',
      );

      final secondaryOnSurface = _calculateContrast(
        AppColors.textSecondary,
        AppColors.surface,
      );
      expect(
        secondaryOnSurface,
        greaterThanOrEqualTo(7.0),
        reason: 'Secondary text on surface must meet WCAG AAA (7.0:1)',
      );

      final mossOnSurface = _calculateContrast(
        AppColors.primary,
        AppColors.surface,
      );
      expect(
        mossOnSurface,
        greaterThanOrEqualTo(7.0),
        reason: 'Moss primary must exceed WCAG AAA (7.0:1)',
      );

      final onPrimaryOnMoss = _calculateContrast(
        AppColors.onPrimary,
        AppColors.primary,
      );
      expect(
        onPrimaryOnMoss,
        greaterThanOrEqualTo(7.0),
        reason: 'onPrimary on Moss must exceed WCAG AAA (7.0:1)',
      );

      final ochreOnSurface = _calculateContrast(
        AppColors.accent,
        AppColors.surface,
      );
      expect(
        ochreOnSurface,
        greaterThanOrEqualTo(7.0),
        reason: 'Ochre accent on surface must exceed WCAG AAA (7.0:1)',
      );

      final rivalOnSurface = _calculateContrast(
        AppColors.rival,
        AppColors.surface,
      );
      expect(
        rivalOnSurface,
        greaterThanOrEqualTo(3.0),
        reason: 'Rival terracotta on surface must meet WCAG UI component contrast (3.0:1)',
      );
    });

    test('WCAG AAA / AA contrast verified for Light Mode', () {
      const palette = AppPalette.light;

      final textOnSurface = _calculateContrast(
        palette.textPrimary,
        palette.surface,
      );
      expect(
        textOnSurface,
        greaterThanOrEqualTo(7.0),
        reason: 'Light primary text must exceed WCAG AAA (7.0:1)',
      );

      final secondaryOnSurface = _calculateContrast(
        palette.textSecondary,
        palette.surface,
      );
      expect(
        secondaryOnSurface,
        greaterThanOrEqualTo(7.0),
        reason: 'Light secondary text must meet WCAG AAA (7.0:1)',
      );

      final mossOnSurface = _calculateContrast(
        palette.primary,
        palette.surface,
      );
      expect(
        mossOnSurface,
        greaterThanOrEqualTo(4.5),
        reason: 'Moss light must exceed WCAG AA (4.5:1)',
      );

      final onPrimaryOnMoss = _calculateContrast(
        palette.onPrimary,
        palette.primary,
      );
      expect(
        onPrimaryOnMoss,
        greaterThanOrEqualTo(4.5),
        reason: 'White on Moss light must exceed WCAG AA (4.5:1)',
      );

      final ochreOnSurface = _calculateContrast(
        palette.accent,
        palette.surface,
      );
      expect(
        ochreOnSurface,
        greaterThanOrEqualTo(4.5),
        reason: 'Ochre light on white must exceed WCAG AA (4.5:1)',
      );
    });

    test(
      'Buttons enforce flat, non-glowing design with zero colored shadows',
      () {
        final btnStyle = AppTheme.darkTheme.elevatedButtonTheme.style;
        expect(btnStyle, isNotNull);

        final elevation = btnStyle!.elevation?.resolve({});
        expect(elevation, equals(0.0));

        final shadowColor = btnStyle.shadowColor?.resolve({});
        expect(shadowColor, equals(Colors.transparent));
      },
    );
  });
}
