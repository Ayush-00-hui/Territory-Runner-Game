import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/run_log_entry.dart';
import '../models/training_plan.dart';
import '../ui/ui.dart';
import 'api_client.dart';
import 'app_preferences.dart';
import 'daily_checkin_service.dart';
import 'daily_quest_service.dart';
import 'run_log_service.dart';
import 'training_plan_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background push alert received (FCM HTTP v1 payload)
  AppLogger.info(
    'Background message received: ${message.messageId} - ${message.data}',
    tag: 'NotificationService',
  );
}

/// Service managing FCM HTTP v1 push notifications, permission primer UI,
/// device token registration with backend, and attack navigation deep-linking.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  static const String dailyChannelId = 'daily_goal_health_v1';
  static const String dailyChannelName = 'Daily Goal & Health Check';
  static const String dailyChannelDescription =
      '2-3 daily check-ins featuring today\'s goal progress, health tips, and wellness checks.';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DailyCheckInService _dailyCheckInService = DailyCheckInService();

  ApiClient? _apiClient;
  bool _isInitialized = false;
  bool _localInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get _isTestEnv {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  final StreamController<String> _attackedTerritoryController =
      StreamController<String>.broadcast();
  String? _pendingTerritoryId;

  /// Stream of territory IDs to navigate and focus on when push alerts are tapped
  Stream<String> get onAttackedTerritoryTapped =>
      _attackedTerritoryController.stream;

  /// Returns and clears any territory focus ID queued before MapScreen mounted.
  String? consumePendingTerritoryId() {
    final pending = _pendingTerritoryId;
    _pendingTerritoryId = null;
    return pending;
  }

  /// Check if Firebase Core is initialized and available
  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Initialize local daily notifications and Firebase Cloud Messaging listeners.
  Future<void> initialize({ApiClient? apiClient}) async {
    _apiClient = apiClient ?? ApiClient();
    await _initLocalNotifications();

    if (!isFirebaseAvailable) {
      AppLogger.info(
        'Firebase not initialized; push notification service running in local mode.',
        tag: 'NotificationService',
      );
      _isInitialized = true;
      await _ensureDevicePermissionOnce();
      unawaited(syncDailyReminders());
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.info(
          'Foreground message received: ${message.data}',
          tag: 'NotificationService',
        );
        final type = message.data['type'];
        if (type == 'territory_carved') {
          final rival = message.data['rival_name'] as String? ?? 'Rival';
          AppPreferences().triggerAttackHaptic();
          AppToast.showGlobal(
            '⚠️ Territory under attack by $rival!',
            icon: Icons.warning_amber_rounded,
            type: AppToastType.error,
          );
        } else if (type == 'decay_warning') {
          AppPreferences().triggerAttackHaptic();
          AppToast.showGlobal(
            'One of your areas is getting weak. A short loop will restore it.',
            icon: Icons.shield_outlined,
            type: AppToastType.warning,
          );
        }
      });

      // Handle notification tap when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessagePayload(message.data);
      });

      // Handle notification tap when app launched from terminated state
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessagePayload(initialMessage.data);
      }

      // Handle device token rotation
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        AppLogger.info(
          'FCM device token refreshed.',
          tag: 'NotificationService',
        );
        _registerToken(newToken);
      });

      // Check existing permissions and sync token if already authorized
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          unawaited(_registerToken(token));
        }
      }

      _isInitialized = true;
      await _ensureDevicePermissionOnce();
      unawaited(syncDailyReminders());
      AppLogger.info(
        'FCM notification service successfully initialized.',
        tag: 'NotificationService',
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to initialize FirebaseMessaging: $e',
        tag: 'NotificationService',
        error: e,
      );
      _isInitialized = true; // Fallback mode active
      await _ensureDevicePermissionOnce();
      unawaited(syncDailyReminders());
    }
  }

  Future<void> _ensureDevicePermissionOnce() async {
    if (_isTestEnv || kIsWeb) return;
    if (AppPreferences().dailyReminderWindow == 'off') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('local_daily_notif_prompted') ?? false) return;
      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await androidImpl?.areNotificationsEnabled() ?? true;
      if (!enabled) {
        await androidImpl?.requestNotificationsPermission();
      }
      await prefs.setBool('local_daily_notif_prompted', true);
    } catch (_) {}
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized || _isTestEnv || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      );
      await _localNotifications.initialize(settings: initSettings);
      _localInitialized = true;
    } catch (e) {
      AppLogger.warning(
        'Local notification plugin init skipped: $e',
        tag: 'NotificationService',
      );
    }
  }

  NotificationDetails _dailyDetails(String title, String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        dailyChannelId,
        dailyChannelName,
        channelDescription: dailyChannelDescription,
        icon: 'ic_notification',
        color: AppColors.accent,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Territory Runner',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
      ),
    );
  }

  /// Refreshes the scheduled 2-3 daily notifications containing today's goal,
  /// progress, and a health quote or wellness check-in.
  Future<List<PlannedDailyNotification>> syncDailyReminders({
    DateTime? now,
    String? overrideWindow,
  }) async {
    final planned = await _dailyCheckInService.buildScheduleFromAppState(
      now: now,
      overrideWindow: overrideWindow,
    );

    if (_isTestEnv || kIsWeb) {
      return planned;
    }

    await _initLocalNotifications();
    if (!_localInitialized) return planned;

    try {
      for (int i = 1; i <= DailyCheckInService.maxSlotSpan; i++) {
        await _localNotifications.cancel(
          id: DailyCheckInService.baseNotificationId + i,
        );
      }

      for (final item in planned) {
        final tzWhen = tz.TZDateTime.from(
          item.scheduledLocalTime.toUtc(),
          tz.UTC,
        );
        await _localNotifications.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: tzWhen,
          notificationDetails: _dailyDetails(item.title, item.body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: item.payload,
        );
      }
      AppLogger.info(
        'Scheduled ${planned.length} daily goal & health check notifications',
        tag: 'NotificationService',
      );
    } catch (e) {
      AppLogger.warning(
        'Failed scheduling daily reminders: $e',
        tag: 'NotificationService',
      );
    }
    return planned;
  }

  /// Sends a real local check-in notification immediately using today's active goal
  /// and health check/quote so the athlete can preview it right away.
  Future<PlannedDailyNotification?> sendSampleDailyCheckIn({
    DailyCheckInSlot slot = DailyCheckInSlot.middayHealthCheck,
  }) async {
    final now = DateTime.now();
    final List<RunLogEntry> runs = RunLogService().isBoxOpen
        ? RunLogService().getAllRuns()
        : const <RunLogEntry>[];
    final quests = await DailyQuestService().getTodayQuests(
      now: now,
      overrideRuns: runs,
    );
    PlanWorkoutDay? nextWorkout;
    if (Hive.isBoxOpen(TrainingPlanService.boxName)) {
      try {
        nextWorkout = await TrainingPlanService().getNextWorkout();
      } catch (_) {}
    }

    final todayStart = DateTime(now.year, now.month, now.day);
    final double todayDistanceKm = runs
        .where((r) => !r.simulated && !r.startedAt.isBefore(todayStart))
        .fold(0.0, (sum, r) => sum + (r.distanceM / 1000.0));

    final msg = DailyCheckInService.composeMessage(
      date: now,
      slot: slot,
      quests: quests,
      todayDistanceKm: todayDistanceKm,
      customDailyGoalKm: AppPreferences().dailyGoalKm,
      nextPlanWorkout: nextWorkout,
    );

    final preview = PlannedDailyNotification(
      id: DailyCheckInService.previewNotificationId,
      slot: slot,
      scheduledLocalTime: now,
      title: msg.title,
      body: msg.body,
      payload: 'daily_checkin:${slot.name}',
    );

    if (_isTestEnv || kIsWeb) return preview;

    await _initLocalNotifications();
    await requestNotificationPermission();
    if (!_localInitialized) return preview;

    try {
      await _localNotifications.show(
        id: preview.id,
        title: preview.title,
        body: preview.body,
        notificationDetails: _dailyDetails(preview.title, preview.body),
        payload: preview.payload,
      );
    } catch (e) {
      AppLogger.warning(
        'Failed showing sample daily check-in: $e',
        tag: 'NotificationService',
      );
    }
    return preview;
  }

  void _handleMessagePayload(Map<String, dynamic> data) {
    final territoryId = data['territory_id'] as String?;
    if (territoryId != null && territoryId.isNotEmpty) {
      AppLogger.info(
        'Navigating to attacked territory: $territoryId',
        tag: 'NotificationService',
      );
      _pendingTerritoryId = territoryId;
      _attackedTerritoryController.add(territoryId);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final client = _apiClient ?? ApiClient();
      await client.registerDeviceToken(token);
      AppLogger.debug(
        'Successfully registered FCM device token with backend.',
        tag: 'NotificationService',
      );
    } catch (e) {
      AppLogger.error(
        'Error registering device token with backend: $e',
        tag: 'NotificationService',
        error: e,
      );
    }
  }

  /// Dispatches an attacked territory event (for testing or direct simulated alerts)
  void simulateAttackedTerritoryTap(String territoryId) {
    _pendingTerritoryId = territoryId;
    _attackedTerritoryController.add(territoryId);
  }

  /// Displays the radar alerts permission primer bottom sheet if not already prompted
  Future<bool> showPermissionPrimerIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
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

  /// Requests system notification permissions (Android 13+ local & FCM)
  /// and registers the FCM device token when Firebase is available.
  Future<bool> requestNotificationPermission() async {
    bool localGranted = false;
    if (!_isTestEnv && !kIsWeb) {
      try {
        await _initLocalNotifications();
        final androidImpl = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidImpl != null) {
          localGranted =
              await androidImpl.requestNotificationsPermission() ?? false;
        }
        final iosImpl = _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosImpl != null) {
          localGranted =
              await iosImpl.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              localGranted;
        }
      } catch (e) {
        AppLogger.warning(
          'Local notification permission request notice: $e',
          tag: 'NotificationService',
        );
      }
    }

    if (!isFirebaseAvailable) {
      AppLogger.info(
        'Firebase not configured; local notification permission granted=$localGranted.',
        tag: 'NotificationService',
      );
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

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isAuthorized || localGranted) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _registerToken(token);
        }
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error(
        'Error requesting notification permissions: $e',
        tag: 'NotificationService',
        error: e,
      );
      return localGranted;
    }
  }

  /// Unregisters the current device token on user sign-out
  Future<void> unregisterDeviceToken() async {
    if (!isFirebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      AppLogger.info(
        'FCM device token deleted from device.',
        tag: 'NotificationService',
      );
    } catch (e) {
      AppLogger.error(
        'Error deleting FCM token: $e',
        tag: 'NotificationService',
        error: e,
      );
    }
  }
}
