import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic palette tokens attached as a ThemeExtension to ThemeData.
/// Allows runtime theme switching between Dark (default), Light (outdoor), and System.
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;

  // Primary & Accent Brand Tokens
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color primaryContainer;
  final Color accentContainer;

  // Core Surfaces & Structure
  final Color bgDeep;
  final Color bgElevated;
  final Color surface;
  final Color surface2;
  final Color surfaceGlass;
  final Color border;
  final Color borderSubtle;
  final Color divider;
  final Color scrim;
  final Color disabled;

  // Typography Tokens
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Map Territory Tokens
  final Color mine;
  final Color rival;
  final Color territoryMineFill;
  final Color territoryMineBorder;
  final Color territoryRivalFill;
  final Color territoryRivalBorder;

  // Status & Semantics
  final Color warning;
  final Color error;
  final Color info;
  final Color success;

  // Podium Accents
  final Color gold;
  final Color silver;
  final Color bronze;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.primaryContainer,
    required this.accentContainer,
    required this.bgDeep,
    required this.bgElevated,
    required this.surface,
    required this.surface2,
    required this.surfaceGlass,
    required this.border,
    required this.borderSubtle,
    required this.divider,
    required this.scrim,
    required this.disabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.mine,
    required this.rival,
    required this.territoryMineFill,
    required this.territoryMineBorder,
    required this.territoryRivalFill,
    required this.territoryRivalBorder,
    required this.warning,
    required this.error,
    required this.info,
    required this.success,
    required this.gold,
    required this.silver,
    required this.bronze,
  });

  bool get isDark => brightness == Brightness.dark;
  bool get isLight => brightness == Brightness.light;

  /// Dark Palette (Electric Blue + Mustard Yellow + Dark Graphite Base)
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    primaryContainer: AppColors.primaryContainer,
    accentContainer: AppColors.accentContainer,
    bgDeep: AppColors.bgDeep,
    bgElevated: AppColors.bgElevated,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surfaceGlass: AppColors.surfaceGlass,
    border: AppColors.border,
    borderSubtle: AppColors.borderSubtle,
    divider: AppColors.divider,
    scrim: AppColors.scrim,
    disabled: AppColors.disabled,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    mine: AppColors.mine,
    rival: AppColors.rival,
    territoryMineFill: AppColors.territoryMineFill,
    territoryMineBorder: AppColors.territoryMineBorder,
    territoryRivalFill: AppColors.territoryRivalFill,
    territoryRivalBorder: AppColors.territoryRivalBorder,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    success: AppColors.success,
    gold: AppColors.gold,
    silver: AppColors.silver,
    bronze: AppColors.bronze,
  );

  /// Light Palette (Outdoor High-Contrast Daylight Base)
  /// Calibrated to meet WCAG AA (>= 4.5:1 body, >= 3.0:1 large/graphical).
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF0369A1), // Sky 700 (5.2:1 AA on white)
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFB45309), // Amber 700 (4.8:1 AA on white)
    onAccent: Color(0xFFFFFFFF),
    primaryContainer: Color(0x260369A1),
    accentContainer: Color(0x26B45309),
    bgDeep: Color(0xFFF1F5F9), // Slate 100 crisp daylight base
    bgElevated: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF), // Pure white surface card
    surface2: Color(0xFFE2E8F0), // Slate 200 secondary containers
    surfaceGlass: Color(0xF5FFFFFF), // High-opacity daylight HUD
    border: Color(0xFFCBD5E1), // Slate 300
    borderSubtle: Color(0x260F172A), // 15% Slate 900
    divider: Color(0x140F172A), // 8% Slate 900
    scrim: Color(0x99000000),
    disabled: Color(0xFF94A3B8), // Slate 400
    textPrimary: Color(0xFF0F172A), // Slate 900 (16.5:1 AAA on surface)
    textSecondary: Color(0xFF334155), // Slate 700 (9.6:1 AAA on surface)
    textMuted: Color(0xFF475569), // Slate 600 (6.7:1 AA on surface)
    mine: Color(0xFF0369A1),
    rival: Color(0xFFC2410C), // Orange-Red 700 (distinct from error, 5.0:1)
    territoryMineFill: Color(0x380369A1),
    territoryMineBorder: Color(0xFF0369A1),
    territoryRivalFill: Color(0x38C2410C),
    territoryRivalBorder: Color(0xFFC2410C),
    warning: Color(0xFFB45309),
    error: Color(0xFFB91C1C), // Red 700 (6.2:1 on white)
    info: Color(0xFF0369A1),
    success: Color(0xFF15803D), // Green 700 (4.9:1 on white)
    gold: Color(0xFFB45309),
    silver: Color(0xFF64748B),
    bronze: Color(0xFF9A3412),
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? primaryContainer,
    Color? accentContainer,
    Color? bgDeep,
    Color? bgElevated,
    Color? surface,
    Color? surface2,
    Color? surfaceGlass,
    Color? border,
    Color? borderSubtle,
    Color? divider,
    Color? scrim,
    Color? disabled,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? mine,
    Color? rival,
    Color? territoryMineFill,
    Color? territoryMineBorder,
    Color? territoryRivalFill,
    Color? territoryRivalBorder,
    Color? warning,
    Color? error,
    Color? info,
    Color? success,
    Color? gold,
    Color? silver,
    Color? bronze,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      accentContainer: accentContainer ?? this.accentContainer,
      bgDeep: bgDeep ?? this.bgDeep,
      bgElevated: bgElevated ?? this.bgElevated,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      divider: divider ?? this.divider,
      scrim: scrim ?? this.scrim,
      disabled: disabled ?? this.disabled,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      mine: mine ?? this.mine,
      rival: rival ?? this.rival,
      territoryMineFill: territoryMineFill ?? this.territoryMineFill,
      territoryMineBorder: territoryMineBorder ?? this.territoryMineBorder,
      territoryRivalFill: territoryRivalFill ?? this.territoryRivalFill,
      territoryRivalBorder: territoryRivalBorder ?? this.territoryRivalBorder,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      success: success ?? this.success,
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      bronze: bronze ?? this.bronze,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      bgDeep: Color.lerp(bgDeep, other.bgDeep, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      mine: Color.lerp(mine, other.mine, t)!,
      rival: Color.lerp(rival, other.rival, t)!,
      territoryMineFill: Color.lerp(
        territoryMineFill,
        other.territoryMineFill,
        t,
      )!,
      territoryMineBorder: Color.lerp(
        territoryMineBorder,
        other.territoryMineBorder,
        t,
      )!,
      territoryRivalFill: Color.lerp(
        territoryRivalFill,
        other.territoryRivalFill,
        t,
      )!,
      territoryRivalBorder: Color.lerp(
        territoryRivalBorder,
        other.territoryRivalBorder,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      success: Color.lerp(success, other.success, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      bronze: Color.lerp(bronze, other.bronze, t)!,
    );
  }
}

/// Convenience extension on BuildContext to access the active theme palette.
extension AppPaletteContextExtension on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
