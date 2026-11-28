import 'dart:async';
import 'package:flutter/services.dart';
import '../core/logging/app_logger.dart';

/// Service delivering tactical radio squelch tones, loop proximity frequency hums,
/// arcade victory chimes, and synchronized haptic pulses.
class ArcadeAudioService {
  static final ArcadeAudioService _instance = ArcadeAudioService._internal();
  factory ArcadeAudioService() => _instance;
  ArcadeAudioService._internal();

  bool isAudioEnabled = true;
  DateTime _lastProximityTone = DateTime.fromMillisecondsSinceEpoch(0);

  /// Plays a tactical radio squelch [kzzzt] sound and haptic burst
  /// before coach voice synthesis begins.
  Future<void> playRadioSquelch() async {
    if (!isAudioEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      AppLogger.warning('Radio squelch playback suppressed: $e', tag: 'ArcadeAudioService');
    }
  }

  /// Plays an ascending loop closure tone as runner approaches closure threshold.
  /// Distance in meters (e.g. 75m, 50m, 25m, 10m).
  Future<void> playLoopProximityCue(double distanceMeters) async {
    if (!isAudioEnabled) return;
    final now = DateTime.now();
    // Throttle proximity ticks to once every 1.5 seconds
    if (now.difference(_lastProximityTone).inMilliseconds < 1500) return;
    _lastProximityTone = now;

    try {
      if (distanceMeters < 15.0) {
        await HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.click);
      } else if (distanceMeters < 35.0) {
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.click);
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Plays triumphant territory capture victory fanfare and double heavy haptic.
  Future<void> playLoopVictoryChime() async {
    if (!isAudioEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      AppLogger.warning('Loop victory chime error: $e', tag: 'ArcadeAudioService');
    }
  }

  /// Plays tactile loot crate collection chime and celebratory vibration.
  Future<void> playCrateCollectedSound() async {
    if (!isAudioEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.lightImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      AppLogger.warning('Crate collection sound error: $e', tag: 'ArcadeAudioService');
    }
  }

  /// Plays pulsing tactical incursion alarm siren.
  Future<void> playIncursionAlarm() async {
    if (!isAudioEnabled) return;
    try {
      for (int i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (_) {}
  }
}
