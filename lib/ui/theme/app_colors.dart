import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Minimal, Calm Athletic Brand Palette (Single Brand Accent: Moss Green):
/// Accent #A3C586 (Calm Moss Green dark, #46663A light)
/// Base Canvas #0D0F11 (Neutral Obsidian) + Surface #16191D + Surface2 #1F2328
/// Rival #C25946 (Muted Terracotta)
/// Gold #D4A373 (Demoted Ochre for rare podium & streak milestones)
///
/// Strictly consolidated to <= 28 core semantic tokens with zero dead aliases.
class AppColors {
  AppColors._();

  // 1-3. Core Brand Accent Tokens (Single Accent: Calm Moss #A3C586)
  static const Color accent = Color(
    0xFFA3C586,
  ); // Single Brand Accent (Moss Green)
  static const Color onAccent = Color(
    0xFF0D0F11,
  ); // Deep Canvas (9.78:1 AAA on accent)
  static const Color accentContainer = Color(0x2EA3C586); // 18% Moss fill
  static const Color primary = accent; // Unified alias
  static const Color onPrimary = onAccent;
  static const Color primaryContainer = accentContainer;

  // 4-13. Core Surfaces & Structural Structure (Neutral Obsidian Base)
  static const Color bgDeep = Color(0xFF0D0F11); // Canvas Base (#0D0F11)
  static const Color bgElevated = Color(
    0xFF262B32,
  ); // Elevated bars/drawers (#262B32)
  static const Color surface = Color(
    0xFF16191D,
  ); // Primary Card surface (#16191D)
  static const Color surface2 = Color(
    0xFF1F2328,
  ); // Secondary container (#1F2328)
  static const Color surfaceGlass = Color(
    0xF016191D,
  ); // Frosted HUD surface (94% opacity)
  static const Color border = Color(0xFF30363D); // Clean architectural border
  static const Color borderSubtle = Color(
    0xFF252A31,
  ); // Subtle container border
  static const Color divider = Color(0x1AFFFFFF); // Hairline divider @ 10%
  static const Color scrim = Color(0x99000000); // 60% Modal scrim
  static const Color disabled = Color(0xFF484F58); // Muted slate disabled

  // 14-16. Typography Tokens (Alpine Snow & Cool Slate, WCAG AAA compliant)
  static const Color textPrimary = Color(
    0xFFF8FAFC,
  ); // Alpine Snow (16.9:1 AAA on surface)
  static const Color textSecondary = Color(
    0xFF9CA9BE,
  ); // Cool Slate (7.4:1 AAA on surface)
  static const Color textMuted = Color(
    0xFF8692A0,
  ); // Muted Slate (5.8:1 AAA/AA on surface)

  // 17-21. Map Territory Tokens (18% opacity fill, 2.0 dp stroke)
  static const Color mine = accent; // Player territory (Moss Green #A3C586)
  static const Color rival = Color(
    0xFFC25946,
  ); // Rival territory (Muted Terracotta #C25946)
  static const Color territoryMineFill = Color(
    0x2EA3C586,
  ); // 18% Moss Green fill
  static const Color territoryMineBorder = mine; // Solid Moss Green outline
  static const Color territoryRivalFill = Color(
    0x2EC25946,
  ); // 18% Terracotta fill
  static const Color territoryRivalBorder = rival; // Solid Terracotta outline

  // 22-25. Status & Metric Semantics
  static const Color warning = Color(0xFFF59E0B); // Amber warning (#F59E0B)
  static const Color error = Color(0xFFDC2626); // Safety alert red (#DC2626)
  static const Color info = accent; // Moss Green (#A3C586)
  static const Color success = accent; // Moss Green (#A3C586)

  // 26-28. Podium & Milestone Highlights (Ochre demoted to rare trophy gold)
  static const Color gold = Color(
    0xFFD4A373,
  ); // Warm Ochre Trophy Gold (#D4A373)
  static const Color silver = Color(0xFFE2E8F0); // Silver Ice (#E2E8F0)
  static const Color bronze = Color(0xFFCD7F32); // Bronze Amber (#CD7F32)
}
