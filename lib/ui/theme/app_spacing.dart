import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Territory Runner Design System: Spacing, Radii, Borders, and Elevation Tokens
class AppSpacing {
  AppSpacing._();

  // Spacing Scale
  static const double s2 = 2.0;
  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // Radii Tokens
  static const Radius r8 = Radius.circular(8.0);
  static const Radius r12 = Radius.circular(12.0);
  static const Radius r14 = Radius.circular(14.0);
  static const Radius r16 = Radius.circular(16.0);
  static const Radius r20 = Radius.circular(20.0);
  static const Radius r24 = Radius.circular(24.0);
  static const Radius r28 = Radius.circular(28.0);
  static const Radius rFull = Radius.circular(999.0);

  // Border Radius Tokens
  static final BorderRadius br8 = BorderRadius.circular(8.0);
  static final BorderRadius br10 = BorderRadius.circular(10.0);
  static final BorderRadius br12 = BorderRadius.circular(12.0);
  static final BorderRadius br14 = BorderRadius.circular(14.0);
  static final BorderRadius br16 = BorderRadius.circular(16.0);
  static final BorderRadius br20 = BorderRadius.circular(20.0);
  static final BorderRadius br24 = BorderRadius.circular(24.0);
  static final BorderRadius br28 = BorderRadius.circular(28.0);
  static final BorderRadius brFull = BorderRadius.circular(999.0);

  // Borders
  static final Border cardBorder = Border.all(color: AppColors.border, width: 1.0);
  static final Border cardBorderSubtle = Border.all(color: AppColors.borderSubtle, width: 1.0);
  static final Border accentBorder = Border.all(color: AppColors.accent, width: 1.2);
  static final Border rivalBorder = Border.all(color: AppColors.rival, width: 1.2);
  static final Border warningBorder = Border.all(color: AppColors.warning, width: 1.2);

  // Elevation Shadows
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> hudShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.6),
      blurRadius: 36,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> neonGlow(Color color, {double blur = 16.0, double spread = 1.0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.45),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];
}
