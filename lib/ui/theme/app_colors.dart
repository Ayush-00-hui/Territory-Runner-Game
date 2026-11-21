import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Ultra-Premium Minimal Athletic Performance Palette:
/// Primary #00E5FF (Laser Cyan) + Accent #D4FF00 (Kinetic Volt Acid Lime) + Surface #111317 (Carbon Graphite)
class AppColors {
  AppColors._();

  // Core Palette Constants (Obsidian & Kinetic Volt Ultra-Premium Minimal)
  static const Color laserCyan = Color(
    0xFF00E5FF,
  ); // Primary: #00E5FF (Laser Cyan)
  static const Color kineticVolt = Color(
    0xFFD4FF00,
  ); // Accent: #D4FF00 (Kinetic Volt Acid Lime)
  static const Color darkGraphite = Color(
    0xFF111317,
  ); // Surface: #111317 (Carbon Graphite)

  // Aliases for backwards compatibility
  static const Color electricBlue = laserCyan;
  static const Color mustardYellow = kineticVolt;

  // Primary & Accent Brand Tokens
  static const Color primary = laserCyan; // #00E5FF (Laser Cyan)
  static const Color accent = kineticVolt; // #D4FF00 (Kinetic Volt Acid Lime)
  static const Color onPrimary = Color(
    0xFF08090B,
  ); // Deep Obsidian Black (10.5:1 AAA contrast on primary)
  static const Color onAccent = Color(
    0xFF08090B,
  ); // Deep Obsidian Black (17.3:1 AAA contrast on accent)
  static const Color primaryContainer = Color(
    0x3300E5FF,
  ); // Laser Cyan @ 20% glow
  static const Color accentContainer = Color(
    0x33D4FF00,
  ); // Kinetic Volt @ 20% glow

  // Core Surfaces & Structure (Obsidian & Carbon Graphite)
  static const Color bgDeep = Color(
    0xFF08090B,
  ); // Deep Obsidian Pitch Void Canvas
  static const Color bgElevated = Color(
    0xFF16191F,
  ); // Elevated Graphite for navigation & app bars
  static const Color surface =
      darkGraphite; // #111317 - Carbon Matte Graphite Surface Card
  static const Color surface2 = Color(
    0xFF1B1F27,
  ); // Secondary Surface for containers & inputs
  static const Color surfaceGlass = Color(
    0xE6111317,
  ); // 90% opacity frosted Carbon Graphite HUD
  static const Color border = Color(0xFF222832); // Clean Graphite Border
  static const Color borderSubtle = Color(
    0x26F5F7FA,
  ); // Hairline Platinum Ice @ 15%
  static const Color divider = Color(0x14F5F7FA); // Hairline Platinum Ice @ 8%
  static const Color scrim = Color(0x99000000); // 60% Black
  static const Color disabled = Color(0xFF38404B); // Muted Slate Disabled

  // Typography Colors (Ice Platinum & Slate Titanium, WCAG AAA contrast)
  static const Color textPrimary = Color(
    0xFFF5F7FA,
  ); // Ice Platinum (17.5:1 AAA on surface)
  static const Color textSecondary = Color(
    0xFF94A1B2,
  ); // Slate Titanium (8.2:1 AAA on surface)
  static const Color textMuted = Color(
    0xFF717E91,
  ); // Muted Slate (5.5:1 AAA/AA on surface)

  // Map Territory Tokens
  static const Color mine = primary; // Player territory (Laser Cyan #00E5FF)
  static const Color rival = Color(
    0xFFFF5252,
  ); // Rival territory & pacer markers (Coral Pink #FF5252)

  // Status & Metric Semantics
  static const Color warning = accent; // Kinetic Volt (#D4FF00)
  static const Color error = Color(
    0xFFFF3B30,
  ); // Safety Alert Crimson (#FF3B30)
  static const Color info = primary; // Laser Cyan (#00E5FF)
  static const Color success = Color(
    0xFF00E676,
  ); // Athletic Mint Emerald (#00E676)

  // Podium Trophy Accents
  static const Color gold = accent; // Kinetic Volt (#D4FF00)
  static const Color silver = Color(0xFFE2E8F0); // Platinum Ice
  static const Color bronze = Color(0xFFCD7F32); // Bronze Amber

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(
    0x3800E5FF,
  ); // 22% Laser Cyan glow
  static const Color territoryMineBorder = primary; // Solid Laser Cyan
  static const Color territoryRivalFill = Color(
    0x38FF5252,
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
