import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Palette: "Charcoal + Ember" (Dark-only theme)
class AppColors {
  AppColors._();

  // Core Surfaces & Text
  static const Color bgDeep = Color(0xFF0C0B0A);
  static const Color bgElevated = Color(0xFF121110);
  static const Color surface = Color(0xFF151413);
  static const Color surface2 = Color(0xFF1D1B19);
  static const Color surfaceGlass = Color(0xF2151413);
  static const Color border = Color(0xFF2B2926);
  static const Color borderSubtle = Color(0x14FFFFFF); // #FFFFFF @ 8%
  static const Color divider = Color(0x0FFFFFFF);      // #FFFFFF @ 6%
  static const Color scrim = Color(0x99000000);        // #000000 @ 60%
  static const Color disabled = Color(0xFF5E5A55);

  // Typography Colors (Never pure white)
  static const Color textPrimary = Color(0xFFF5F3F0);
  static const Color textSecondary = Color(0xFFA8A29A);
  static const Color textMuted = Color(0xFF8A847C);

  // Brand & Semantic Accents
  static const Color accent = Color(0xFFFF6A3D);       // Ember (Primary Action)
  static const Color onAccent = Color(0xFF0C0B0A);     // Dark text/icons on accent fills
  static const Color accentContainer = Color(0x1FFF6A3D); // Accent @ 12% subtle fill
  static const Color mine = Color(0xFFFF6A3D);         // My territory (Ember)
  static const Color rival = Color(0xFF6EA8FE);        // Rival territory (Blue)

  // Status & Telemetry Semantics
  static const Color warning = Color(0xFFF2B84B);      // Amber (Caution / Anomaly)
  static const Color error = Color(0xFFF2677A);        // Rose (Destructive / Failure)
  static const Color success = Color(0xFF5FCB8C);      // Sage (Completion / Sync)
  static const Color info = Color(0xFF9B8CFF);         // Violet (Guidance / Duels)

  // Podium Trophy Accents
  static const Color gold = Color(0xFFD9B45B);
  static const Color silver = Color(0xFFB8BCC4);
  static const Color bronze = Color(0xFFB98558);

  // Territory Map Render Fills & Borders
  static const Color territoryMineFill = Color(0x29FF6A3D);   // Ember @ 16%
  static const Color territoryMineBorder = Color(0xFFFF6A3D); // Solid 1.5px
  static const Color territoryRivalFill = Color(0x246EA8FE);  // Rival @ 14%
  static const Color territoryRivalBorder = Color(0xFF6EA8FE); // Dashed 1.5px

  // Legacy Aliases (Preserved for backwards compatibility, mapped to new palette)
  static const Color accentSecondary = info;
  static const Color secondary = warning;
  static const Color cyanThruster = info;
  static const Color positiveGreen = success;
  static const Color actionRed = error;
  static const Color amberStreak = warning;
  static const Color accentGlow = accentContainer;
}
