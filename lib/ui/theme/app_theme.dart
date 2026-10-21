import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text.dart';
import '../motion/motion.dart';

/// Territory Runner Design System: Global ThemeData Configuration
/// Dark-only theme ("Charcoal + Ember").
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: AppColors.bgDeep,
      canvasColor: AppColors.bgDeep,
      cardColor: AppColors.surface,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        primaryContainer: AppColors.accentContainer,
        secondary: AppColors.rival,
        onSecondary: AppColors.bgDeep,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainer: AppColors.surface2,
        surfaceContainerHigh: AppColors.bgElevated,
        error: AppColors.error,
        onError: AppColors.bgDeep,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSubtle,
        scrim: AppColors.scrim,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: AppText.displayLarge,
        displayMedium: AppText.displayMedium,
        displaySmall: AppText.displaySmall,
        headlineLarge: AppText.headlineLarge,
        headlineMedium: AppText.headlineMedium,
        headlineSmall: AppText.headlineSmall,
        titleLarge: AppText.titleLarge,
        titleMedium: AppText.titleMedium,
        titleSmall: AppText.titleSmall,
        bodyLarge: AppText.bodyLarge,
        bodyMedium: AppText.bodyMedium,
        bodySmall: AppText.bodySmall,
        labelLarge: AppText.labelLarge,
        labelMedium: AppText.labelMedium,
        labelSmall: AppText.labelSmall,
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 20),
        titleTextStyle: AppText.titleMedium,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.bgDeep,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      // Card Theme (1px hairline border, no colored shadow)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),

      // Divider Theme (Hairline #FFFFFF @ 6%)
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1.0,
        space: 1.0,
      ),

      // Bottom Sheet Theme (Squircle 24dp top radius, drag handle)
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.disabled,
        dragHandleSize: Size(36.0, 4.0),
      ),

      // Dialog Theme (Squircle 24dp, hairline border)
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
        titleTextStyle: AppText.titleLarge,
        contentTextStyle: AppText.bodyMedium,
      ),

      // SnackBar Theme (Subtle floating surface)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
        contentTextStyle: AppText.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        hintStyle: AppText.bodyMedium.copyWith(color: AppColors.textMuted),
        labelStyle: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.error, width: 1.0),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onAccent;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent;
          }
          return AppColors.surface2;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.border),
      ),

      // Slider Theme
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surface2,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accentContainer,
        trackHeight: 4.0,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surface2,
        circularTrackColor: AppColors.surface2,
      ),

      // Shared Page Transitions (Fade + subtle slide)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SportsPageTransitionsBuilder(),
          TargetPlatform.iOS: _SportsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _SportsPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SportsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AppMotion.sharedAxisTransition(
      context: context,
      animation: animation,
      child: child,
    );
  }
}
