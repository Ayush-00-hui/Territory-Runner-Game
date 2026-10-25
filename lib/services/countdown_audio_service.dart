import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/logging/app_logger.dart';
import 'app_preferences.dart';

/// Service managing countdown beeps and spoken vocalization prompts.
/// Configured to mix with existing ambient audio so active user music is never paused.
class CountdownAudioService {
  static final CountdownAudioService _instance =
      CountdownAudioService._internal();
  factory CountdownAudioService() => _instance;

  AudioPlayer? _player;
  FlutterTts? _tts;
  bool _initialized = false;

  CountdownAudioService._internal();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      _player = AudioPlayer();
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      AppLogger.warning('AudioPlayer init notice: $e', tag: 'CountdownAudio');
    }

    try {
      _tts = FlutterTts();
      await _tts?.setLanguage('en-US');
      await _tts?.setSpeechRate(0.5);
      await _tts?.setVolume(1.0);
      await _tts?.setPitch(1.0);
    } catch (e) {
      AppLogger.warning('FlutterTts init notice: $e', tag: 'CountdownAudio');
    }

    _initialized = true;
  }

  /// Plays short beep and vocalizes the countdown number (3, 2, 1).
  Future<void> playTick(int second) async {
    if (!AppPreferences().isCountdownVoiceEnabled) return;
    try {
      await _ensureInitialized();
      // Short beep
      _player?.stop().catchError((_) {});
      _player?.play(AssetSource('audio/countdown_tick.wav')).catchError((_) {});

      // Vocalize number
      const words = {3: 'Three', 2: 'Two', 1: 'One'};
      final word = words[second] ?? '$second';
      _tts?.stop().catchError((_) {});
      _tts?.speak(word).catchError((_) {});
    } catch (e) {
      AppLogger.warning('Tick audio notice: $e', tag: 'CountdownAudio');
    }
  }

  /// Plays ending chime and announces 'Go!'.
  Future<void> playGo() async {
    if (!AppPreferences().isCountdownVoiceEnabled) return;
    try {
      await _ensureInitialized();
      _player?.stop().catchError((_) {});
      _player?.play(AssetSource('audio/countdown_go.wav')).catchError((_) {});

      _tts?.stop().catchError((_) {});
      _tts?.speak('Go!').catchError((_) {});
    } catch (e) {
      AppLogger.warning('Go audio notice: $e', tag: 'CountdownAudio');
    }
  }

  /// Safely stops any playing audio and ongoing speech.
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
