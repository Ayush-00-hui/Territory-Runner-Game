import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Athletic High-Contrast Palette (Obsidian + Cyber Volt + Hyper Coral)
class AppColors {
  AppColors._();

  // Core Surfaces & Structure
  static const Color bgDeep = Color(0xFF0A0C10); // Aerospace Obsidian Black
  static const Color bgElevated = Color(0xFF101318);
  static const Color surface = Color(0xFF161922);
  static const Color surface2 = Color(0xFF1E2330);
  static const Color surfaceGlass = Color(0xF2161922);
  static const Color border = Color(0xFF283040);
  static const Color borderSubtle = Color(0x14F8FAFC); // #F8FAFC @ 8%
  static const Color divider = Color(0x0FF8FAFC); // #F8FAFC @ 6%
  static const Color scrim = Color(0x99000000); // #000000 @ 60%
  static const Color disabled = Color(0xFF475569);

  // Typography Colors (Slate White, 17:1 AAA contrast)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Brand & Semantic Accents
  static const Color accent = Color(0xFF00F59B); // Cyber Volt / Neon Lime
  static const Color onAccent = Color(0xFF05120B);
  static const Color accentContainer = Color(0x1A00F59B); // Cyber Volt @ 10%
  static const Color mine = accent; // My territory (Cyber Volt)
  static const Color rival = Color(0xFFFF385C); // Hyper Coral / Crimson Ember

  // Status & Metric Semantics
  static const Color warning = Color(0xFFFFB800); // Solar Amber
  static const Color error = Color(0xFFFF385C); // Hyper Coral
  static const Color info = Color(0xFF00C6FF); // Electric Cobalt
  static const Color success = accent;

  // Podium Trophy Accents
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFCBD5E1);
  static const Color bronze = Color(0xFFCD7F32);

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(
    0x3800F59B,
  ); // 22% Cyber Volt glow
  static const Color territoryMineBorder = Color(
    0xFF00F59B,
  ); // Solid Cyber Volt
  static const Color territoryRivalFill = Color(
    0x33FF385C,
  ); // 20% Hyper Coral glow
  static const Color territoryRivalBorder = Color(
    0xFFFF385C,
  ); // Solid Hyper Coral

  // Legacy Aliases (Preserved for backwards compatibility, mapped to new palette)
  static const Color accentSecondary = info;
  static const Color secondary = warning;
  static const Color cyanThruster = info;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
