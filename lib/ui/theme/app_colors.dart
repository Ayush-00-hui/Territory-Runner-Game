import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Iconic Athletic Brand Palette (Nordic Mint & Solar Blaze on Smoked Obsidian):
/// Primary #00D492 (Nordic Mint Emerald) + Accent #FF6332 (Solar Blaze / Athletic Ember)
/// Surface #131720 (Nordic Titanium) + Canvas #0B0D11 (Smoked Obsidian)
class AppColors {
  AppColors._();

  // Core Palette Constants (Calm, Matte, Non-Flashy Nordic Mint & Solar Blaze)
  static const Color nordicMint = Color(
    0xFF00D492,
  ); // Primary / Mine: #00D492 (Nordic Mint Emerald Conquest)
  static const Color solarBlaze = Color(
    0xFFFF6332,
  ); // Accent: #FF6332 (Solar Blaze / Athletic Ember)
  static const Color smokedObsidian = Color(
    0xFF0B0D11,
  ); // Deep Canvas: #0B0D11 (Smoked Obsidian)
  static const Color nordicTitanium = Color(
    0xFF131720,
  ); // Surface: #131720 (Nordic Titanium Dark Graphite)
  static const Color royalAmethyst = Color(
    0xFFA855F7,
  ); // Rival: #A855F7 (Royal Amethyst)

  // Backward compatibility aliases
  static const Color electricBlue = nordicMint;
  static const Color mustardYellow = solarBlaze;
  static const Color darkGraphite = nordicTitanium;
  static const Color laserCyan = nordicMint;
  static const Color kineticVolt = solarBlaze;

  // Primary & Accent Brand Tokens
  static const Color primary = nordicMint; // #00D492 (Nordic Mint)
  static const Color accent = solarBlaze; // #FF6332 (Solar Blaze)
  static const Color onPrimary = Color(
    0xFF08090B,
  ); // Deep Obsidian Black (10.6:1 AAA contrast on primary)
  static const Color onAccent = Color(
    0xFF08090B,
  ); // Deep Obsidian Black (6.9:1 AA contrast on accent)
  static const Color primaryContainer = Color(
    0x2600D492,
  ); // Nordic Mint @ 15% fill
  static const Color accentContainer = Color(
    0x26FF6332,
  ); // Solar Blaze @ 15% fill

  // Core Surfaces & Structure (Dark Matte Graphite)
  static const Color bgDeep =
      smokedObsidian; // #0B0D11 Deep Matte Obsidian Base Canvas
  static const Color bgElevated = Color(
    0xFF181D27,
  ); // Elevated Graphite for navigation & app bars
  static const Color surface =
      nordicTitanium; // #131720 - Core Nordic Titanium Surface Card
  static const Color surface2 = Color(
    0xFF1B202C,
  ); // Secondary Surface for containers & inputs
  static const Color surfaceGlass = Color(
    0xF0131720,
  ); // 94% opacity frosted Nordic Titanium HUD
  static const Color border = Color(
    0xFF252B3A,
  ); // Clean Architectural Matte Border
  static const Color borderSubtle = Color(
    0x26F8FAFC,
  ); // Hairline Snow White @ 15%
  static const Color divider = Color(0x14F8FAFC); // Hairline Snow White @ 8%
  static const Color scrim = Color(0x99000000); // 60% Black
  static const Color disabled = Color(0xFF384050); // Muted Slate Disabled

  // Typography Colors (Alpine Snow & Cool Slate, WCAG AAA contrast)
  static const Color textPrimary = Color(
    0xFFF8FAFC,
  ); // Alpine Snow (17.5:1 AAA on surface)
  static const Color textSecondary = Color(
    0xFF94A3B8,
  ); // Cool Slate (7.1:1 AAA on surface)
  static const Color textMuted = Color(
    0xFF64748B,
  ); // Muted Slate (3.8:1 AA on surface)

  // Map Territory Tokens
  static const Color mine = primary; // Player territory (Nordic Mint #00D492)
  static const Color rival =
      royalAmethyst; // Rival territory & pacer markers (Royal Amethyst #A855F7)

  // Status & Metric Semantics
  static const Color warning = Color(0xFFF59E0B); // Warm Amber (#F59E0B)
  static const Color error = Color(
    0xFFEF4444,
  ); // Safety Alert Crimson (#EF4444)
  static const Color info = primary; // Nordic Mint (#00D492)
  static const Color success = primary; // Nordic Mint (#00D492)

  // Podium Trophy Accents
  static const Color gold = Color(0xFFF59E0B); // Trophy Gold (#F59E0B)
  static const Color silver = Color(0xFFE2E8F0); // Silver Ice (#E2E8F0)
  static const Color bronze = Color(0xFFCD7F32); // Bronze Amber (#CD7F32)

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(
    0x3800D492,
  ); // 22% Nordic Mint fill
  static const Color territoryMineBorder = primary; // Solid Nordic Mint
  static const Color territoryRivalFill = Color(
    0x38A855F7,
  ); // 22% Royal Amethyst fill
  static const Color territoryRivalBorder = rival; // Solid Royal Amethyst

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
