import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
/// Minimal, Calm Athletic Brand Palette (Moss & Warm Ochre on Neutral Obsidian):
/// Primary #A3C586 (Calm Moss Green) + Accent #D4A373 (Warm Ochre / Sand)
/// Canvas #0D0F11 (Neutral Obsidian) + Surface #16191D + Surface2 #1F2328
/// Rival #C25946 (Muted Terracotta)
class AppColors {
  AppColors._();

  // Core Palette Constants (Calm, Matte, Non-Flashy Moss & Neutral Obsidian)
  static const Color mossDark = Color(0xFFA3C586); // Primary Dark Moss: #A3C586
  static const Color mossLight = Color(
    0xFF46663A,
  ); // Primary Light Moss: #46663A
  static const Color ochre = Color(
    0xFFD4A373,
  ); // Accent Warm Ochre / Sand: #D4A373
  static const Color ochreLight = Color(
    0xFF9E6C3B,
  ); // Accent Light Ochre: #9E6C3B
  static const Color obsidianDeep = Color(0xFF0D0F11); // Deep Canvas: #0D0F11
  static const Color obsidianSurface = Color(0xFF16191D); // Surface: #16191D
  static const Color obsidianSurface2 = Color(0xFF1F2328); // Surface 2: #1F2328
  static const Color obsidianElevated = Color(
    0xFF262B32,
  ); // Elevated Surface: #262B32
  static const Color terracotta = Color(
    0xFFC25946,
  ); // Rival Muted Terracotta: #C25946
  static const Color terracottaLight = Color(
    0xFFA3412E,
  ); // Rival Light Terracotta: #A3412E

  // Primary & Accent Brand Tokens
  static const Color primary = mossDark; // #A3C586 (Calm Moss Green)
  static const Color accent = ochre; // #D4A373 (Warm Ochre / Sand)
  static const Color onPrimary = Color(
    0xFF0D0F11,
  ); // Deep Obsidian (9.78:1 AAA on primary)
  static const Color onAccent = Color(
    0xFF0D0F11,
  ); // Deep Obsidian (7.1:1 AAA on accent)
  static const Color primaryContainer = Color(0x2EA3C586); // 18% Moss fill
  static const Color accentContainer = Color(0x2ED4A373); // 18% Ochre fill

  // Core Surfaces & Structure (Neutral Obsidian Dark)
  static const Color bgDeep = obsidianDeep; // #0D0F11 Deep Matte Base Canvas
  static const Color bgElevated =
      obsidianElevated; // #262B32 Elevated for bars/drawers
  static const Color surface = obsidianSurface; // #16191D Core Surface Card
  static const Color surface2 = obsidianSurface2; // #1F2328 Secondary Surface
  static const Color surfaceGlass = Color(
    0xF016191D,
  ); // 94% opacity frosted HUD
  static const Color border = Color(
    0xFF30363D,
  ); // Clean Architectural Matte Border
  static const Color borderSubtle = Color(
    0xFF252A31,
  ); // Subtle Surface Separator
  static const Color divider = Color(0x1AFFFFFF); // Hairline White @ 10%
  static const Color scrim = Color(0x99000000); // 60% Black scrim
  static const Color disabled = Color(0xFF484F58); // Muted Slate Disabled

  // Typography Colors (Alpine Snow & Cool Slate, WCAG AAA contrast)
  static const Color textPrimary = Color(
    0xFFF8FAFC,
  ); // Alpine Snow (16.9:1 AAA on surface)
  static const Color textSecondary = Color(
    0xFF9CA9BE,
  ); // Cool Slate (7.4:1 AAA on surface)
  static const Color textMuted = Color(
    0xFF8692A0,
  ); // Muted Slate (5.8:1 AAA/AA on surface)

  // Map Territory Tokens
  static const Color mine = primary; // Player territory (Moss Green #A3C586)
  static const Color rival =
      terracotta; // Rival territory (Muted Terracotta #C25946)

  // Status & Metric Semantics
  static const Color warning = Color(0xFFF59E0B); // Warm Amber (#F59E0B)
  static const Color error = Color(0xFFDC2626); // Safety Alert Red (#DC2626)
  static const Color info = primary; // Moss Green (#A3C586)
  static const Color success = primary; // Moss Green (#A3C586)

  // Podium Trophy Accents
  static const Color gold = Color(
    0xFFD4A373,
  ); // Trophy Warm Gold / Ochre (#D4A373)
  static const Color silver = Color(0xFFE2E8F0); // Silver Ice (#E2E8F0)
  static const Color bronze = Color(0xFFCD7F32); // Bronze Amber (#CD7F32)

  // Territory Map Render Fills & Borders (18% opacity fill, 2.0 dp stroke)
  static const Color territoryMineFill = Color(
    0x2EA3C586,
  ); // 18% Moss Green fill
  static const Color territoryMineBorder = primary; // Solid Moss Green
  static const Color territoryRivalFill = Color(
    0x2EC25946,
  ); // 18% Muted Terracotta fill
  static const Color territoryRivalBorder = rival; // Solid Muted Terracotta

  // =========================================================================
  // Backward Compatibility & Deprecated Legacy Aliases
  // =========================================================================
  @Deprecated('Use primary instead (Moss #A3C586)')
  static const Color nordicMint = primary;

  @Deprecated('Use accent instead (Ochre #D4A373)')
  static const Color solarBlaze = accent;

  @Deprecated('Use bgDeep instead (#0D0F11)')
  static const Color smokedObsidian = bgDeep;

  @Deprecated('Use surface instead (#16191D)')
  static const Color nordicTitanium = surface;

  @Deprecated('Use rival instead (Terracotta #C25946)')
  static const Color royalAmethyst = rival;

  @Deprecated('Use primary instead')
  static const Color electricBlue = primary;

  @Deprecated('Use accent instead')
  static const Color mustardYellow = accent;

  @Deprecated('Use surface instead')
  static const Color darkGraphite = surface;

  @Deprecated('Use primary instead')
  static const Color laserCyan = primary;

  @Deprecated('Use accent instead')
  static const Color kineticVolt = accent;

  @Deprecated('Use accent instead')
  static const Color yellow = accent;

  @Deprecated('Use accentContainer instead')
  static const Color accentGlow = accentContainer;

  @Deprecated('Use primary instead')
  static const Color cyanThruster = primary;

  @Deprecated('Use error instead')
  static const Color actionRed = error;

  @Deprecated('Use warning instead')
  static const Color amberStreak = warning;

  @Deprecated('Use success instead')
  static const Color positiveGreen = success;

  @Deprecated('Use textPrimary instead')
  static const Color offWhite = textPrimary;

  @Deprecated('Use accent instead')
  static const Color secondary = accent;

  @Deprecated('Use info instead')
  static const Color accentSecondary = info;

  @Deprecated('Use error instead')
  static const Color amberRed = error;

  @Deprecated('Use error instead')
  static const Color amberRedBright = error;
}
