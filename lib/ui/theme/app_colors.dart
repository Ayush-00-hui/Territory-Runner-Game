import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Palette: "Graphite + Bone + Moss" (Dark-only calm, minimal, premium & human-designed)
class AppColors {
  AppColors._();

  // Core Surfaces & Structure
  static const Color bgDeep = Color(0xFF0D0E0C);
  static const Color bgElevated = Color(0xFF11120F);
  static const Color surface = Color(0xFF141512);
  static const Color surface2 = Color(0xFF1B1C18);
  static const Color surfaceGlass = Color(0xF2141512);
  static const Color border = Color(0xFF2A2B26);
  static const Color borderSubtle = Color(0x14ECEAE3); // #ECEAE3 @ 8%
  static const Color divider = Color(0x0FECEAE3); // #ECEAE3 @ 6%
  static const Color scrim = Color(0x99000000); // #000000 @ 60%
  static const Color disabled = Color(0xFF55554D);

  // Typography Colors (Never pure white)
  static const Color textPrimary = Color(0xFFECEAE3);
  static const Color textSecondary = Color(0xFFA6A397);
  static const Color textMuted = Color(0xFF85837A);

  // Brand & Semantic Accents (Default: MOSS)
  static const Color accent = Color(0xFFA3C586); // Moss (Primary Action & Claimed Land)
  static const Color onAccent = Color(0xFF0D0E0C); // Dark text/icons on accent fills
  static const Color accentContainer = Color(0x1AA3C586); // Accent @ 10% (Selected states only)
  static const Color mine = accent; // My territory (Moss)
  static const Color rival = Color(0xFF86A5D3); // Rival territory (Steel Blue, dashed)

  // Status & Telemetry Semantics
  static const Color warning = Color(0xFFD9A441); // Ochre / Amber (Caution / Anomaly)
  static const Color error = Color(0xFFE0716B); // Terracotta / Rose (Destructive / Failure)
  static const Color info = Color(0xFF9AA4B2); // Slate (Guidance / Neutral Telemetry)
  static const Color success = accent; // Success is an alias of accent (no second green)

  // Podium Trophy Accents (Muted)
  static const Color gold = Color(0xFFCDAE6A);
  static const Color silver = Color(0xFFB5B6B0);
  static const Color bronze = Color(0xFFB0825A);

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(0x29A3C586); // Accent @ 16%
  static const Color territoryMineBorder = accent; // Solid 1.5px
  static const Color territoryRivalFill = Color(0x2486A5D3); // Rival @ 14%
  static const Color territoryRivalBorder = rival; // Dashed 1.5px

  // Legacy Aliases (Preserved for backwards compatibility, mapped to new palette)
  static const Color accentSecondary = info;
  static const Color secondary = warning;
  static const Color cyanThruster = info;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
