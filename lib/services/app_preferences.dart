import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Supported distance and area measurement systems
enum DistanceUnit {
  metric,
  imperial,
}

/// Global Application Preferences & Hardware Feedback Service
///
/// Owns persistent user preferences for distance units and tactical haptics,
/// alongside unit-conversion, formatting helpers, and tactical vibration triggers.
class AppPreferences {
  static final AppPreferences _instance = AppPreferences._internal();
  factory AppPreferences() => _instance;

  static const String _prefHapticsKey = 'pref_voice_coach_haptics_enabled';
  static const String _prefUnitKey = 'pref_distance_unit';

  bool _isHapticsEnabled = true;
  DistanceUnit _unit = DistanceUnit.metric;
  bool _isInitialized = false;

  bool get isHapticsEnabled => _isHapticsEnabled;
  DistanceUnit get unit => _unit;
  bool get isInitialized => _isInitialized;

  AppPreferences._internal() {
    init();
  }

  /// Initializes preferences from persistent storage
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isHapticsEnabled = prefs.getBool(_prefHapticsKey) ?? true;
      final unitStr = prefs.getString(_prefUnitKey) ?? 'metric';
      _unit = unitStr == 'imperial' ? DistanceUnit.imperial : DistanceUnit.metric;
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AppPreferences] Init note: $e');
    }
  }

  /// Toggles persistent tactical haptic feedback
  Future<void> toggleHaptics(bool enabled) async {
    _isHapticsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHapticsKey, enabled);
    } catch (_) {}
  }

  /// Updates persistent measurement unit system (metric or imperial)
  Future<void> setUnit(DistanceUnit unit) async {
    _unit = unit;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUnitKey, unit == DistanceUnit.imperial ? 'imperial' : 'metric');
    } catch (_) {}
  }

  // --- UNIT CONVERSION & FORMATTING HELPERS ---

  /// Converts a kilometer value into current unit (km or miles)
  double convertDistance(double distanceKm) {
    if (_unit == DistanceUnit.imperial) {
      return distanceKm * 0.621371;
    }
    return distanceKm;
  }

  /// Returns distance formatted with unit label (e.g. "5.00 km" or "3.11 mi")
  String formatDistance(double distanceKm, {int fractionDigits = 2}) {
    final converted = convertDistance(distanceKm);
    final label = distanceUnitLabel;
    return '${converted.toStringAsFixed(fractionDigits)} $label';
  }

  /// Returns unit abbreviation: "km" or "mi"
  String get distanceUnitLabel => _unit == DistanceUnit.imperial ? 'mi' : 'km';

  /// Returns full unit singular noun: "mile" or "kilometer"
  String get distanceUnitNoun => _unit == DistanceUnit.imperial ? 'mile' : 'kilometer';

  /// Returns pace label: "/km" or "/mi"
  String get paceUnitLabel => _unit == DistanceUnit.imperial ? '/mi' : '/km';

  /// Formats surface area based on measurement system
  /// Metric: m² (or km² if >= 10,000 m²)
  /// Imperial: sq ft (or acres if >= 43,560 sq ft)
  String formatArea(double areaSqMeters) {
    if (_unit == DistanceUnit.imperial) {
      final double sqFt = areaSqMeters * 10.7639;
      if (sqFt >= 43560) {
        final double acres = sqFt / 43560.0;
        return '${acres.toStringAsFixed(1)} acres';
      } else {
        return '${sqFt.toStringAsFixed(0)} sq ft';
      }
    } else {
      if (areaSqMeters >= 10000) {
        final double km2 = areaSqMeters / 1000000.0;
        return '${km2.toStringAsFixed(2)} km²';
      } else {
        return '${areaSqMeters.toStringAsFixed(0)} m²';
      }
    }
  }

  // --- TACTICAL HAPTIC HELPERS ---

  /// Lightweight tactile vibration dispatcher using [Vibration] package
  /// Respects [_isHapticsEnabled] setting.
  Future<void> triggerHaptic([List<int> pattern = const [0, 80]]) async {
    if (!_isHapticsEnabled) return;
    try {
      final bool hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: pattern);
      }
    } catch (e) {
      debugPrint('[AppPreferences] Haptic vibration error: $e');
    }
  }

  /// Preset tactical vibration patterns
  Future<void> triggerRunStartHaptic() => triggerHaptic([0, 150, 100, 150]);
  Future<void> triggerMilestoneHaptic() => triggerHaptic([0, 200, 150, 200]);
  Future<void> triggerLoopClosedHaptic() => triggerHaptic([0, 80, 80, 80]);
  Future<void> triggerAttackHaptic() => triggerHaptic([0, 250, 100, 250, 100, 250]);
  Future<void> triggerRunCompleteHaptic() => triggerHaptic([0, 300, 150, 300]);
  Future<void> triggerGoalAchievedHaptic() => triggerHaptic([0, 150, 80, 150, 80, 250]);
  Future<void> triggerAutoPauseHaptic() => triggerHaptic([0, 100, 100, 100]);
  Future<void> triggerAutoResumeHaptic() => triggerHaptic([0, 80]);
}
