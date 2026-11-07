import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Athletic High-Contrast Palette: Primary #2D9CDB (Electric Blue) + Accent #F2C94C (Mustard Yellow) + Surface #121417 (Dark Graphite)
class AppColors {
  AppColors._();

  // Core Palette Constants (Exact Requested Values)
  static const Color electricBlue = Color(
    0xFF2D9CDB,
  ); // Primary: #2D9CDB (Electric Blue)
  static const Color mustardYellow = Color(
    0xFFF2C94C,
  ); // Accent: #F2C94C (Mustard Yellow)
  static const Color darkGraphite = Color(
    0xFF121417,
  ); // Surface: #121417 (Dark Graphite)

  // Primary & Accent Brand Tokens
  static const Color primary = electricBlue; // #2D9CDB (Electric Blue)
  static const Color accent = mustardYellow; // #F2C94C (Mustard Yellow)
  static const Color onPrimary = Color(
    0xFF080B0E,
  ); // Deep Obsidian Black (6.5:1 AA contrast on primary)
  static const Color onAccent = Color(
    0xFF121417,
  ); // Dark Graphite (11.5:1 AAA contrast on accent)
  static const Color primaryContainer = Color(
    0x332D9CDB,
  ); // Electric Blue @ 20% glow
  static const Color accentContainer = Color(
    0x33F2C94C,
  ); // Mustard Yellow @ 20% glow

  // Core Surfaces & Structure (Dark Graphite)
  static const Color bgDeep = Color(
    0xFF0C0E11,
  ); // Deep Obsidian Graphite Base Canvas
  static const Color bgElevated = Color(
    0xFF181B20,
  ); // Elevated Graphite for navigation & app bars
  static const Color surface =
      darkGraphite; // #121417 - Core Dark Graphite Surface Card
  static const Color surface2 = Color(
    0xFF1C2025,
  ); // Secondary Surface for containers & inputs
  static const Color surfaceGlass = Color(
    0xF2121417,
  ); // 95% opacity frosted Dark Graphite HUD
  static const Color border = Color(0xFF2A2F37); // Clean Graphite Border
  static const Color borderSubtle = Color(
    0x26F4F6F8,
  ); // Hairline Ice White @ 15%
  static const Color divider = Color(0x14F4F6F8); // Hairline Ice White @ 8%
  static const Color scrim = Color(0x99000000); // 60% Black
  static const Color disabled = Color(0xFF3E4550); // Muted Slate Disabled

  // Typography Colors (Ice White & Slate Titanium, WCAG AAA contrast)
  static const Color textPrimary = Color(
    0xFFF4F6F8,
  ); // Ice White (17.1:1 AAA on surface)
  static const Color textSecondary = Color(
    0xFFA0AAB5,
  ); // Slate Titanium (8.0:1 AAA on surface)
  static const Color textMuted = Color(
    0xFF6B7684,
  ); // Muted Graphite (4.0:1 AA on surface)

  // Map Territory Tokens
  static const Color mine = primary; // Player territory (Electric Blue #2D9CDB)
  static const Color rival = Color(
    0xFFEB5757,
  ); // Rival territory & pacer markers (Coral Red #EB5757)

  // Status & Metric Semantics
  static const Color warning = accent; // Mustard Yellow (#F2C94C)
  static const Color error = Color(0xFFEB5757); // Coral Red (#EB5757)
  static const Color info = primary; // Electric Blue (#2D9CDB)
  static const Color success = Color(
    0xFF27AE60,
  ); // Athletic Mint Emerald (#27AE60)

  // Podium Trophy Accents
  static const Color gold = accent; // Mustard Yellow (#F2C94C)
  static const Color silver = Color(0xFFE0E6ED); // Silver Ice
  static const Color bronze = Color(0xFFCD7F32); // Bronze Amber

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(
    0x3D2D9CDB,
  ); // 24% Electric Blue glow
  static const Color territoryMineBorder = primary; // Solid Electric Blue
  static const Color territoryRivalFill = Color(
    0x38EB5757,
  ); // 22% Coral Red glow
  static const Color territoryRivalBorder = rival; // Solid Coral Red

  // Aliases for backwards compatibility
  static const Color amberRed = Color(0xFF95191D);
  static const Color amberRedBright = Color(0xFFFF454A);
  static const Color offWhite = textPrimary;
  static const Color yellow = accent;
  static const Color accentSecondary = info;
  static const Color secondary = accent;
  static const Color cyanThruster = primary;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
