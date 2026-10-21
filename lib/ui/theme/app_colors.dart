import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Palette: "Ink + Pacer Blue" (Dark-only sporty, minimal & premium)
class AppColors {
  AppColors._();

  // Core Surfaces & Text
  static const Color bgDeep = Color(0xFF090B0F);
  static const Color bgElevated = Color(0xFF0E1116);
  static const Color surface = Color(0xFF12151B);
  static const Color surface2 = Color(0xFF191D25);
  static const Color surfaceGlass = Color(0xF212151B);
  static const Color border = Color(0xFF262B35);
  static const Color borderSubtle = Color(0x14FFFFFF); // #FFFFFF @ 8%
  static const Color divider = Color(0x0FFFFFFF); // #FFFFFF @ 6%
  static const Color scrim = Color(0x99000000); // #000000 @ 60%
  static const Color disabled = Color(0xFF5A606B);

  // Typography Colors (Never pure white)
  static const Color textPrimary = Color(0xFFF2F4F7);
  static const Color textSecondary = Color(0xFFA0A8B5);
  static const Color textMuted = Color(0xFF7F8897);

  // Brand & Semantic Accents
  static const Color accent = Color(0xFF4C8DFF); // Pacer Blue (Primary Action)
  static const Color onAccent = Color(
    0xFF06080C,
  ); // Dark text/icons on accent fills
  static const Color accentContainer = Color(
    0x1F4C8DFF,
  ); // Accent @ 12% subtle fill
  static const Color mine = Color(0xFF4C8DFF); // My territory (Pacer Blue)
  static const Color rival = Color(0xFFFF7A59); // Rival territory (Coral)

  // Status & Telemetry Semantics
  static const Color warning = Color(0xFFF5B544); // Amber (Caution / Anomaly)
  static const Color error = Color(0xFFF2677A); // Rose (Destructive / Failure)
  static const Color success = Color(0xFF4FD1A5); // Emerald (Completion / Sync)
  static const Color info = Color(
    0xFF94A3B8,
  ); // Slate (Guidance / Neutral Telemetry)

  // Podium Trophy Accents
  static const Color gold = Color(0xFFD9B45B);
  static const Color silver = Color(0xFFB8BCC4);
  static const Color bronze = Color(0xFFB98558);

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(0x294C8DFF); // Accent @ 16%
  static const Color territoryMineBorder = Color(0xFF4C8DFF); // Solid 1.5px
  static const Color territoryRivalFill = Color(0x24FF7A59); // Rival @ 14%
  static const Color territoryRivalBorder = Color(0xFFFF7A59); // Dashed 1.5px

  // Legacy Aliases (Preserved for backwards compatibility, mapped to new palette)
  static const Color accentSecondary = info;
  static const Color secondary = warning;
  static const Color cyanThruster = info;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
