import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../models/user_body_profile.dart';
import '../ui/ui.dart';
import 'calorie_engine_service.dart';
import 'calorie_model_engine.dart';

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
  static const String _prefBodyProfileKey = 'pref_user_body_profile_v1';
  static const String _prefHasSkippedBodyDetailsKey =
      'pref_has_skipped_body_details';
  static const String _prefWatchCalorieFactorKey =
      'pref_watch_calorie_factor_v1';
  static const String _prefWatchCalorieSessionsKey =
      'pref_watch_calorie_sessions_v1';

  bool _isHapticsEnabled = true;
  DistanceUnit _unit = DistanceUnit.metric;
  bool _isLeftHandedMode = false;
  double? _dailyGoalKm;
  bool _isCountdownVoiceEnabled = true;
  bool _isAutoSaveCardEnabled = true;
  bool _isDemoModeUnlocked = false;
  bool _isDemoModeEnabled = false;
  double? _bodyWeightKg;
  UserBodyProfile? _bodyProfile;
  bool _hasSkippedBodyDetails = false;
  double? _watchCalorieFactor;
  List<Map<String, double>> _watchCalibrationSessions = [];
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
  final ValueNotifier<UserBodyProfile?> bodyProfileNotifier =
      ValueNotifier<UserBodyProfile?>(null);
  final ValueNotifier<double?> watchCalorieFactorNotifier =
      ValueNotifier<double?>(null);

  bool get isHapticsEnabled => _isHapticsEnabled;
  DistanceUnit get unit => _unit;
  bool get isLeftHandedMode => _isLeftHandedMode;
  double? get dailyGoalKm => _dailyGoalKm;
  bool get isCountdownVoiceEnabled => _isCountdownVoiceEnabled;
  bool get isAutoSaveCardEnabled => _isAutoSaveCardEnabled;
  bool get isDemoModeUnlocked => _isDemoModeUnlocked;
  bool get isDemoModeEnabled => _isDemoModeEnabled;
  double? get bodyWeightKg => _bodyWeightKg;
  UserBodyProfile? get bodyProfile => _bodyProfile;
  bool get hasBodyProfile => _bodyProfile != null && _bodyProfile!.isCustomized;
  bool get hasSkippedBodyDetails => _hasSkippedBodyDetails;
  double? get watchCalorieFactor => _watchCalorieFactor;
  int get watchCalibrationSessionCount => _watchCalibrationSessions.length;
  bool get isWatchCalibrationActive => _watchCalorieFactor != null;
  List<Map<String, double>> get watchCalibrationSessions =>
      List.unmodifiable(_watchCalibrationSessions);
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

      _hasSkippedBodyDetails =
          prefs.getBool(_prefHasSkippedBodyDetailsKey) ?? false;

      // Body profile migration / loading
      final rawProfile = prefs.getString(_prefBodyProfileKey);
      if (rawProfile != null && rawProfile.isNotEmpty) {
        try {
          _bodyProfile = UserBodyProfile.fromJson(
            jsonDecode(rawProfile) as Map<String, dynamic>,
          );
          if (_bodyProfile != null) {
            _bodyWeightKg = _bodyProfile!.weightKg;
            bodyWeightKgNotifier.value = _bodyWeightKg;
          }
        } catch (e) {
          AppLogger.debug(
            'Failed to parse body profile: $e',
            tag: 'AppPreferences',
          );
        }
      } else if (_bodyWeightKg != null && _bodyWeightKg! > 0) {
        // Transparent migration: existing legacy bodyWeightKg migrated non-destructively
        final currentYear = DateTime.now().year;
        _bodyProfile = UserBodyProfile(
          weightKg: _bodyWeightKg!,
          heightCm: UserBodyProfile.defaultHeightCm,
          gender: UserBodyProfile.defaultGender,
          birthYear: currentYear - UserBodyProfile.defaultAge,
          isCustomized: false,
          isMigratedWeightOnly: true,
        );
        await prefs.setString(
          _prefBodyProfileKey,
          jsonEncode(_bodyProfile!.toJson()),
        );
      }
      bodyProfileNotifier.value = _bodyProfile;

      // Watch calorie calibration loading
      _watchCalorieFactor = prefs.getDouble(_prefWatchCalorieFactorKey);
      watchCalorieFactorNotifier.value = _watchCalorieFactor;
      final rawSessions = prefs.getString(_prefWatchCalorieSessionsKey);
      if (rawSessions != null && rawSessions.isNotEmpty) {
        try {
          final list = jsonDecode(rawSessions) as List;
          _watchCalibrationSessions = list
              .map(
                (e) => Map<String, double>.from(
                  (e as Map).map(
                    (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
                  ),
                ),
              )
              .toList();
        } catch (_) {}
      }

      // Initialize ML surrogate calorie engine in background
      CalorieModelEngine().loadProductionModel().ignore();

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
    if (_bodyProfile != null) {
      if (_bodyWeightKg != null) {
        _bodyProfile = _bodyProfile!.copyWith(weightKg: _bodyWeightKg!);
      }
      bodyProfileNotifier.value = _bodyProfile;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_bodyWeightKg != null) {
        await prefs.setDouble(_prefBodyWeightKgKey, _bodyWeightKg!);
      } else {
        await prefs.remove(_prefBodyWeightKgKey);
      }
      if (_bodyProfile != null) {
        await prefs.setString(
          _prefBodyProfileKey,
          jsonEncode(_bodyProfile!.toJson()),
        );
      }
    } catch (_) {}
  }

  /// Manually inject body weight state for testing
  void setMockBodyWeight(double? weightKg) {
    _bodyWeightKg = (weightKg != null && weightKg > 0) ? weightKg : null;
    bodyWeightKgNotifier.value = _bodyWeightKg;
    if (_bodyProfile != null && _bodyWeightKg != null) {
      _bodyProfile = _bodyProfile!.copyWith(weightKg: _bodyWeightKg!);
      bodyProfileNotifier.value = _bodyProfile;
    }
  }

  /// Sets persistent customized body profile (stored locally on device only).
  Future<void> setBodyProfile(UserBodyProfile? profile) async {
    _bodyProfile = profile;
    bodyProfileNotifier.value = _bodyProfile;
    _bodyWeightKg = profile?.weightKg;
    bodyWeightKgNotifier.value = _bodyWeightKg;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_bodyProfile != null) {
        await prefs.setString(
          _prefBodyProfileKey,
          jsonEncode(_bodyProfile!.toJson()),
        );
        if (_bodyWeightKg != null) {
          await prefs.setDouble(_prefBodyWeightKgKey, _bodyWeightKg!);
        }
      } else {
        await prefs.remove(_prefBodyProfileKey);
        await prefs.remove(_prefBodyWeightKgKey);
      }
    } catch (_) {}
  }

  /// Permanently removes body details from device storage ("Remove my body details").
  Future<void> clearBodyProfile() async {
    _bodyProfile = null;
    _bodyWeightKg = null;
    _hasSkippedBodyDetails = false;
    bodyProfileNotifier.value = null;
    bodyWeightKgNotifier.value = null;

    await resetWatchCalibration();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefBodyProfileKey);
      await prefs.remove(_prefBodyWeightKgKey);
      await prefs.remove(_prefHasSkippedBodyDetailsKey);
    } catch (_) {}
  }

  /// Records a comparison session between user's trusted watch calories and app estimate.
  ///
  /// After at least 3 sessions, computes a bounded multiplicative factor [0.8, 1.2]
  /// using the median ratio of watch calories / model calories.
  Future<void> recordWatchCalibrationSession({
    required double userWatchKcal,
    required double modelEstimatedKcal,
  }) async {
    if (userWatchKcal <= 0 || modelEstimatedKcal <= 0) return;
    final ratio = userWatchKcal / modelEstimatedKcal;
    _watchCalibrationSessions.add({
      'user': userWatchKcal,
      'model': modelEstimatedKcal,
      'ratio': ratio,
    });
    if (_watchCalibrationSessions.length > 10) {
      _watchCalibrationSessions.removeAt(0);
    }

    if (_watchCalibrationSessions.length >= 3) {
      final ratios = _watchCalibrationSessions.map((s) => s['ratio']!).toList()
        ..sort();
      final medianRatio = ratios[ratios.length ~/ 2];
      _watchCalorieFactor = medianRatio.clamp(0.8, 1.2);
      watchCalorieFactorNotifier.value = _watchCalorieFactor;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefWatchCalorieSessionsKey,
        jsonEncode(_watchCalibrationSessions),
      );
      if (_watchCalorieFactor != null) {
        await prefs.setDouble(_prefWatchCalorieFactorKey, _watchCalorieFactor!);
      }
    } catch (_) {}
  }

  /// Clears watch calibration data and returns to default uncalibrated state.
  Future<void> resetWatchCalibration() async {
    _watchCalorieFactor = null;
    _watchCalibrationSessions.clear();
    watchCalorieFactorNotifier.value = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefWatchCalorieFactorKey);
      await prefs.remove(_prefWatchCalorieSessionsKey);
    } catch (_) {}
  }

  /// Records user skipping the first-run body details prompt.
  Future<void> setSkippedBodyDetails(bool skipped) async {
    _hasSkippedBodyDetails = skipped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHasSkippedBodyDetailsKey, skipped);
    } catch (_) {}
  }

  /// Records completed run for body profile reminder counter.
  Future<void> recordCompletedRunForBodyProfile() async {
    // If user already customized profile or dismissed reminder, no need to track
    if (hasBodyProfile || (_bodyProfile?.reminderDismissed ?? false)) {
      return;
    }
    final currentProfile = _bodyProfile ?? UserBodyProfile.referenceAdult();
    final updated = currentProfile.copyWith(
      skippedRunCount: currentProfile.skippedRunCount + 1,
    );
    _bodyProfile = updated;
    bodyProfileNotifier.value = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefBodyProfileKey, jsonEncode(updated.toJson()));
    } catch (_) {}
  }

  /// Dismisses the one-time post-run reminder card permanently.
  Future<void> dismissBodyDetailsReminder() async {
    if (_bodyProfile == null) return;
    final updated = _bodyProfile!.copyWith(reminderDismissed: true);
    _bodyProfile = updated;
    bodyProfileNotifier.value = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefBodyProfileKey, jsonEncode(updated.toJson()));
    } catch (_) {}
  }

  /// Injects mock body profile for testing.
  void setMockBodyProfile(UserBodyProfile? profile) {
    _bodyProfile = profile;
    bodyProfileNotifier.value = _bodyProfile;
    _bodyWeightKg = profile?.weightKg;
    bodyWeightKgNotifier.value = _bodyWeightKg;
  }

  /// Resets internal initialization state for test harness setup.
  void resetForTesting() {
    _isInitialized = false;
  }

  // --- CALORIE ESTIMATION HELPERS ---

  /// Estimates gross energy expenditure in kilocalories (kcal).
  ///
  /// By default, utilizes the primary physiological engine ([PhysiologicalCalorieEngine])
  /// combining ACSM locomotion equations, Minetti et al. slope polynomials,
  /// Mifflin-St Jeor resting energy, and cycling power dynamics.
  ///
  /// Set [useLegacyFlat] to true to compute against the historical flat-factor baseline:
  ///   Calories (kcal) = Distance (km) * Body Weight (kg) * Factor
  int estimateCalories({
    required double distanceKm,
    double? customWeightKg,
    String activityType = 'running',
    double grade = 0.0,
    double? elevationGainMeters,
    double? durationMinutes,
    double? speedKmh,
    bool? useLegacyFlat,
  }) {
    if (distanceKm <= 0) return 0;
    final weight =
        customWeightKg ?? _bodyProfile?.weightKg ?? _bodyWeightKg ?? 70.0;

    final effectiveGrade = (elevationGainMeters != null && grade == 0.0 && distanceKm > 0)
        ? (elevationGainMeters / (distanceKm * 1000.0)).clamp(-0.20, 0.20)
        : grade;

    final shouldUseLegacy =
        useLegacyFlat ??
        (durationMinutes == null && speedKmh == null && effectiveGrade == 0.0);

    if (shouldUseLegacy) {
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

    final result = estimatePhysiologicalCalories(
      distanceKm: distanceKm,
      customWeightKg: weight,
      activityType: activityType,
      grade: effectiveGrade,
      durationMinutes: durationMinutes,
      speedKmh: speedKmh,
    );
    double gross = result.grossKcal;
    if (_watchCalorieFactor != null) {
      gross *= _watchCalorieFactor!;
    }
    return gross.round();
  }

  /// Predicts energy expenditure with P10/P50/P90 quantile intervals
  /// using the on-device ML surrogate model (with analytical fallback).
  CalorieQuantileResult estimateQuantileCalories({
    required double distanceKm,
    double? customWeightKg,
    String activityType = 'running',
    double grade = 0.0,
    double? elevationGainMeters,
    double cadenceSpm = 0.0,
    double? durationMinutes,
    double? speedKmh,
  }) {
    final weight =
        customWeightKg ?? _bodyProfile?.weightKg ?? _bodyWeightKg ?? 70.0;
    final durSec = (durationMinutes ?? 0.0) * 60.0;
    final spd =
        speedKmh ??
        (durationMinutes != null && durationMinutes > 0
            ? (distanceKm / (durationMinutes / 60.0))
            : 0.0);
    final effectiveGrade = (elevationGainMeters != null && grade == 0.0 && distanceKm > 0)
        ? (elevationGainMeters / (distanceKm * 1000.0)).clamp(-0.20, 0.20)
        : grade;

    return CalorieModelEngine().estimateSegment(
      distanceKm: distanceKm,
      durationSeconds: durSec,
      speedKmh: spd,
      grade: effectiveGrade,
      cadenceSpm: cadenceSpm,
      activityType: activityType,
      profile: _bodyProfile ?? UserBodyProfile.referenceAdult(weightKg: weight),
      watchCalibrationFactor: _watchCalorieFactor,
    );
  }

  /// Estimates and formats calorie estimate with an uncertainty range for post-run summary sheets.
  String estimateAndFormatCalorieRange({
    required double distanceKm,
    double? durationMinutes,
    double? speedKmh,
    double grade = 0.0,
    double? elevationGainMeters,
    double cadenceSpm = 0.0,
    String activityType = 'running',
  }) {
    final quant = estimateQuantileCalories(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      speedKmh: speedKmh,
      grade: grade,
      elevationGainMeters: elevationGainMeters,
      cadenceSpm: cadenceSpm,
      activityType: activityType,
    );
    return quant.displayRange;
  }

  /// Full physiological calculation returning gross/net calories, burn rate, and METs.
  CalorieEstimateResult estimatePhysiologicalCalories({
    required double distanceKm,
    double? customWeightKg,
    String activityType = 'running',
    double grade = 0.0,
    double? durationMinutes,
    double? speedKmh,
  }) {
    final weight =
        customWeightKg ?? _bodyProfile?.weightKg ?? _bodyWeightKg ?? 70.0;

    double defaultSpeed;
    final act = activityType.toLowerCase();
    if (act == 'walking' || act == 'walk') {
      defaultSpeed = 5.0;
    } else if (act == 'cycling' ||
        act == 'cycle' ||
        act == 'bike' ||
        act == 'biking') {
      defaultSpeed = 20.0;
    } else {
      defaultSpeed = 10.0;
    }

    final spd =
        speedKmh ??
        (durationMinutes != null && durationMinutes > 0
            ? (distanceKm / (durationMinutes / 60.0))
            : defaultSpeed);
    final durSec = (durationMinutes != null)
        ? durationMinutes * 60.0
        : (distanceKm > 0 ? (distanceKm / spd) * 3600.0 : 0.0);

    final profile =
        _bodyProfile ?? UserBodyProfile.referenceAdult(weightKg: weight);

    return PhysiologicalCalorieEngine.estimateSegment(
      distanceKm: distanceKm,
      durationSeconds: durSec,
      speedKmh: spd,
      grade: grade,
      activityType: activityType,
      profile: profile,
    );
  }

  /// Formats estimated calories with the required "(est.)" label.
  /// Example: "~376 kcal (est.)" or "+~376 kcal (est.)" if [withPrefixPlus] is true.
  String formatCalories(int calories, {bool withPrefixPlus = false}) {
    final prefix = withPrefixPlus ? '+~' : '~';
    return '$prefix$calories kcal (est.)';
  }

  /// Formats an estimated calorie range.
  /// Example: "~350–395 kcal (est.)"
  String formatCalorieRange(int minKcal, int maxKcal) {
    return '~$minKcal–$maxKcal kcal (est.)';
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
