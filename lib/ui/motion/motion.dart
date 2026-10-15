import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Territory Runner Design System: Shared Motion & Haptics Tokens
/// Enforces purposeful, sports-feel animations (150-300ms for UI, up to 900ms for capture).
/// Checks [MediaQuery.disableAnimations] to respect reduced-motion user preferences.
class AppMotion {
  AppMotion._();

  // Durations
  static const Duration fast = Duration(milliseconds: 150);      // Micro-interactions, button presses, chips
  static const Duration standard = Duration(milliseconds: 250);  // HUD sliding, tabs, cards
  static const Duration sheet = Duration(milliseconds: 320);     // Modal bottom sheets
  static const Duration countUp = Duration(milliseconds: 600);   // Stat tile number roll-up
  static const Duration capture = Duration(milliseconds: 900);   // Big territory capture moment
  static const Duration replay = Duration(milliseconds: 1500);   // Route path replay (skippable)

  // Curves
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve bounceOut = Curves.easeOutBack;

  /// Returns true if reduced motion is requested on the device
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Scales duration to zero if reduced motion is enabled
  static Duration duration(BuildContext context, Duration baseDuration) {
    if (shouldReduceMotion(context)) {
      return Duration.zero;
    }
    return baseDuration;
  }

  // --- PURPOSEFUL HAPTICS ---

  /// Light haptic feedback for button taps and selection clicks
  static void lightTick() {
    HapticFeedback.lightImpact();
  }

  /// Medium haptic feedback for mode switching, tab selection, and loop closure
  static void mediumTick() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy haptic burst for major milestones: run start, territory capture, rank up
  static void heavyBurst() {
    HapticFeedback.heavyImpact();
  }

  /// Selection tick for subtle slider / list movement
  static void selectionTick() {
    HapticFeedback.selectionClick();
  }
}
