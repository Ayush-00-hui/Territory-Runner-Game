import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Territory Runner Design System: Shared Motion & Haptics Tokens
/// Enforces purposeful athletic timing (150-250ms ease-out).
/// No looping pulses, no bounces.
/// Strictly honors [MediaQuery.disableAnimations] across all screens.
class AppMotion {
  AppMotion._();

  // Durations (150 - 250 ms)
  static const Duration fast = Duration(
    milliseconds: 150,
  ); // Micro-interactions, press states, chips
  static const Duration standard = Duration(
    milliseconds: 220,
  ); // Tab switches, card reveals, HUD slide
  static const Duration sheet = Duration(
    milliseconds: 250,
  ); // Modal bottom sheets & dialogs
  static const Duration countUp = Duration(
    milliseconds: 500,
  ); // Tabular number roll-ups
  static const Duration capture = Duration(
    milliseconds: 600,
  ); // Single polygon fill celebration

  // Interactive Press State
  static const double pressScale = 0.97;

  // Curves (Smooth sports-grade decel)
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;

  /// Global accessibility helper: returns true if reduced motion is requested
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Ergonomic alias for [shouldReduceMotion]
  static bool isReducedMotion(BuildContext context) =>
      shouldReduceMotion(context);

  /// Scales duration to zero if reduced motion is enabled
  static Duration duration(BuildContext context, Duration baseDuration) {
    if (shouldReduceMotion(context)) {
      return Duration.zero;
    }
    return baseDuration;
  }

  // --- PURPOSEFUL HAPTICS ---

  /// Light selection tick on tap / press
  static void selectionTick() {
    HapticFeedback.selectionClick();
  }

  /// Light impact tick
  static void lightTick() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact on milestone, goal closure or tab switch
  static void mediumTick() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact for capture celebration / hold-to-finish completion
  static void heavyBurst() {
    HapticFeedback.heavyImpact();
  }

  // --- SHARED PAGE TRANSITIONS (FADE + SUBTLE SLIDE) ---

  /// Creates a shared sports-grade transition: subtle fade + 12px vertical slide
  static Widget sharedAxisTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
  }) {
    if (shouldReduceMotion(context)) {
      return child;
    }

    final curved = CurvedAnimation(parent: animation, curve: easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  /// Ergonomic page route builder using [sharedAxisTransition] and [standard] duration.
  static Route<T> pageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: standard,
      reverseTransitionDuration: standard,
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (context, animation, _, child) {
        return sharedAxisTransition(
          context: context,
          animation: animation,
          child: child,
        );
      },
    );
  }
}
