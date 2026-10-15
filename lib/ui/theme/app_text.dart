import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Territory Runner Design System: Typography Scale
/// Uses 'Oswald' for athletic big numbers & bold headings,
/// and 'Inter' for clean, readable body typography.
/// Tabular figures are enforced on numbers/timers to eliminate digit jitter.
class AppText {
  AppText._();

  static const String displayFont = 'Oswald';
  static const String bodyFont = 'Inter';

  // --- ATHLETIC DISPLAY NUMBERS (TABULAR FIGURES) ---

  /// Massive 44sp metric readout (e.g. big live pace/distance hero)
  static const TextStyle statHero = TextStyle(
    fontFamily: displayFont,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 32sp stat metric readout
  static const TextStyle statDisplay = TextStyle(
    fontFamily: displayFont,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 26sp stat metric readout (e.g. live HUD primary numbers)
  static const TextStyle statLarge = TextStyle(
    fontFamily: displayFont,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 20sp stat metric readout (e.g. secondary HUD metrics)
  static const TextStyle statMedium = TextStyle(
    fontFamily: displayFont,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 16sp stat metric readout (compact tiles)
  static const TextStyle statSmall = TextStyle(
    fontFamily: displayFont,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Stopwatch and digital clock timer
  static const TextStyle timer = TextStyle(
    fontFamily: displayFont,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // --- HEADINGS (OSWALD DISPLAY) ---

  static const TextStyle headingLarge = TextStyle(
    fontFamily: displayFont,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: displayFont,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  // --- BODY TEXT (INTER SANS) ---

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // --- LABELS & CAPTIONS (SPORTS HUD STYLE) ---

  static const TextStyle label = TextStyle(
    fontFamily: bodyFont,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textMuted,
  );

  static const TextStyle labelAccent = TextStyle(
    fontFamily: bodyFont,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.accent,
  );

  static const TextStyle button = TextStyle(
    fontFamily: displayFont,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: Colors.black,
  );

  // --- COMPATIBILITY & CONVENIENCE ALIASES ---
  static const TextStyle headlineLarge = headingLarge;
  static const TextStyle headlineMedium = headingMedium;
  static const TextStyle headlineSmall = headingSmall;
  static const TextStyle bodyMedium = body;
  static const TextStyle labelSmall = label;
}
