import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:latlong2/latlong.dart';
import '../core/logging/app_logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tactical runner safety and emergency SOS service providing one-tap emergency
/// dialing, GPS coordinate distress SMS, location sharing, and loud audio sirens.
class SafetyService {
  static final SafetyService _instance = SafetyService._internal();
  factory SafetyService() => _instance;

  SafetyService._internal();

  static const String _prefContactName = 'sos_emergency_contact_name';
  static const String _prefContactPhone = 'sos_emergency_contact_phone';
  static const String _prefCustomMessage = 'sos_custom_message_template';

  String _contactName = '';
  String _contactPhone = '';
  String _customMessage = '';
  bool _isLoaded = false;

  AudioPlayer? _sirenPlayer;
  bool _isSirenPlaying = false;
  bool get isSirenPlaying => _isSirenPlaying;

  void resetForTesting() {
    _contactName = '';
    _contactPhone = '';
    _customMessage = '';
    _isLoaded = false;
    _isSirenPlaying = false;
  }

  String get contactName => _contactName;
  String get contactPhone => _contactPhone;
  String get customMessage => _customMessage;
  bool get hasContactConfigured => _contactPhone.trim().isNotEmpty;

  /// Loads emergency safety preferences from storage
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _contactName = prefs.getString(_prefContactName) ?? '';
      _contactPhone = prefs.getString(_prefContactPhone) ?? '';
      _customMessage = prefs.getString(_prefCustomMessage) ??
          'EMERGENCY: I am running and need assistance. My current GPS coordinates are:';
      _isLoaded = true;
    } catch (e) {
      AppLogger.error('Error loading safety settings: $e', tag: 'SafetyService', error: e);
    }
  }

  /// Updates emergency contact credentials
  Future<void> saveSettings({
    required String name,
    required String phone,
    String? message,
  }) async {
    _contactName = name.trim();
    _contactPhone = phone.trim();
    if (message != null) {
      _customMessage = message.trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefContactName, _contactName);
      await prefs.setString(_prefContactPhone, _contactPhone);
      await prefs.setString(_prefCustomMessage, _customMessage);
    } catch (e) {
      AppLogger.error('Error saving safety settings: $e', tag: 'SafetyService', error: e);
    }
  }

  /// Launches system phone dialer to call local emergency services
  Future<bool> callEmergencyServices({String dialNumber = '911'}) async {
    final uri = Uri.parse('tel:$dialNumber');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      AppLogger.error('Failed to dial emergency services: $e', tag: 'SafetyService', error: e);
    }
    return false;
  }

  /// Formats and opens SMS composer addressed to the saved emergency contact with GPS location link
  Future<bool> sendEmergencySms({required LatLng position}) async {
    if (!_isLoaded) await loadSettings();

    final locationUrl = 'https://maps.google.com/?q=${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    final body = '$_customMessage\n$locationUrl\n(Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)})';

    final query = Uri.encodeComponent(body);
    final phone = _contactPhone.isNotEmpty ? _contactPhone : '';
    final uri = Uri.parse('sms:$phone?body=$query');

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      AppLogger.error('Failed to launch SMS composer: $e', tag: 'SafetyService', error: e);
    }
    return false;
  }

  /// Shares current GPS coordinates and map link via standard system share sheet
  Future<void> shareLiveLocation({required LatLng position}) async {
    final locationUrl = 'https://maps.google.com/?q=${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    final text = '🚨 TACTICAL DISTRESS BEACON — Territory Runner\n'
        'My current GPS location:\n$locationUrl\n'
        'Latitude: ${position.latitude.toStringAsFixed(6)}\n'
        'Longitude: ${position.longitude.toStringAsFixed(6)}\n'
        'Time: ${DateTime.now().toUtc().toIso8601String()}';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
      ),
    );
  }

  /// Triggers a loud tactical audio siren beacon to deter threats or alert passersby
  Future<void> playTacticalSiren() async {
    if (_isSirenPlaying) return;
    _isSirenPlaying = true;
    try {
      _sirenPlayer ??= AudioPlayer();
      await _sirenPlayer!.setReleaseMode(ReleaseMode.loop);
      await _sirenPlayer!.setVolume(1.0);
      await _sirenPlayer!.play(AssetSource('audio/sos_siren.wav'));
    } catch (e) {
      AppLogger.error('Error playing tactical siren: $e', tag: 'SafetyService', error: e);
    }
  }

  /// Silences the audio siren beacon
  Future<void> stopTacticalSiren() async {
    _isSirenPlaying = false;
    try {
      if (_sirenPlayer != null) {
        await _sirenPlayer!.stop();
      }
    } catch (e) {
      AppLogger.error('Error stopping tactical siren: $e', tag: 'SafetyService', error: e);
    }
  }
}
