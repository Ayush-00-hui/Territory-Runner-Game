import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Event types for real-time running voice & haptic feedback cues
enum VoiceCoachCueType {
  runStarted,
  kmMilestone,
  hexCaptured,
  targetPaceAlert,
  runCompleted,
}

/// Zero-cost, on-device Voice & Haptic Coaching Dispatcher
///
/// Dispatches audio cue messages and synchronized tactical haptic pulses
/// during live runs to keep runners informed without needing to stare at their phone.
class VoiceCoachService {
  static final VoiceCoachService _instance = VoiceCoachService._internal();
  factory VoiceCoachService() => _instance;

  bool _isAudioEnabled = true;
  bool _isHapticsEnabled = true;

  bool get isAudioEnabled => _isAudioEnabled;
  bool get isHapticsEnabled => _isHapticsEnabled;

  void toggleAudio(bool enabled) => _isAudioEnabled = enabled;
  void toggleHaptics(bool enabled) => _isHapticsEnabled = enabled;

  VoiceCoachService._internal();

  /// Announces run start
  Future<void> announceRunStart() async {
    await _triggerCue(
      cueType: VoiceCoachCueType.runStarted,
      message: "Run tracking initiated. Hex conquest active!",
      hapticPattern: [0, 150, 100, 150],
    );
  }

  /// Announces a distance milestone (e.g. Every 1.0 km)
  Future<void> announceDistanceMilestone(int km, String currentPace) async {
    await _triggerCue(
      cueType: VoiceCoachCueType.kmMilestone,
      message: "Milestone reached: $km kilometer completed. Current pace: $currentPace.",
      hapticPattern: [0, 200, 150, 200],
    );
  }

  /// Announces hexagonal territory conquest
  Future<void> announceHexConquered(int totalHexes) async {
    await _triggerCue(
      cueType: VoiceCoachCueType.hexCaptured,
      message: "Sector captured! Total sectors claimed: $totalHexes.",
      hapticPattern: [0, 80, 80, 80],
    );
  }

  /// Announces run completion
  Future<void> announceRunComplete(double distanceKm, int hexesClaimed) async {
    await _triggerCue(
      cueType: VoiceCoachCueType.runCompleted,
      message: "Run finished! Conquered $hexesClaimed sectors across ${distanceKm.toStringAsFixed(2)} kilometers.",
      hapticPattern: [0, 300, 150, 300],
    );
  }

  Future<void> _triggerCue({
    required VoiceCoachCueType cueType,
    required String message,
    List<int>? hapticPattern,
  }) async {
    debugPrint('[VoiceCoach] 🎙️ Audio Cue: "$message"');

    if (_isHapticsEnabled && hapticPattern != null) {
      try {
        final bool hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          Vibration.vibrate(pattern: hapticPattern);
        }
      } catch (e) {
        debugPrint('[VoiceCoach] Haptic vibration fallback: $e');
      }
    }
  }
}
