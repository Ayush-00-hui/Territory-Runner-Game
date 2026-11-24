import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Territory Runner Design System: Typography Scale
/// Enforces 'Inter' across the entire interface.
/// Big numbers use Inter w600-w700 with tabular figures (`FontFeature.tabularFigures()`)
/// and subtle negative letter spacing for clean, jitter-free athletic metrics.
class AppText {
  AppText._();

  static const String fontFamily = 'Inter';
  static const String bodyFont = 'Inter';
  static const String displayFont = 'Inter'; // Oswald completely deprecated

  // ==========================================
  // ATHLETIC DISPLAY NUMBERS (TABULAR FIGURES)
  // ==========================================

  /// Massive 44sp metric readout (live pace, distance hero)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 36sp primary metric readout
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 28sp secondary metric readout
  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ==========================================
  // TITLES & HEADINGS (INTER SANS)
  // ==========================================

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ==========================================
  // BODY TEXT
  // ==========================================

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.textMuted,
  );

  // ==========================================
  // LABELS, OVERLINES & CAPTIONS
  // ==========================================

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
  );

  /// Tiny overline labels (+0.8 tracking) — the ONLY place uppercase is recommended
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textMuted,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  /// Tabular unit style: smaller and muted next to hero digits
  static const TextStyle statUnit = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    color: AppColors.textMuted,
  );

  // ==========================================
  // COMPATIBILITY ALIASES
  // ==========================================

  static const TextStyle statHero = displayLarge;
  static const TextStyle statDisplay = displayMedium;
  static const TextStyle statLarge = displaySmall;

  static const TextStyle statMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle statSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle timer = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ==========================================
  // SEMANTIC SCALE MAPPINGS
  // (Heading 1-4, Body, Label, Stat, Micro)
  // ==========================================

  /// Heading 1 (24sp Bold)
  static const TextStyle heading1 = headlineLarge;

  /// Heading 2 (22sp SemiBold)
  static const TextStyle heading2 = titleLarge;

  /// Heading 3 (18sp SemiBold)
  static const TextStyle heading3 = titleMedium;

  /// Heading 4 (15sp SemiBold)
  static const TextStyle heading4 = titleSmall;

  /// Primary Body (13sp Regular)
  static const TextStyle body = bodyMedium;

  /// Primary Label (10sp SemiBold Tracking +0.8)
  static const TextStyle label = labelSmall;

  /// Primary Stat (36sp Bold Tabular)
  static const TextStyle stat = displayMedium;

  /// Micro style (9sp SemiBold Tracking +0.5) for compact badges/tags
  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );

  static const TextStyle headingLarge = headlineLarge;
  static const TextStyle headingMedium = headlineMedium;
  static const TextStyle headingSmall = headlineSmall;

  static const TextStyle labelAccent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.accent,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.onAccent,
  );
}
