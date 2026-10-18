import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/ui.dart';
import 'api_client.dart';
import 'app_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background push alert received (FCM HTTP v1 payload)
  AppLogger.info('Background message received: ${message.messageId} - ${message.data}', tag: 'NotificationService');
}

/// Service managing FCM HTTP v1 push notifications, permission primer UI,
/// device token registration with backend, and attack navigation deep-linking.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  ApiClient? _apiClient;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final StreamController<String> _attackedTerritoryController = StreamController<String>.broadcast();

  /// Stream of territory IDs to navigate and focus on when push alerts are tapped
  Stream<String> get onAttackedTerritoryTapped => _attackedTerritoryController.stream;

  /// Check if Firebase Core is initialized and available
  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Initialize Firebase Cloud Messaging lifecycle listeners and token synchronization
  Future<void> initialize({ApiClient? apiClient}) async {
    _apiClient = apiClient ?? ApiClient();

    if (!isFirebaseAvailable) {
      AppLogger.info('Firebase not initialized; push notification service running in local fallback mode.', tag: 'NotificationService');
      _isInitialized = true;
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.info('Foreground message received: ${message.data}', tag: 'NotificationService');
        final type = message.data['type'];
        if (type == 'territory_carved') {
          final rival = message.data['rival_name'] as String? ?? 'Rival';
          AppPreferences().triggerAttackHaptic();
          AppToast.showGlobal(
            '⚠️ Territory under attack by $rival!',
            icon: Icons.warning_amber_rounded,
            type: AppToastType.error,
          );
        }
      });

      // Handle notification tap when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessagePayload(message.data);
      });

      // Handle notification tap when app launched from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessagePayload(initialMessage.data);
      }

      // Handle device token rotation
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        AppLogger.info('FCM device token refreshed.', tag: 'NotificationService');
        _registerToken(newToken);
      });

      // Check existing permissions and sync token if already authorized
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          unawaited(_registerToken(token));
        }
      }

      _isInitialized = true;
      AppLogger.info('FCM notification service successfully initialized.', tag: 'NotificationService');
    } catch (e) {
      AppLogger.warning('Failed to initialize FirebaseMessaging: $e', tag: 'NotificationService', error: e);
      _isInitialized = true; // Fallback mode active
    }
  }

  void _handleMessagePayload(Map<String, dynamic> data) {
    final territoryId = data['territory_id'] as String?;
    if (territoryId != null && territoryId.isNotEmpty) {
      AppLogger.info('Navigating to attacked territory: $territoryId', tag: 'NotificationService');
      _attackedTerritoryController.add(territoryId);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final client = _apiClient ?? ApiClient();
      await client.registerDeviceToken(token);
      AppLogger.debug('Successfully registered FCM device token with backend.', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('Error registering device token with backend: $e', tag: 'NotificationService', error: e);
    }
  }

  /// Dispatches an attacked territory event (for testing or direct simulated alerts)
  void simulateAttackedTerritoryTap(String territoryId) {
    _attackedTerritoryController.add(territoryId);
  }

  /// Displays the tactical radar alerts permission primer bottom sheet if not already prompted
  Future<bool> showPermissionPrimerIfNeeded(BuildContext context, {bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool('fcm_permission_prompted') ?? false;

    if (alreadyPrompted && !force) {
      return false;
    }

    if (!context.mounted) return false;

    final accepted = await AppSheet.show<bool?>(
      context: context,
      builder: (ctx) => const PermissionPrimerSheet.notifications(),
    );

    await prefs.setBool('fcm_permission_prompted', true);

    if (accepted == true) {
      return await requestNotificationPermission();
    }
    return false;
  }

  /// Requests system notification permissions and registers the FCM device token
  Future<bool> requestNotificationPermission() async {
    if (!isFirebaseAvailable) {
      AppLogger.info('Firebase not configured; simulated permission granted.', tag: 'NotificationService');
      return true;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isAuthorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _registerToken(token);
        }
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error requesting notification permissions: $e', tag: 'NotificationService', error: e);
      return false;
    }
  }

  /// Unregisters the current device token on user sign-out
  Future<void> unregisterDeviceToken() async {
    if (!isFirebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      AppLogger.info('FCM device token deleted from device.', tag: 'NotificationService');
    } catch (e) {
      AppLogger.error('Error deleting FCM token: $e', tag: 'NotificationService', error: e);
    }
  }
}
