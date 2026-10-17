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

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const _PermissionPrimerSheet(),
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

class _PermissionPrimerSheet extends StatelessWidget {
  const _PermissionPrimerSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Header Icon & Title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TACTICAL RADAR ALERTS',
                      style: AppText.headingSmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EARLY WARNING DEFENSE SYSTEM',
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 9.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),

          Text(
            'Rival runner syndicates can attack your captured sectors in real-time. Enable radar alerts to receive instant notifications when your territory is under attack, carved, or contested.',
            style: AppText.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(height: AppSpacing.s16),

          // Features bullet list
          _buildFeatureRow(
            Icons.shield_rounded,
            'Real-Time Attack Radar',
            'Instant warnings when a rival runs through your sector',
          ),
          const SizedBox(height: AppSpacing.s10),
          _buildFeatureRow(
            Icons.gps_fixed_rounded,
            'Direct Tactical Deep-Link',
            'Tap notification to immediately center and defend on map',
          ),
          const SizedBox(height: AppSpacing.s10),
          _buildFeatureRow(
            Icons.military_tech_rounded,
            'Weekly League Cutoffs',
            'Alerts when promotion or relegation zones shift',
          ),

          const SizedBox(height: AppSpacing.s24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('MAYBE LATER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'ENABLE RADAR ALERTS',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.bodyBold.copyWith(fontSize: 12, color: Colors.white),
              ),
              Text(
                description,
                style: AppText.bodySmall.copyWith(fontSize: 10.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
