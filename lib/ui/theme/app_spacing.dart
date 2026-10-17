import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Territory Runner Design System: Spacing Scale (4/8/12/16/24/32)
class AppSpacing {
  AppSpacing._();

  // Strict 4-pt grid tokens
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // Touch target minimum (Accessibility AA)
  static const double touchTarget = 48.0;

  // Compatibility spacing tokens
  static const double s2 = 2.0;
  static const double s6 = 6.0;
  static const double s10 = 10.0;
  static const double s14 = 14.0;

  // Borders (1px hairlines)
  static final Border cardBorder = Border.all(color: AppColors.border, width: 1.0);
  static final Border cardBorderSubtle = Border.all(color: AppColors.borderSubtle, width: 1.0);
  static final Border accentBorder = Border.all(color: AppColors.accent, width: 1.2);
  static final Border rivalBorder = Border.all(color: AppColors.rival, width: 1.2);
  static final Border warningBorder = Border.all(color: AppColors.warning, width: 1.2);

  // Deprecated glow & shadow aliases remapped to neutral elevations (No colored shadows!)
  static List<BoxShadow> get cardShadow => const [];
  static List<BoxShadow> get hudShadow => AppElevation.floating;
  static List<BoxShadow> get subtleElevation => const [];
  static List<BoxShadow> neonGlow(Color color, {double blur = 8.0, double spread = 0.0}) => const [];

  // Squircle radii tokens
  static const Radius r8 = AppRadius.r8;
  static const Radius r12 = AppRadius.r12;
  static const Radius r14 = AppRadius.r12;
  static const Radius r16 = AppRadius.r16;
  static const Radius r20 = AppRadius.r16;
  static const Radius r24 = AppRadius.r24;
  static const Radius r28 = AppRadius.r24;
  static const Radius rFull = AppRadius.rFull;

  static final BorderRadius br8 = AppRadius.br8;
  static final BorderRadius br10 = AppRadius.br12;
  static final BorderRadius br12 = AppRadius.br12;
  static final BorderRadius br14 = AppRadius.br12;
  static final BorderRadius br16 = AppRadius.br16;
  static final BorderRadius br20 = AppRadius.br16;
  static final BorderRadius br24 = AppRadius.br24;
  static final BorderRadius br28 = AppRadius.br24;
  static final BorderRadius brFull = AppRadius.brFull;
}

/// Territory Runner Design System: Radius Scale (8/12/16/24/full)
class AppRadius {
  AppRadius._();

  static const Radius r8 = Radius.circular(8.0);
  static const Radius r12 = Radius.circular(12.0);
  static const Radius r16 = Radius.circular(16.0);
  static const Radius r24 = Radius.circular(24.0);
  static const Radius rFull = Radius.circular(999.0);

  static final BorderRadius br8 = BorderRadius.circular(8.0);
  static final BorderRadius br12 = BorderRadius.circular(12.0);
  static final BorderRadius br16 = BorderRadius.circular(16.0);
  static final BorderRadius br24 = BorderRadius.circular(24.0);
  static final BorderRadius brFull = BorderRadius.circular(999.0);

  /// Squircle continuous shape border generator
  static ShapeBorder squircle({
    double radius = 16.0,
    BorderSide side = BorderSide.none,
  }) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side,
    );
  }
}

/// Territory Runner Design System: Elevation Tokens
/// Depth is achieved primarily through surface tone steps (bgDeep -> surface -> surface2)
/// and 1px hairline borders (borderSubtle). A single soft neutral shadow token is
/// reserved strictly for floating overlays and FABs.
class AppElevation {
  AppElevation._();

  /// Flat (surface level)
  static const List<BoxShadow> none = [];

  /// Soft neutral shadow token strictly for floating elements (HUD, FAB, Sheets)
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x66000000), // Pure neutral black @ 40%
      blurRadius: 16.0,
      offset: Offset(0, 8),
      spreadRadius: 0.0,
    ),
  ];
}
