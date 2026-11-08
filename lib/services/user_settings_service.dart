import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_logger.dart';
import 'api_client.dart';

/// Available modes for sharing live runner location.
enum LiveVisibility {
  off,
  friends,
  nearby;

  static LiveVisibility fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'friends':
        return LiveVisibility.friends;
      case 'nearby':
        return LiveVisibility.nearby;
      case 'off':
      default:
        return LiveVisibility.off;
    }
  }

  String toApiValue() => name;

  String get displayName {
    switch (this) {
      case LiveVisibility.off:
        return 'Off';
      case LiveVisibility.friends:
        return 'Friends only';
      case LiveVisibility.nearby:
        return 'Nearby runners';
    }
  }

  String get description {
    switch (this) {
      case LiveVisibility.off:
        return 'Your live location is never shared with anyone. (Recommended for maximum privacy)';
      case LiveVisibility.friends:
        return 'Only accepted friends can see your live position during a run.';
      case LiveVisibility.nearby:
        return 'Nearby runners can see your position coarsened to ~25 m with a 5-second delay. Speed and heading are never shared.';
    }
  }
}

/// Offline-first service managing user privacy preferences and live presence visibility.
class UserSettingsService extends ChangeNotifier {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;

  static const String _prefLiveVisibilityKey = 'pref_live_visibility';
  static const String _prefLandRemindersKey = 'pref_land_reminders';

  final ApiClient _apiClient;
  LiveVisibility _liveVisibility = LiveVisibility.off; // PROPOSED DEFAULT: off
  bool _landReminders =
      true; // PROPOSED DEFAULT: true (enabled after permission)
  bool _isInitialized = false;

  LiveVisibility get liveVisibility => _liveVisibility;
  bool get landReminders => _landReminders;
  bool get isInitialized => _isInitialized;
  String get localTimezone => DateTime.now().timeZoneName;

  UserSettingsService._internal({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  @visibleForTesting
  UserSettingsService.custom({
    ApiClient? apiClient,
    LiveVisibility initial = LiveVisibility.off,
    bool initialLandReminders = true,
    this._isInitialized = true,
  }) : _apiClient = apiClient ?? ApiClient(),
       _liveVisibility = initial,
       _landReminders = initialLandReminders;

  @visibleForTesting
  void resetForTesting({
    LiveVisibility initial = LiveVisibility.off,
    bool initialLandReminders = true,
  }) {
    _liveVisibility = initial;
    _landReminders = initialLandReminders;
    _isInitialized = false;
  }

  /// Initializes settings from local offline storage and schedules background server sync
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefLiveVisibilityKey);
      _liveVisibility = LiveVisibility.fromString(stored);
      _landReminders = prefs.getBool(_prefLandRemindersKey) ?? true;
      _isInitialized = true;
      notifyListeners();

      // Background sync with server if online
      unawaited(syncWithServer());
    } catch (e) {
      AppLogger.warning(
        'Failed to load user settings: $e',
        tag: 'UserSettingsService',
      );
      _liveVisibility = LiveVisibility.off;
      _landReminders = true;
      _isInitialized = true;
    }
  }

  /// Updates land reminders preference offline-first and syncs to backend
  Future<void> setLandReminders(bool enabled) async {
    _landReminders = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLandRemindersKey, enabled);
    } catch (e) {
      AppLogger.warning(
        'Failed to persist land reminders locally: $e',
        tag: 'UserSettingsService',
      );
    }

    try {
      await _apiClient.updateSettings({
        'land_reminders': enabled,
        'timezone': localTimezone,
      });
      AppLogger.info(
        'Updated land_reminders on server to $enabled ($localTimezone)',
        tag: 'UserSettingsService',
      );
    } catch (e) {
      // Offline-first: failure is non-fatal
      AppLogger.warning(
        'Failed to sync land_reminders to server (offline-first preserved): $e',
        tag: 'UserSettingsService',
      );
    }
  }

  /// Updates live location visibility offline-first and syncs to backend
  Future<void> setLiveVisibility(LiveVisibility visibility) async {
    _liveVisibility = visibility;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLiveVisibilityKey, visibility.toApiValue());
    } catch (e) {
      AppLogger.warning(
        'Failed to persist visibility locally: $e',
        tag: 'UserSettingsService',
      );
    }

    try {
      await _apiClient.updateSettings({
        'live_visibility': visibility.toApiValue(),
      });
      AppLogger.info(
        'Updated live_visibility on server to ${visibility.toApiValue()}',
        tag: 'UserSettingsService',
      );
    } catch (e) {
      // Offline-first: failure is non-fatal
      AppLogger.warning(
        'Failed to sync live_visibility to server (offline-first preserved): $e',
        tag: 'UserSettingsService',
      );
    }
  }

  /// Synchronizes settings with Go backend, preserving local values on network errors
  Future<void> syncWithServer() async {
    try {
      // Push client timezone to server as non-sensitive operational setting
      await _apiClient.updateSettings({
        'timezone': localTimezone,
        'land_reminders': _landReminders,
      });

      final data = await _apiClient.getSettings();
      if (data != null) {
        if (data.containsKey('live_visibility')) {
          final serverVis = LiveVisibility.fromString(
            data['live_visibility'] as String?,
          );
          if (_liveVisibility != serverVis) {
            _liveVisibility = serverVis;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              _prefLiveVisibilityKey,
              serverVis.toApiValue(),
            );
          }
        }
        if (data.containsKey('land_reminders')) {
          final serverReminders = data['land_reminders'] as bool?;
          if (serverReminders != null && _landReminders != serverReminders) {
            _landReminders = serverReminders;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefLandRemindersKey, serverReminders);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.debug(
        'Server settings sync skipped (device offline): $e',
        tag: 'UserSettingsService',
      );
    }
  }
}
