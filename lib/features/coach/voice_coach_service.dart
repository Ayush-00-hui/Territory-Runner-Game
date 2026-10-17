import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Supported distance and area measurement systems
enum DistanceUnit {
  metric,
  imperial,
}

/// Event types for real-time running voice & audio/haptic feedback cues
enum VoiceCoachCueType {
  runStarted,
  distanceMilestone,
  loopClosed,
  territoryUnderAttack,
  runCompleted,
}

/// On-device Tactical Voice & Haptic Coaching Dispatcher
///
/// Dispatches synthesized audio chimes, text-to-speech spoken notifications,
/// and synchronized tactical vibration pulses during live runs.
class VoiceCoachService {
  static final VoiceCoachService _instance = VoiceCoachService._internal();
  factory VoiceCoachService() => _instance;

  static const String _prefAudioKey = 'pref_voice_coach_audio_enabled';
  static const String _prefHapticsKey = 'pref_voice_coach_haptics_enabled';
  static const String _prefVolumeKey = 'pref_voice_coach_volume';
  static const String _prefUnitKey = 'pref_distance_unit';

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isAudioEnabled = true;
  bool _isHapticsEnabled = true;
  double _volume = 0.8;
  DistanceUnit _unit = DistanceUnit.metric;
  bool _isInitialized = false;

  bool get isAudioEnabled => _isAudioEnabled;
  bool get isHapticsEnabled => _isHapticsEnabled;
  double get volume => _volume;
  DistanceUnit get unit => _unit;

  VoiceCoachService._internal() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAudioEnabled = prefs.getBool(_prefAudioKey) ?? true;
      _isHapticsEnabled = prefs.getBool(_prefHapticsKey) ?? true;
      _volume = prefs.getDouble(_prefVolumeKey) ?? 0.8;
      final unitStr = prefs.getString(_prefUnitKey) ?? 'metric';
      _unit = unitStr == 'imperial' ? DistanceUnit.imperial : DistanceUnit.metric;

