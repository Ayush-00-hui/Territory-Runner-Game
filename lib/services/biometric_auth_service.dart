import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_logger.dart';

/// Service managing biometric athlete authentication (Fingerprint / Face ID).
class BiometricAuthService {
  static final BiometricAuthService _instance =
      BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;

  BiometricAuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefBiometricsEnabled = 'athlete_biometrics_enabled';

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  /// Loads stored biometric preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefBiometricsEnabled) ?? false;
    } catch (e) {
      AppLogger.warning(
        'Failed to load biometric preferences: $e',
        tag: 'BiometricAuthService',
      );
    }
  }

  /// Checks if device hardware supports biometrics
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Error checking biometric hardware availability: $e',
        tag: 'BiometricAuthService',
      );
      return false;
    }
  }

  /// Available biometric types (e.g. fingerprint, face)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Error getting biometric types: $e',
        tag: 'BiometricAuthService',
      );
      return [];
    }
  }

  /// Prompts biometric prompt for rapid athlete quick-unlock
  Future<bool> authenticate({
    String reason =
        'Authenticate to access Territory Runner athlete profile and live runs',
  }) async {
    try {
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Biometric authentication attempt failed: $e',
        tag: 'BiometricAuthService',
      );
      return false;
    }
  }

  /// Toggles athlete biometric preference
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBiometricsEnabled, enabled);
    } catch (e) {
      AppLogger.warning(
        'Failed to persist biometric preference: $e',
        tag: 'BiometricAuthService',
      );
    }
  }
}
