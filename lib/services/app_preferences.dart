import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../ui/ui.dart';

/// Supported distance and area measurement systems
enum DistanceUnit { metric, imperial }

/// Global Application Preferences & Hardware Feedback Service
///
/// Owns persistent user preferences for distance units and sensory feedback,
/// alongside unit-conversion, formatting helpers, and vibration triggers.
class AppPreferences {
  static final AppPreferences _instance = AppPreferences._internal();
  factory AppPreferences() => _instance;

  static const String _prefHapticsKey = 'pref_voice_coach_haptics_enabled';
  static const String _prefUnitKey = 'pref_distance_unit';
  static const String _prefLeftHandedKey = 'pref_left_handed_mode';
  static const String _prefDailyGoalKmKey = 'pref_daily_goal_km';
  static const String _prefCountdownVoiceKey = 'pref_countdown_voice_enabled';
  static const String _prefAutoSaveCardKey = 'pref_auto_save_run_card';
  static const String _prefDemoModeUnlockedKey = 'pref_demo_mode_unlocked';
  static const String _prefDemoModeEnabledKey = 'pref_demo_mode_enabled';
  static const String _prefBodyWeightKgKey = 'pref_body_weight_kg';

  bool _isHapticsEnabled = true;
  DistanceUnit _unit = DistanceUnit.metric;
  bool _isLeftHandedMode = false;
  double? _dailyGoalKm;
  bool _isCountdownVoiceEnabled = true;
  bool _isAutoSaveCardEnabled = true;
  bool _isDemoModeUnlocked = false;
  bool _isDemoModeEnabled = false;
  double? _bodyWeightKg;
  bool _isInitialized = false;

  final ValueNotifier<bool> leftHandedModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double?> dailyGoalKmNotifier = ValueNotifier<double?>(
    null,
  );
  final ValueNotifier<bool> demoModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> demoUnlockedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double?> bodyWeightKgNotifier = ValueNotifier<double?>(
    null,
  );