      // Configure TTS
      await _tts.setVolume(_volume);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('en-US');
      _isInitialized = true;
    } catch (e) {
      debugPrint('[VoiceCoach] Preferences/TTS init note: $e');
    }
  }

  Future<void> toggleAudio(bool enabled) async {
    _isAudioEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAudioKey, enabled);
    } catch (_) {}
  }

  Future<void> toggleHaptics(bool enabled) async {
    _isHapticsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHapticsKey, enabled);
    } catch (_) {}
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _tts.setVolume(_volume);
      await _audioPlayer.setVolume(_volume);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefVolumeKey, _volume);
    } catch (_) {}
  }

  Future<void> setUnit(DistanceUnit unit) async {
    _unit = unit;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUnitKey, unit == DistanceUnit.imperial ? 'imperial' : 'metric');
    } catch (_) {}
  }

  /// Announces run start with tactical chime and spoken directive
  Future<void> announceRunStart() async {
    await _triggerCue(
      cueType: VoiceCoachCueType.runStarted,
      audioAsset: 'assets/audio/run_start.wav',
      spokenText: 'Run tracking initiated. Territory conquest active.',
      hapticPattern: [0, 150, 100, 150],
    );
  }

  /// Announces a distance milestone (every 1.0 km or 1.0 mi)
  Future<void> announceDistanceMilestone(int milestone, String currentPace) async {
    final String unitLabel = _unit == DistanceUnit.imperial ? 'mile' : 'kilometer';
    final String plural = milestone > 1 ? '${unitLabel}s' : unitLabel;
    final String spokenText = '$milestone $plural completed. Current split pace: $currentPace per $unitLabel.';

    await _triggerCue(
      cueType: VoiceCoachCueType.distanceMilestone,
      audioAsset: null,
      spokenText: spokenText,
      hapticPattern: [0, 200, 150, 200],
    );
  }

  /// Announces closed loop territorial conquest
  Future<void> announceLoopClosed(double areaSqMeters) async {
    String areaSpoken;
    if (_unit == DistanceUnit.imperial) {
      final double sqFt = areaSqMeters * 10.7639;
      if (sqFt >= 43560) {
        final double acres = sqFt / 43560.0;
        areaSpoken = '${acres.toStringAsFixed(1)} acres';
      } else {
        areaSpoken = '${sqFt.toStringAsFixed(0)} square feet';
      }
    } else {
      if (areaSqMeters >= 10000) {
        final double km2 = areaSqMeters / 1000000.0;
        areaSpoken = '${km2.toStringAsFixed(2)} square kilometers';
      } else {
        areaSpoken = '${areaSqMeters.toStringAsFixed(0)} square meters';
      }
    }

    await _triggerCue(
      cueType: VoiceCoachCueType.loopClosed,
      audioAsset: 'assets/audio/loop_capture.wav',
      spokenText: 'Sector captured! Conquered $areaSpoken.',
      hapticPattern: [0, 80, 80, 80],
    );
  }

  /// Backward-compatible alias for hex/sector capture
  Future<void> announceHexConquered(int totalHexes) async {
    await _triggerCue(
      cueType: VoiceCoachCueType.loopClosed,
      audioAsset: 'assets/audio/loop_capture.wav',
      spokenText: 'Sector captured! Total sectors claimed: $totalHexes.',
      hapticPattern: [0, 80, 80, 80],
    );
  }

  /// Announces enemy attack alert on sovereign territory
  Future<void> announceTerritoryUnderAttack(String attackerCallsign) async {
    final String cleanCallsign = attackerCallsign.isNotEmpty ? attackerCallsign : 'Rival';
    await _triggerCue(
      cueType: VoiceCoachCueType.territoryUnderAttack,
      audioAsset: 'assets/audio/attack_alert.wav',
      spokenText: 'Warning! Territory under attack by $cleanCallsign.',
      hapticPattern: [0, 250, 100, 250, 100, 250],
    );
  }

  /// Announces run completion
  Future<void> announceRunComplete(double distanceKm, int sectorsClaimed) async {
    String distStr;
    if (_unit == DistanceUnit.imperial) {
      final double miles = distanceKm * 0.621371;
      distStr = '${miles.toStringAsFixed(2)} miles';
    } else {
      distStr = '${distanceKm.toStringAsFixed(2)} kilometers';
    }

    await _triggerCue(
      cueType: VoiceCoachCueType.runCompleted,
      audioAsset: 'assets/audio/run_complete.wav',
      spokenText: 'Workout completed! Conquered $sectorsClaimed sectors across $distStr.',
      hapticPattern: [0, 300, 150, 300],
    );
  }

  /// Announces run goal achievement milestone
  Future<void> announceGoalAchieved(String goalTitle) async {
    await _triggerCue(
      cueType: VoiceCoachCueType.distanceMilestone,
      audioAsset: 'assets/audio/loop_capture.wav',
      spokenText: 'Target accomplished! $goalTitle completed.',
      hapticPattern: [0, 150, 80, 150, 80, 250],
    );
  }

  /// Announces auto-pause activation
  Future<void> announceAutoPaused() async {
    await _triggerCue(
      cueType: VoiceCoachCueType.runStarted,
      audioAsset: null,
      spokenText: 'Run auto-paused.',
      hapticPattern: [0, 100, 100, 100],
    );
  }

  /// Announces auto-pause resume
  Future<void> announceAutoResumed() async {
    await _triggerCue(
      cueType: VoiceCoachCueType.runStarted,
      audioAsset: null,
      spokenText: 'Run resumed.',
      hapticPattern: [0, 80],
    );
  }

  /// Spoken general tactical announcement
  Future<void> announceEvent(String message) async {
    await _triggerCue(
      cueType: VoiceCoachCueType.runStarted,
      audioAsset: null,
      spokenText: message,
      hapticPattern: [0, 100],
    );
  }

  Future<void> _triggerCue({
    required VoiceCoachCueType cueType,
    required String? audioAsset,
    required String spokenText,
    List<int>? hapticPattern,
  }) async {
    debugPrint('[VoiceCoach] 🎙️ Spoken Cue: "$spokenText"');

    // 1. Tactical Haptics
    if (_isHapticsEnabled && hapticPattern != null) {
      try {
        final bool hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          Vibration.vibrate(pattern: hapticPattern);
        }
      } catch (e) {
        debugPrint('[VoiceCoach] Haptic vibration note: $e');
      }
    }

    // If audio is disabled, skip sound effects and spoken TTS
    if (!_isAudioEnabled) return;

    // 2. Play sound effect chime (fail silently if audio engine unavailable)
    if (audioAsset != null) {
      try {
        // Strip assets/ prefix if audioplayers AssetSource expects relative to assets/
        final assetPath = audioAsset.replaceFirst('assets/', '');
        await _audioPlayer.play(AssetSource(assetPath));
      } catch (e) {
        debugPrint('[VoiceCoach] Audio chime fallback: $e');
      }
    }

    // 3. Spoken Text-to-Speech (fail silently if TTS engine unavailable)
    try {
      await _tts.speak(spokenText);
    } catch (e) {
      debugPrint('[VoiceCoach] TTS speech fallback: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      await _audioPlayer.stop();
    } catch (_) {}
  }
}
