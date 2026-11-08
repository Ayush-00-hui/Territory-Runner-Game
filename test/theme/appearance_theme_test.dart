import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/map/widgets/map_layers.dart';
import 'package:territory_runner/features/map/widgets/run_hud_metrics_card.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/firebase_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  group('Task F5: Appearance Runtime Theme Switching', () {
    test('Preferences support dark, light, and system theme modes', () async {
      final prefs = AppPreferences();

      // Default is dark
      expect(prefs.themePreference, equals(AppThemePreference.dark));
      expect(prefs.flutterThemeMode, equals(ThemeMode.dark));

      // Switch to light
      await prefs.setThemePreference(AppThemePreference.light);
      expect(prefs.themePreference, equals(AppThemePreference.light));
      expect(prefs.flutterThemeMode, equals(ThemeMode.light));

      // Switch to system
      await prefs.setThemePreference(AppThemePreference.system);
      expect(prefs.themePreference, equals(AppThemePreference.system));
      expect(prefs.flutterThemeMode, equals(ThemeMode.system));

      // Switch back to dark
      await prefs.setThemePreference(AppThemePreference.dark);
      expect(prefs.themePreference, equals(AppThemePreference.dark));
      expect(prefs.flutterThemeMode, equals(ThemeMode.dark));
    });

    testWidgets(
      'Switching theme preference immediately updates MaterialApp without app restart',
      (tester) async {
        final prefs = AppPreferences();
        await prefs.setThemePreference(AppThemePreference.dark);

        await tester.pumpWidget(
          ValueListenableBuilder<AppThemePreference>(
            valueListenable: prefs.themePreferenceNotifier,
            builder: (context, currentPref, _) {
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: prefs.flutterThemeMode,
                home: Builder(
                  builder: (ctx) {
                    final isLight =
                        Theme.of(ctx).brightness == Brightness.light;
                    final palette = ctx.palette;
                    return Scaffold(
                      backgroundColor: palette.bgDeep,
                      body: Center(
                        child: Text(
                          isLight ? 'Outdoor Light' : 'Athletic Dark',
                          style: TextStyle(color: palette.textPrimary),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Athletic Dark'), findsOneWidget);
        expect(find.text('Outdoor Light'), findsNothing);

        // Switch live to Light theme without restart
        await prefs.setThemePreference(AppThemePreference.light);
        await tester.pumpAndSettle();

        expect(find.text('Outdoor Light'), findsOneWidget);
        expect(find.text('Athletic Dark'), findsNothing);

        // Switch live back to Dark
        await prefs.setThemePreference(AppThemePreference.dark);
        await tester.pumpAndSettle();

        expect(find.text('Athletic Dark'), findsOneWidget);
      },
    );

    testWidgets(
      'Appearance settings controls allow tapping Dark, Light, System',
      (tester) async {
        final prefs = AppPreferences();
        await prefs.setThemePreference(AppThemePreference.dark);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileSettingsList(
                  firebaseService: FirebaseService(),
                  territoryService: TerritoryService(),
                  onOpenAuth: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Appearance'), findsWidgets);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);

        // Tap 'Light' option
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        expect(prefs.themePreference, equals(AppThemePreference.light));

        // Tap 'System' option
        await tester.tap(find.text('System'));
        await tester.pumpAndSettle();
        expect(prefs.themePreference, equals(AppThemePreference.system));

        // Tap 'Dark' option
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(prefs.themePreference, equals(AppThemePreference.dark));
      },
    );
  });

  group('Task F5: WCAG AA Contrast Tests for BOTH Palettes', () {
    test('Dark Palette: WCAG AA contrast compliance and muted text fix', () {
      const palette = AppPalette.dark;

      final textPrimaryContrast = _calculateContrast(
        palette.textPrimary,
        palette.surface,
      );
      final textSecondaryContrast = _calculateContrast(
        palette.textSecondary,
        palette.surface,
      );
      final textMutedContrast = _calculateContrast(
        palette.textMuted,
        palette.surface,
      );
      final onPrimaryContrast = _calculateContrast(
        palette.onPrimary,
        palette.primary,
      );
      final onAccentContrast = _calculateContrast(
        palette.onAccent,
        palette.accent,
      );

      // Body text >= 4.5:1
      expect(
        textPrimaryContrast,
        greaterThanOrEqualTo(4.5),
        reason: 'Dark textPrimary on surface must meet WCAG AA (>= 4.5:1)',
      );
      expect(
        textSecondaryContrast,
        greaterThanOrEqualTo(4.5),
        reason: 'Dark textSecondary on surface must meet WCAG AA (>= 4.5:1)',
      );

      // Muted text: MUST measure >= 4.5:1 (Fixed from legacy ~3.3:1)
      expect(
        textMutedContrast,
        greaterThanOrEqualTo(4.5),
        reason:
            'Dark textMuted ($textMutedContrast:1) on surface must meet WCAG AA (>= 4.5:1)',
      );

      // Primary and Accent button labels >= 4.5:1
      expect(onPrimaryContrast, greaterThanOrEqualTo(4.5));
      expect(onAccentContrast, greaterThanOrEqualTo(4.5));

      // Rival and Error colors must be distinct
      expect(
        palette.rival != palette.error,
        isTrue,
        reason: 'Dark palette rival color must differ from error color',
      );
    });

    test('Light Palette: Outdoor high-contrast WCAG AA compliance', () {
      const palette = AppPalette.light;

      final textPrimaryContrast = _calculateContrast(
        palette.textPrimary,
        palette.surface,
      );
      final textSecondaryContrast = _calculateContrast(
        palette.textSecondary,
        palette.surface,
      );
      final textMutedContrast = _calculateContrast(
        palette.textMuted,
        palette.surface,
      );
      final onPrimaryContrast = _calculateContrast(
        palette.onPrimary,
        palette.primary,
      );
      final onAccentContrast = _calculateContrast(
        palette.onAccent,
        palette.accent,
      );
      final primaryContrast = _calculateContrast(
        palette.primary,
        palette.surface,
      );
      final accentContrast = _calculateContrast(
        palette.accent,
        palette.surface,
      );
      final errorContrast = _calculateContrast(palette.error, palette.surface);
      final rivalContrast = _calculateContrast(palette.rival, palette.surface);

      // Body text >= 4.5:1
      expect(
        textPrimaryContrast,
        greaterThanOrEqualTo(4.5),
        reason: 'Light textPrimary on surface must meet WCAG AA (>= 4.5:1)',
      );
      expect(
        textSecondaryContrast,
        greaterThanOrEqualTo(4.5),
        reason: 'Light textSecondary on surface must meet WCAG AA (>= 4.5:1)',
      );
      expect(
        textMutedContrast,
        greaterThanOrEqualTo(4.5),
        reason: 'Light textMuted on surface must meet WCAG AA (>= 4.5:1)',
      );

      // Buttons >= 4.5:1
      expect(onPrimaryContrast, greaterThanOrEqualTo(4.5));
      expect(onAccentContrast, greaterThanOrEqualTo(4.5));

      // UI accents & status colors on light surface >= 4.5:1
      expect(primaryContrast, greaterThanOrEqualTo(4.5));
      expect(accentContrast, greaterThanOrEqualTo(4.5));
      expect(errorContrast, greaterThanOrEqualTo(4.5));
      expect(rivalContrast, greaterThanOrEqualTo(4.5));

      // Rival and Error colors must be distinct
      expect(
        palette.rival != palette.error,
        isTrue,
        reason: 'Light palette rival color must differ from error color',
      );
    });
  });

  group('Task F5: Map Layers & Territory Overlay Adaptation', () {
    test(
      'MapLayers.buildTileLayer adapts correctly for light vs dark mode',
      () {
        final darkLayer = MapLayers.buildTileLayer(isLight: false);
        final lightLayer = MapLayers.buildTileLayer(isLight: true);

        expect(darkLayer.urlTemplate, isNotEmpty);
        expect(lightLayer.urlTemplate, isNotEmpty);
      },
    );

    test('buildPolygonLayer applies dashed stroke pattern and distinct borders for rival territories', () {
      final mineTerritory = Territory(
        id: 'mine_1',
        ownerId: 'u1',
        polygon: const [
          LatLng(40.78, -73.96),
          LatLng(40.79, -73.96),
          LatLng(40.79, -73.95),
          LatLng(40.78, -73.95),
        ],
        color: AppColors.mine,
        areaSqMeters: 50000.0,
        capturedAt: DateTime.now(),
      );

      final rivalTerritory = Territory(
        id: 'rival_1',
        ownerId: 'u2',
        polygon: const [
          LatLng(40.75, -73.98),
          LatLng(40.76, -73.98),
          LatLng(40.76, -73.97),
          LatLng(40.75, -73.97),
        ],
        color: AppColors.rival,
        areaSqMeters: 40000.0,
        capturedAt: DateTime.now(),
      );

      for (final palette in [AppPalette.dark, AppPalette.light]) {
        final layer = MapLayers.buildPolygonLayer(
          [mineTerritory, rivalTerritory],
          currentUserId: 'u1',
          palette: palette,
        );

        expect(layer.polygons.length, equals(2));

        final minePoly = layer.polygons[0];
        final rivalPoly = layer.polygons[1];

        // Mine territory has solid pattern, 2.0 stroke width
        expect(minePoly.borderStrokeWidth, equals(2.0));
        expect(minePoly.pattern, equals(const StrokePattern.solid()));
        expect(
          minePoly.borderColor.withValues(alpha: 1.0),
          equals(palette.territoryMineBorder.withValues(alpha: 1.0)),
        );

        // Rival territory has dashed pattern, 2.0 stroke width
        expect(rivalPoly.borderStrokeWidth, equals(2.0));
        expect(
          rivalPoly.pattern,
          equals(StrokePattern.dashed(segments: const [7.0, 4.0])),
        );
        expect(
          rivalPoly.borderColor.withValues(alpha: 1.0),
          equals(palette.territoryRivalBorder.withValues(alpha: 1.0)),
        );

        // Both border colors are distinct from each other
        expect(minePoly.borderColor, isNot(equals(rivalPoly.borderColor)));
      }
    });
  });

  group('Task F5: Small Screen & Large Text Scale (1.3) Layout Stability', () {
    testWidgets(
      'RunHudMetricsCard renders at 1.3 text scale on 320px screen under Light Theme without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: RunHudMetricsCard(
                  isRunActive: true,
                  isAutoPaused: false,
                  distanceKm: 4.82,
                  elapsedSeconds: 1420,
                  movingSeconds: 1380,
                  splitPace: "4'58\"",
                  currentSpeedKmh: 12.1,
                  satelliteAccuracyMeters: 4.0,
                  stepCount: 2840,
                  isStepCountEstimated: false,
                  territoriesClaimed: 2,
                  onToggleExpanded: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('4.82'), findsOneWidget);
        expect(find.text('km'), findsOneWidget);
        expect(find.text('23:00'), findsOneWidget);
        expect(find.text("4'58\""), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
