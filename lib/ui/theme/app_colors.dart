import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Athletic High-Contrast Palette: Amber Red (#95191D) Canvas + Off-White (#F6F6EA) + Electric Yellow (#FDE827)
class AppColors {
  AppColors._();

  // Core Palette Constants (Exact Requested Values)
  static const Color amberRed = Color(
    0xFF95191D,
  ); // Primary Amber Red (#95191D)
  static const Color amberRedBright = Color(
    0xFFFF454A,
  ); // Luminous Amber Red for radiant accents & contrast (3.5:1 on surface)
  static const Color offWhite = Color(
    0xFFF6F6EA,
  ); // Primary Warm Off-White (#F6F6EA)
  static const Color yellow = Color(
    0xFFFDE827,
  ); // Primary Electric Yellow (#FDE827)

  // Core Surfaces & Structure (Amber Red Canvas + Deep Velvet Garnet Surfaces)
  static const Color bgDeep =
      amberRed; // #95191D - Main Amber Red Canvas Background!
  static const Color bgElevated = Color(
    0xFF7E1317,
  ); // Rich deep garnet velvet for nav/bars
  static const Color surface = Color(
    0xFF6B0E12,
  ); // Deep rich velvety garnet card surface
  static const Color surface2 = Color(
    0xFF550A0E,
  ); // Deep velvety ruby container & input fill
  static const Color surfaceGlass = Color(
    0xF26B0E12,
  ); // 95% opacity frosted garnet HUD
  static const Color border = Color(0x59F6F6EA); // Crisp Off-White @ 35%
  static const Color borderSubtle = Color(0x33F6F6EA); // Crisp Off-White @ 20%
  static const Color divider = Color(0x26F6F6EA); // Crisp Off-White @ 15%
  static const Color scrim = Color(0x99000000); // #000000 @ 60%
  static const Color disabled = Color(0xFF6D3B3E); // Muted wine disabled

  // Typography Colors (Off-White & Warm Ivory, WCAG AAA contrast)
  static const Color textPrimary =
      offWhite; // 0xFFF6F6EA (7.9:1 AAA on bgDeep, 11.4:1 AAA on surface)
  static const Color textSecondary = Color(
    0xFFEADBDB,
  ); // Warm Ivory (6.4:1 AA on bgDeep, 9.2:1 AAA on surface)
  static const Color textMuted = Color(
    0xFFCCAFAF,
  ); // Muted Rosy Parchment (4.2:1 AA on bgDeep, 6.1:1 on surface)

  // Brand & Semantic Accents
  static const Color accent =
      yellow; // Electric Yellow (#FDE827) - Eye-catchy CTA buttons & details
  static const Color onAccent = Color(
    0xFF140708,
  ); // Deep obsidian text (15.7:1 AAA contrast on yellow)
  static const Color accentContainer = Color(
    0x33FDE827,
  ); // Electric Yellow @ 20% glow
  static const Color mine = yellow; // Player territory (Electric Yellow)
  static const Color rival =
      amberRedBright; // Rival territory & pacer markers (Luminous Red #FF454A)

  // Status & Metric Semantics
  static const Color warning = yellow; // Solar Electric Yellow
  static const Color error =
      amberRedBright; // Luminous Red (#FF454A) for high contrast on Amber Red
  static const Color info = offWhite; // Warm Off-White (#F6F6EA)
  static const Color success = yellow; // Electric Yellow

  // Podium Trophy Accents
  static const Color gold = yellow; // Electric Yellow (#FDE827)
  static const Color silver = offWhite; // Warm Off-White (#F6F6EA)
  static const Color bronze = amberRedBright; // Luminous Amber Red (#FF454A)

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(
    0x3DFDE827,
  ); // 24% Electric Yellow glow
  static const Color territoryMineBorder = yellow; // Solid Electric Yellow
  static const Color territoryRivalFill = Color(
    0x38FF454A,
  ); // 22% Luminous Red glow
  static const Color territoryRivalBorder =
      amberRedBright; // Solid Luminous Red

  // Legacy Aliases (Preserved for backwards compatibility, mapped to new palette)
  static const Color accentSecondary = info;
  static const Color secondary = yellow;
  static const Color cyanThruster = accent;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
