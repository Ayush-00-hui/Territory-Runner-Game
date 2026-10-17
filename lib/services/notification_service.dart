import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/coach/voice_coach_service.dart';
import '../ui/ui.dart';
import 'api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background push alert received (FCM HTTP v1 payload)
  debugPrint('[NotificationService] Background message received: ${message.messageId} - ${message.data}');
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
      debugPrint('[NotificationService] Firebase not initialized; push notification service running in local fallback mode.');
      _isInitialized = true;
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground message received: ${message.data}');
        final type = message.data['type'];
        if (type == 'territory_carved') {
          final rival = message.data['rival_name'] as String? ?? 'Rival';
          VoiceCoachService().announceTerritoryUnderAttack(rival);
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
        debugPrint('[NotificationService] FCM device token refreshed.');
        _registerToken(newToken);
      });

      // Check existing permissions and sync token if already authorized
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _registerToken(token);
        }
      }

      _isInitialized = true;
      debugPrint('[NotificationService] FCM notification service successfully initialized.');
    } catch (e) {
      debugPrint('[NotificationService] Failed to initialize FirebaseMessaging: $e');
      _isInitialized = true; // Fallback mode active
    }
  }

  void _handleMessagePayload(Map<String, dynamic> data) {
    final territoryId = data['territory_id'] as String?;
    if (territoryId != null && territoryId.isNotEmpty) {
      debugPrint('[NotificationService] Navigating to attacked territory: $territoryId');
      _attackedTerritoryController.add(territoryId);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final client = _apiClient ?? ApiClient();
      await client.registerDeviceToken(token);
      debugPrint('[NotificationService] Successfully registered FCM device token with backend.');
    } catch (e) {
      debugPrint('[NotificationService] Error registering device token with backend: $e');
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
      debugPrint('[NotificationService] Firebase not configured; simulated permission granted.');
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
      debugPrint('[NotificationService] Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Unregisters the current device token on user sign-out
  Future<void> unregisterDeviceToken() async {
    if (!isFirebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[NotificationService] FCM device token deleted from device.');
    } catch (e) {
      debugPrint('[NotificationService] Error deleting FCM token: $e');
    }
  }
}
