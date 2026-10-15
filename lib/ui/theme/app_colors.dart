import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
class AppColors {
  AppColors._();

  // Core Surface & Background Palette
  static const Color bgDeep = Color(0xFF0B0C10);
  static const Color bgElevated = Color(0xFF14161D);
  static const Color surface = Color(0xFF161822);
  static const Color surface2 = Color(0xFF1F2332);
  static const Color surfaceGlass = Color(0xF014161E);
  static const Color border = Color(0xFF262A3B);
  static const Color borderSubtle = Color(0x33262A3B);

  // Brand Accent (Nike / Strava / Whoop Athletic Neon Emerald)
  static const Color accent = Color(0xFF00E676);
  static const Color accentSecondary = Color(0xFF00F0FF);
  static const Color secondary = Color(0xFFFF6D00); // Solar Orange
  static const Color cyanThruster = Color(0xFF00F0FF);

  // Semantic Territory & Feedback Tokens
  static const Color mine = Color(0xFF00E676);       // Sovereign Territory (Neon Emerald)
  static const Color rival = Color(0xFFFF3366);      // Contested / Rival Territory (Coral Red)
  static const Color warning = Color(0xFFFFB300);    // Anomaly / Warning Alert (Amber)
  static const Color info = Color(0xFF00F0FF);       // Guidance / Telemetry (Cyan)

  // Legacy Aliases
  static const Color accentGlow = Color(0x3300E676);
  static const Color positiveGreen = Color(0xFF00E676);
  static const Color actionRed = Color(0xFFFF3366);
  static const Color amberStreak = Color(0xFFFFB800);

  // Typography Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E9BAE);
  static const Color textMuted = Color(0xFF5A6678);

  // Podium Trophy Accents
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
}
