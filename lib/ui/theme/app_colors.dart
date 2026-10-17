import 'package:flutter/material.dart';

/// Territory Runner Design System: Color Palette & Semantic Tokens
class AppColors {
  AppColors._();

  // Core Surface & Background Palette (Whoop / Oura Calm Obsidian)
  static const Color bgDeep = Color(0xFF0B0C0E);
  static const Color bgElevated = Color(0xFF121417);
  static const Color surface = Color(0xFF16191D);
  static const Color surface2 = Color(0xFF1F2329);
  static const Color surfaceGlass = Color(0xF2121417);
  static const Color border = Color(0xFF2A2E35);
  static const Color borderSubtle = Color(0x1AFFFFFF);

  // Primary Brand Accent (Whoop Athletic Mint)
  static const Color accent = Color(0xFF3DDC97);
  static const Color accentSecondary = Color(0xFF5C85FF); // Calm Slate Blue
  static const Color secondary = Color(0xFFE5A93C);      // Muted Amber
  static const Color cyanThruster = Color(0xFF5C85FF);

  // Semantic Territory & Feedback Tokens
  static const Color mine = Color(0xFF3DDC97);          // Sovereign Territory (Mint)
  static const Color rival = Color(0xFFE05353);         // Contested / Rival Territory (Muted Crimson)
  static const Color warning = Color(0xFFE5A93C);       // Telemetry / Anomaly Alert (Amber)
  static const Color info = Color(0xFF5C85FF);          // Guidance / Pacer (Slate Blue)
  static const Color error = Color(0xFFE05353);         // Error / Rejection Alert

  // Legacy Aliases
  static const Color accentGlow = Color(0x1A3DDC97);
  static const Color positiveGreen = Color(0xFF3DDC97);
  static const Color actionRed = Color(0xFFE05353);
  static const Color amberStreak = Color(0xFFE5A93C);

  // Typography Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E9BAE);
  static const Color textMuted = Color(0xFF5A6678);

  // Podium Trophy Accents
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
}
