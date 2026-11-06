import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Athletic High-Contrast Palette: Amber Red (#95191D) + Off-White (#F6F6EA) + Electric Yellow (#FDE827)
class AppColors {
  AppColors._();

  // Core Palette Constants (Exact Requested Values)
  static const Color amberRed = Color(0xFF95191D); // Primary Amber Red (#95191D)
  static const Color amberRedBright = Color(0xFFCC2228); // Luminous Amber Red for dark UI contrast
  static const Color offWhite = Color(0xFFF6F6EA); // Primary Warm Off-White (#F6F6EA)
  static const Color yellow = Color(0xFFFDE827); // Primary Electric Yellow (#FDE827)

  // Core Surfaces & Structure (Warm Carbon Obsidian)
  static const Color bgDeep = Color(0xFF0C0D0E); // Deep Aerospace Obsidian Black
  static const Color bgElevated = Color(0xFF141416);
  static const Color surface = Color(0xFF1A1A1D);
  static const Color surface2 = Color(0xFF242428);
  static const Color surfaceGlass = Color(0xF21A1A1D); // 95% opacity frosted glass HUD
  static const Color border = Color(0xFF333338);
  static const Color borderSubtle = Color(0x1AF6F6EA); // #F6F6EA @ 10%
  static const Color divider = Color(0x12F6F6EA); // #F6F6EA @ 7%
  static const Color scrim = Color(0x99000000); // #000000 @ 60%
  static const Color disabled = Color(0xFF52525A);

  // Typography Colors (Off-White & Titanium, 16:1+ AAA contrast)
  static const Color textPrimary = offWhite; // 0xFFF6F6EA (16.2:1 AAA contrast on surface)
  static const Color textSecondary = Color(0xFFA8A89C); // Warm Titanium (7.2:1 AAA contrast on surface)
  static const Color textMuted = Color(0xFF727266); // Muted Slate (3.6:1 AA contrast on surface)

  // Brand & Semantic Accents
  static const Color accent = yellow; // Electric Yellow (#FDE827)
  static const Color onAccent = Color(0xFF120E02); // Deep obsidian black (15.4:1 AAA contrast on yellow)
  static const Color accentContainer = Color(0x26FDE827); // Electric Yellow @ 15% glow
  static const Color mine = yellow; // Player territory (Electric Yellow)
  static const Color rival = amberRed; // Rival territory & pacer markers (Amber Red #95191D)

  // Status & Metric Semantics
  static const Color warning = yellow; // Solar Electric Yellow
  static const Color error = amberRed; // Amber Red (#95191D)
  static const Color info = offWhite; // Warm Off-White (#F6F6EA)
  static const Color success = yellow; // Electric Yellow

  // Podium Trophy Accents
  static const Color gold = yellow; // Electric Yellow (#FDE827)
  static const Color silver = offWhite; // Warm Off-White (#F6F6EA)
  static const Color bronze = amberRed; // Amber Red (#95191D)

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(
    0x3DFDE827,
  ); // 24% Electric Yellow glow
  static const Color territoryMineBorder = yellow; // Solid Electric Yellow
  static const Color territoryRivalFill = Color(
    0x3895191D,
  ); // 22% Amber Red glow (#95191D)
  static const Color territoryRivalBorder = amberRed; // Solid Amber Red (#95191D)

  // Legacy Aliases (Preserved for backwards compatibility, mapped to new palette)
  static const Color accentSecondary = info;
  static const Color secondary = yellow;
  static const Color cyanThruster = accent;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