  bool get isHapticsEnabled => _isHapticsEnabled;
  DistanceUnit get unit => _unit;
  bool get isLeftHandedMode => _isLeftHandedMode;
  double? get dailyGoalKm => _dailyGoalKm;
  bool get isCountdownVoiceEnabled => _isCountdownVoiceEnabled;
  bool get isAutoSaveCardEnabled => _isAutoSaveCardEnabled;
  bool get isDemoModeUnlocked => _isDemoModeUnlocked;
  bool get isDemoModeEnabled => _isDemoModeEnabled;
  double? get bodyWeightKg => _bodyWeightKg;
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
      AppMotion.hapticsEnabled = _isHapticsEnabled;
      _isCountdownVoiceEnabled = prefs.getBool(_prefCountdownVoiceKey) ?? true;
      _isAutoSaveCardEnabled = prefs.getBool(_prefAutoSaveCardKey) ?? true;
      _isLeftHandedMode = prefs.getBool(_prefLeftHandedKey) ?? false;
      leftHandedModeNotifier.value = _isLeftHandedMode;
      _dailyGoalKm = prefs.getDouble(_prefDailyGoalKmKey);
      dailyGoalKmNotifier.value = _dailyGoalKm;
      final unitStr = prefs.getString(_prefUnitKey) ?? 'metric';
      _unit = unitStr == 'imperial'
          ? DistanceUnit.imperial
          : DistanceUnit.metric;
      _isDemoModeUnlocked = prefs.getBool(_prefDemoModeUnlockedKey) ?? false;
      demoUnlockedNotifier.value = _isDemoModeUnlocked;
      _isDemoModeEnabled = prefs.getBool(_prefDemoModeEnabledKey) ?? false;
      demoModeNotifier.value = _isDemoModeEnabled;
      _bodyWeightKg = prefs.getDouble(_prefBodyWeightKgKey);
      bodyWeightKgNotifier.value = _bodyWeightKg;
      _isInitialized = true;
    } catch (e) {
      AppLogger.debug('Init note: $e', tag: 'AppPreferences');
    }
  }

  /// Sets or clears the user's daily running distance goal in kilometers
  Future<void> setDailyGoalKm(double? goalKm) async {
    _dailyGoalKm = (goalKm != null && goalKm > 0) ? goalKm : null;
    dailyGoalKmNotifier.value = _dailyGoalKm;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dailyGoalKm != null) {
        await prefs.setDouble(_prefDailyGoalKmKey, _dailyGoalKm!);
      } else {
        await prefs.remove(_prefDailyGoalKmKey);
      }
    } catch (_) {}
  }

  /// Toggles persistent left-handed mirror mode for map screen controls
  Future<void> toggleLeftHandedMode(bool enabled) async {
    _isLeftHandedMode = enabled;
    leftHandedModeNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLeftHandedKey, enabled);
    } catch (_) {}
  }

  /// Toggles persistent haptic feedback
  Future<void> toggleHaptics(bool enabled) async {
    _isHapticsEnabled = enabled;
    AppMotion.hapticsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHapticsKey, enabled);
    } catch (_) {}
  }

  /// Toggles countdown voice announcements and audio beeps
  Future<void> toggleCountdownVoice(bool enabled) async {
    _isCountdownVoiceEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCountdownVoiceKey, enabled);
    } catch (_) {}
  }

  /// Toggles automatic gallery export when completing a GPS run
  Future<void> toggleAutoSaveCard(bool enabled) async {
    _isAutoSaveCardEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoSaveCardKey, enabled);
    } catch (_) {}
  }

  /// Updates persistent measurement unit system (metric or imperial)
  Future<void> setUnit(DistanceUnit unit) async {
    _unit = unit;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefUnitKey,
        unit == DistanceUnit.imperial ? 'imperial' : 'metric',
      );
    } catch (_) {}
  }

  /// Unlocks demo & simulation developer settings (e.g. after tapping version row 7 times)
  Future<void> unlockDemoMode() async {
    _isDemoModeUnlocked = true;
    demoUnlockedNotifier.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDemoModeUnlockedKey, true);
    } catch (_) {}
  }

  /// Toggles demo mode & GPS simulation controls
  Future<void> toggleDemoMode(bool enabled) async {
    _isDemoModeEnabled = enabled;
    demoModeNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDemoModeEnabledKey, enabled);
    } catch (_) {}
  }

  /// Manually inject demo mode state for testing
  void setMockDemoState({bool? unlocked, bool? enabled}) {
    if (unlocked != null) {
      _isDemoModeUnlocked = unlocked;
      demoUnlockedNotifier.value = unlocked;
    }
    if (enabled != null) {
      _isDemoModeEnabled = enabled;
      demoModeNotifier.value = enabled;
    }
  }

  /// Sets or clears the user's optional body weight in kilograms (null = default 70.0 kg fallback).
  Future<void> setBodyWeightKg(double? weightKg) async {
    _bodyWeightKg = (weightKg != null && weightKg > 0) ? weightKg : null;
    bodyWeightKgNotifier.value = _bodyWeightKg;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_bodyWeightKg != null) {
        await prefs.setDouble(_prefBodyWeightKgKey, _bodyWeightKg!);
      } else {
        await prefs.remove(_prefBodyWeightKgKey);
      }
    } catch (_) {}
  }

  /// Manually inject body weight state for testing
  void setMockBodyWeight(double? weightKg) {
    _bodyWeightKg = (weightKg != null && weightKg > 0) ? weightKg : null;
    bodyWeightKgNotifier.value = _bodyWeightKg;
  }

  // --- CALORIE ESTIMATION HELPERS ---

  /// Estimates gross energy expenditure in kilocalories (kcal).
  ///
  /// Uses the documented ACSM / Margaria metabolic formula:
  ///   Calories (kcal) = Distance (km) * Body Weight (kg) * Factor
  ///
  /// Activity factors (kcal / kg / km):
  /// - Running: 1.036 (Margaria et al. 1963, "Energy cost of running in humans")
  /// - Walking: 0.73 (American College of Sports Medicine metabolic equation)
  /// - Cycling: 0.40 (ACSM outdoor cycling metabolic guidelines)
  ///
  /// If [customWeightKg] is not provided, uses [_bodyWeightKg] if configured,
  /// otherwise defaults to a standard reference runner weight of 70.0 kg (~154.3 lbs).
  int estimateCalories({
    required double distanceKm,
    double? customWeightKg,
    String activityType = 'running',
  }) {
    if (distanceKm <= 0) return 0;
    final weight = customWeightKg ?? _bodyWeightKg ?? 70.0;
    final double factor;
    switch (activityType.toLowerCase()) {
      case 'walking':
      case 'walk':
        factor = 0.73;
        break;
      case 'cycling':
      case 'cycle':
      case 'bike':
      case 'biking':
        factor = 0.40;
        break;
      case 'running':
      case 'run':
      default:
        factor = 1.036;
        break;
    }
    return (distanceKm * weight * factor).round();
  }

  /// Formats estimated calories with the required "(est.)" label.
  /// Example: "~363 kcal (est.)" or "+~363 kcal (est.)" if [withPrefixPlus] is true.
  String formatCalories(int calories, {bool withPrefixPlus = false}) {
    final prefix = withPrefixPlus ? '+~' : '~';
    return '$prefix$calories kcal (est.)';
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
  String get distanceUnitNoun =>
      _unit == DistanceUnit.imperial ? 'mile' : 'kilometer';

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

  // --- RUN HAPTIC HELPERS ---

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
      AppLogger.warning(
        'Haptic vibration error: $e',
        tag: 'AppPreferences',
        error: e,
      );
    }
  }

  /// Preset run vibration patterns
  Future<void> triggerRunStartHaptic() => triggerHaptic([0, 150, 100, 150]);
  Future<void> triggerMilestoneHaptic() => triggerHaptic([0, 200, 150, 200]);
  Future<void> triggerLoopClosedHaptic() => triggerHaptic([0, 80, 80, 80]);
  Future<void> triggerAttackHaptic() =>
      triggerHaptic([0, 250, 100, 250, 100, 250]);
  Future<void> triggerRunCompleteHaptic() => triggerHaptic([0, 300, 150, 300]);
  Future<void> triggerGoalAchievedHaptic() =>
      triggerHaptic([0, 150, 80, 150, 80, 250]);
  // Auto-pause and auto-resume haptics removed to prevent sensory vibration clutter
  Future<void> triggerAutoPauseHaptic() async {}
  Future<void> triggerAutoResumeHaptic() async {}
}
