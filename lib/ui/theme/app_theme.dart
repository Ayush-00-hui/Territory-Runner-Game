import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_text.dart';
import '../motion/motion.dart';

/// Territory Runner Design System: Global ThemeData Configuration
/// Dark-only theme (Amber Red + Off-White + Electric Yellow).
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
      extensions: const [AppPalette.dark],

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        secondaryContainer: AppColors.accentContainer,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainer: AppColors.surface2,
        surfaceContainerHigh: AppColors.bgElevated,
        error: AppColors.error,
        onError: AppColors.onPrimary,
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

      // Buttons Theme (Electric Blue Primary CTA & Mustard Yellow Accent Details)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: AppText.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: AppText.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppText.button,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 0,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
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
            return AppColors.onPrimary;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surface2;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.border),
      ),

      // Slider Theme
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surface2,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primaryContainer,
        trackHeight: 4.0,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
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

  /// Outdoor High-Contrast Daylight Light Theme
  /// Calibrated for outdoor visibility under direct sunlight with WCAG AA compliance.
  static ThemeData get lightTheme {
    const palette = AppPalette.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppText.fontFamily,
      scaffoldBackgroundColor: palette.bgDeep,
      canvasColor: palette.bgDeep,
      cardColor: palette.surface,
      extensions: const [palette],

      colorScheme: ColorScheme.light(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        primaryContainer: palette.primaryContainer,
        secondary: palette.accent,
        onSecondary: palette.onAccent,
        secondaryContainer: palette.accentContainer,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainer: palette.surface2,
        surfaceContainerHigh: palette.bgElevated,
        error: palette.error,
        onError: palette.onPrimary,
        outline: palette.border,
        outlineVariant: palette.borderSubtle,
        scrim: palette.scrim,
      ),

      textTheme: TextTheme(
        displayLarge: AppText.displayLarge.copyWith(color: palette.textPrimary),
        displayMedium: AppText.displayMedium.copyWith(
          color: palette.textPrimary,
        ),
        displaySmall: AppText.displaySmall.copyWith(color: palette.textPrimary),
        headlineLarge: AppText.headlineLarge.copyWith(
          color: palette.textPrimary,
        ),
        headlineMedium: AppText.headlineMedium.copyWith(
          color: palette.textPrimary,
        ),
        headlineSmall: AppText.headlineSmall.copyWith(
          color: palette.textPrimary,
        ),
        titleLarge: AppText.titleLarge.copyWith(color: palette.textPrimary),
        titleMedium: AppText.titleMedium.copyWith(color: palette.textPrimary),
        titleSmall: AppText.titleSmall.copyWith(color: palette.textPrimary),
        bodyLarge: AppText.bodyLarge.copyWith(color: palette.textPrimary),
        bodyMedium: AppText.bodyMedium.copyWith(color: palette.textPrimary),
        bodySmall: AppText.bodySmall.copyWith(color: palette.textSecondary),
        labelLarge: AppText.labelLarge.copyWith(color: palette.textPrimary),
        labelMedium: AppText.labelMedium.copyWith(color: palette.textPrimary),
        labelSmall: AppText.labelSmall.copyWith(color: palette.textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: palette.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.textPrimary, size: 20),
        titleTextStyle: TextStyle(
          fontFamily: AppText.fontFamily,
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: palette.bgDeep,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: AppText.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: AppText.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface2,
        hintStyle: AppText.caption.copyWith(color: palette.textMuted),
        labelStyle: AppText.bodyMedium.copyWith(color: palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: palette.border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: palette.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: palette.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: palette.error, width: 1.0),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.onPrimary;
          }
          return palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primary;
          }
          return palette.surface2;
        }),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: palette.primary,
        inactiveTrackColor: palette.surface2,
        thumbColor: palette.primary,
        overlayColor: palette.primaryContainer,
        trackHeight: 4.0,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.surface2,
        circularTrackColor: palette.surface2,
      ),

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
