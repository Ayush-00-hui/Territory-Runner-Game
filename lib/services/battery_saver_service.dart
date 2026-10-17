import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing Endurance Battery Saver mode for marathon and long runs.
///
/// Reduces AMOLED display battery consumption, tunes GPS sampling intervals,
/// and suppresses non-critical map animations.
class BatterySaverService {
  static final BatterySaverService _instance = BatterySaverService._internal();
  factory BatterySaverService() => _instance;

  static const String _prefBatterySaverKey = 'pref_battery_saver_enabled';

  final ValueNotifier<bool> isBatterySaverNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isAmoledHudActiveNotifier = ValueNotifier<bool>(false);

  bool _isInitialized = false;

  bool get isBatterySaverEnabled => isBatterySaverNotifier.value;
  bool get isAmoledHudActive => isAmoledHudActiveNotifier.value;

  /// Recommended GPS update interval (milliseconds)
  int get gpsIntervalMs => isBatterySaverEnabled ? 3000 : 1000;

  /// Recommended GPS distance filter threshold (meters)
  int get gpsDistanceFilterMeters => isBatterySaverEnabled ? 8 : 2;

  /// Whether map layer pulse animations and tile tilt should be suppressed
  bool get shouldDisableAnimations => isBatterySaverEnabled;

  BatterySaverService._internal() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefBatterySaverKey) ?? false;
      isBatterySaverNotifier.value = enabled;
      _isInitialized = true;
    } catch (_) {
      // In-memory fallback for test environments
      _isInitialized = true;
    }
  }

  /// Toggles Endurance Battery Saver mode
  Future<void> setBatterySaver(bool enabled) async {
    isBatterySaverNotifier.value = enabled;
    if (!enabled) {
      isAmoledHudActiveNotifier.value = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBatterySaverKey, enabled);
    } catch (_) {}
  }

  /// Activates or deactivates the pure black AMOLED low-power HUD
  void setAmoledHudActive(bool active) {
    if (isBatterySaverEnabled) {
      isAmoledHudActiveNotifier.value = active;
    } else {
      isAmoledHudActiveNotifier.value = false;
    }
  }

  /// Visible for testing to reset state
  @visibleForTesting
  void resetForTest({bool enabled = false}) {
    isBatterySaverNotifier.value = enabled;
    isAmoledHudActiveNotifier.value = false;
  }
}
