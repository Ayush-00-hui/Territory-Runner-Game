import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/logging/app_logger.dart';
import '../models/ws_events.dart';
import 'api_client.dart';
import 'firebase_service.dart';
import 'privacy_zone_service.dart';
import 'user_settings_service.dart';

/// Real-Time WebSocket Service for live rival runner presence and territory alerts.
/// Features resilient exponential backoff with jitter, zero unhandled exceptions,
/// authentication-failure pausing, and offline/lifecycle-aware reconnection.
class WebSocketService with WidgetsBindingObserver {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  final FirebaseService _firebaseService;
  final ApiClient _apiClient;
  final PrivacyZoneService _privacyZoneService;
  final UserSettingsService _userSettingsService;
  WebSocketChannel Function(Uri uri, {Iterable<String>? protocols})?
  _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StreamSubscription? _authSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _stableConnectionTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  bool _isAuthBlocked = false;
  bool _isOffline = false;
  bool _isAppBackgrounded = false;
  int _reconnectAttempts = 0;

  DateTime? _lastPresenceSentTime;
  double? _lastSentLat;
  double? _lastSentLng;
  static const Distance _distanceCalc = Distance();

  /// Minimum interval between outbound presence packets to avoid flooding the WebSocket hub
  static const Duration minPresenceInterval = Duration(milliseconds: 2500);

  /// Minimum movement displacement (in meters) required to send an update if stationary
  static const double minMovementMeters = 3.0;

  List<String> _lastSubscribedCells = [];
  List<String> get lastSubscribedCells =>
      List.unmodifiable(_lastSubscribedCells);

  final _presenceController = StreamController<RunnerPresenceEvent>.broadcast();
  final _runnerLeftController = StreamController<String>.broadcast();
  final _alertController = StreamController<TerritoryAlertEvent>.broadcast();
  final _broadcastController =
      StreamController<ConquestBroadcastEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<RunnerPresenceEvent> get presenceStream => _presenceController.stream;
  Stream<String> get runnerLeftStream => _runnerLeftController.stream;
  Stream<TerritoryAlertEvent> get alertStream => _alertController.stream;
  Stream<ConquestBroadcastEvent> get broadcastStream =>
      _broadcastController.stream;
  Stream<bool> get isConnectedStream => _connectionStateController.stream;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isAuthBlocked => _isAuthBlocked;
  bool get isOffline => _isOffline;
  bool get isLiveAvailable => _isConnected;
  int get reconnectAttempts => _reconnectAttempts;

  WebSocketService._internal({
    FirebaseService? firebaseService,
    ApiClient? apiClient,
    PrivacyZoneService? privacyZoneService,
    UserSettingsService? userSettingsService,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _apiClient = apiClient ?? ApiClient(),
       _privacyZoneService = privacyZoneService ?? PrivacyZoneService(),
       _userSettingsService = userSettingsService ?? UserSettingsService() {
    _initObservers();
  }

  /// Visible for testing constructor
  @visibleForTesting
  WebSocketService.custom({
    FirebaseService? firebaseService,
    ApiClient? apiClient,
    PrivacyZoneService? privacyZoneService,
    UserSettingsService? userSettingsService,
    WebSocketChannel Function(Uri uri, {Iterable<String>? protocols})?
    channelFactory,
    bool registerLifecycleObserver = true,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _apiClient = apiClient ?? ApiClient(),
       _privacyZoneService = privacyZoneService ?? PrivacyZoneService(),
       _userSettingsService = userSettingsService ?? UserSettingsService() {
    _channelFactory = channelFactory;
    if (registerLifecycleObserver) {
      _initObservers();
    }
  }

  @visibleForTesting
  set channelFactory(
    WebSocketChannel Function(Uri uri, {Iterable<String>? protocols})? factory,
  ) {
    _channelFactory = factory;
  }

  void _initObservers() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In test environments WidgetsBinding may not be attached
    }

    try {
      _authSub = _firebaseService.auth?.idTokenChanges().listen((user) {
        if (user != null && _isAuthBlocked) {
          onTokenRefreshed();
        }
      });
    } catch (_) {
      // Mock / non-Firebase environment
    }
  }

  /// Computes the WebSocket URI and subprotocols according to authentication mode.
  /// When authenticated with Firebase, ID token is sent via Sec-WebSocket-Protocol (`bearer`, `<token>`)
  /// and `?user_id` is removed from the URI.
  /// In unauthenticated/dev mode, `?dev_user=<uid>` is used.
  Future<({Uri uri, Iterable<String>? protocols})> buildConnectionParams({
    bool forceRefresh = false,
  }) async {
    final httpBase = _apiClient.baseUrl.trim();
    final wsScheme = httpBase.startsWith('https') ? 'wss' : 'ws';
    final hostAndPort = httpBase
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');

    String? token;
    final user = _firebaseService.currentUser;
    if (user != null) {
      try {
        token = await user.getIdToken(forceRefresh);
      } catch (e) {
        AppLogger.warning(
          'Error fetching Firebase ID token for WebSocket: $e',
          tag: 'WebSocketService',
        );
      }
    }

    if (token != null && token.isNotEmpty) {
      // Production path: Sec-WebSocket-Protocol header ('bearer', <token>), no query params
      final uri = Uri.parse('$wsScheme://$hostAndPort/v1/ws');
      final protocols = ['bearer', token];
      return (uri: uri, protocols: protocols);
    } else {
      // Dev mode path: ?dev_user=<uid>
      final uid = _firebaseService.currentUserId;
      final uri = Uri.parse('$wsScheme://$hostAndPort/v1/ws?dev_user=$uid');
      return (uri: uri, protocols: null);
    }
  }

  /// Establishes the real-time WebSocket connection to the Go backend.
  /// Completely catches all async errors from connect, ready, stream, and sink.
  Future<void> connect() async {
    if (_isConnected || _isConnecting || _isDisposed) return;
    if (_isAuthBlocked) {
      AppLogger.debug(
        'WebSocket connect skipped: authentication blocked until token refresh.',
        tag: 'WebSocketService',
      );
      return;
    }
    if (_isOffline) {
      AppLogger.debug(
        'WebSocket connect skipped: device is offline.',
        tag: 'WebSocketService',
      );
      return;
    }
    if (_isAppBackgrounded) {
      AppLogger.debug(
        'WebSocket connect skipped: app is in background.',
        tag: 'WebSocketService',
      );
      return;
    }

    _isConnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final forceRefresh = _reconnectAttempts > 0 && !_isAuthBlocked;
    final params = await buildConnectionParams(forceRefresh: forceRefresh);
    if (_isDisposed || !_isConnecting) {
      return;
    }

    try {
      final channel = _channelFactory != null
          ? _channelFactory!(params.uri, protocols: params.protocols)
          : WebSocketChannel.connect(params.uri, protocols: params.protocols);
      _channel = channel;

      _subscription = channel.stream.listen(
        _onMessageReceived,
        onError: (err) {
          _handleDisconnect(error: err);
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // CRITICAL: Await channel.ready inside try/catch to ensure handshake succeeds
      // and prevent channel.ready errors from escaping as unhandled Zone exceptions.
      await channel.ready;

      if (_isDisposed || !_isConnecting) {
        disconnect();
        return;
      }

      _onConnected(params.uri);
    } catch (e) {
      if (!_isDisposed) {
        _handleDisconnect(error: e);
      }
    } finally {
      _isConnecting = false;
    }
  }

  void _onConnected(Uri uri) {
    if (_isDisposed) {
      disconnect();
      return;
    }

    _isConnected = true;
    _connectionStateController.add(true);
    AppLogger.info('WebSocket connected: $uri', tag: 'WebSocketService');

    _startHeartbeat();

    // Start 30s timer for connection stabilization before resetting backoff
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = Timer(const Duration(seconds: 30), () {
      if (_isConnected) {
        _reconnectAttempts = 0;
        AppLogger.debug(
          'WebSocket connection stable for 30s. Backoff reset.',
          tag: 'WebSocketService',
        );
      }
    });

    if (_lastSubscribedCells.isNotEmpty) {
      sendViewportSubscription(_lastSubscribedCells, force: true);
    }
  }

  /// Sends a lightweight subscription message declaring the runner's visible viewport spatial cells.
  void sendViewportSubscription(List<String> cells, {bool force = false}) {
    if (!force && listEquals(_lastSubscribedCells, cells)) return;
    _lastSubscribedCells = List.from(cells);
    if (!_isConnected || _channel == null || cells.isEmpty) return;

    try {
      final packet = {'type': 'viewport_subscribe', 'cells': cells};
      _channel?.sink.add(jsonEncode(packet));
    } catch (e) {
      AppLogger.warning(
        'Failed to send viewport subscription: $e',
        tag: 'WebSocketService',
      );
    }
  }

  void _onMessageReceived(dynamic rawData) {
    try {
      final json = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';

      switch (type) {
        case 'runner_presence':
          final event = RunnerPresenceEvent.fromJson(json);
          if (event.userId != _firebaseService.currentUserId) {
            _presenceController.add(event);
          }
          break;

        case 'runner_left':
          final uid = json['user_id'] as String? ?? '';
          if (uid.isNotEmpty) {
            _runnerLeftController.add(uid);
          }
          break;

        case 'territory_alert':
        case 'territory_under_attack':
          final alert = TerritoryAlertEvent.fromJson(json);
          _alertController.add(alert);
          break;

        case 'conquest_broadcast':
          final bcast = ConquestBroadcastEvent.fromJson(json);
          _broadcastController.add(bcast);
          break;
      }
    } catch (e, st) {
      AppLogger.error(
        'Error parsing inbound WebSocket packet',
        error: e,
        stackTrace: st,
        tag: 'WebSocketService',
      );
    }
  }

  /// Sends periodic position updates to nearby peers or friends.
  bool sendPresenceUpdate({
    required double latitude,
    required double longitude,
    double speed = 0.0,
    double heading = 0.0,
    bool force = false,
  }) {
    if (!_isConnected || _channel == null) return false;

    if (_userSettingsService.liveVisibility == LiveVisibility.off) {
      return false;
    }

    final targetPoint = LatLng(latitude, longitude);

    if (_privacyZoneService.isPointInPrivacyZone(targetPoint)) {
      AppLogger.debug(
        'Presence update suppressed: coordinate is within an active privacy exclusion zone',
        tag: 'WebSocketService',
      );
      return false;
    }

    final now = DateTime.now();

    if (!force && _lastPresenceSentTime != null) {
      final elapsed = now.difference(_lastPresenceSentTime!);
      if (elapsed < minPresenceInterval) {
        return false;
      }
    }

    if (!force && _lastSentLat != null && _lastSentLng != null) {
      final distanceMoved = _distanceCalc.as(
        LengthUnit.Meter,
        LatLng(_lastSentLat!, _lastSentLng!),
        targetPoint,
      );
      if (distanceMoved < minMovementMeters && speed < 0.5) {
        return false;
      }
    }

    final packet = {
      'type': 'presence_update',
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
    };

    try {
      _channel?.sink.add(jsonEncode(packet));
      _lastPresenceSentTime = now;
      _lastSentLat = latitude;
      _lastSentLng = longitude;
      return true;
    } catch (e) {
      AppLogger.warning(
        'Failed to send presence update: $e',
        tag: 'WebSocketService',
      );
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'heartbeat'}));
        } catch (_) {
          _handleDisconnect();
        }
      }
    });
  }

  void _handleDisconnect({Object? error}) {
    if (_isDisposed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _stableConnectionTimer?.cancel();
      _stableConnectionTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _subscription?.cancel();
      _subscription = null;
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;
      return;
    }

    _isConnected = false;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(false);
    }

    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    final formattedError = _cleanErrorString(error);

    // 1. Check for Authentication Failure (401/403)
    if (_isAuthError(error)) {
      _isAuthBlocked = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      AppLogger.warning(
        'WebSocket authentication failed (401/403). Retries paused until token refresh.',
        tag: 'WebSocketService',
      );
      return;
    }

    // 2. Check for Offline condition
    if (_isOfflineError(error) || _isOffline) {
      _isOffline = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      AppLogger.info(
        'WebSocket offline ($formattedError). Retries paused until connectivity returns.',
        tag: 'WebSocketService',
      );
      return;
    }

    // 3. Check for App Background condition
    if (_isAppBackgrounded) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      AppLogger.info(
        'WebSocket paused while app in background.',
        tag: 'WebSocketService',
      );
      return;
    }

    // 4. Exponential backoff with jitter (2s doubling to 60s cap)
    _reconnectAttempts++;
    final delay = computeBackoffDelay(_reconnectAttempts);

    AppLogger.info(
      'WebSocket disconnected ($formattedError). Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...',
      tag: 'WebSocketService',
    );

    _reconnectTimer?.cancel();
    if (!_isDisposed) {
      _reconnectTimer = Timer(delay, connect);
    }
  }

  /// Calculates exponential backoff duration with random jitter.
  /// 2s doubling up to a 60s cap, plus 0-1000ms jitter.
  static Duration computeBackoffDelay(int attempts, {math.Random? random}) {
    if (attempts <= 0) return Duration.zero;
    final expSec = 2 * math.pow(2, math.max(0, attempts - 1)).toInt();
    final clampedSec = math.min(60, expSec);
    final jitterMs = (random ?? math.Random()).nextInt(1000);
    return Duration(seconds: clampedSec, milliseconds: jitterMs);
  }

  /// Formats raw error for concise logging, cleaning internal Dart SDK fragment artifact.
  static String _cleanErrorString(Object? error) {
    if (error == null) return 'connection closed';
    var str = error.toString();
    // Clean up internal Dart SDK empty fragment artifact (e.g. "...runner#' was not upgraded")
    str = str.replaceAll('#\' was not upgraded', '\' was not upgraded');
    return str;
  }

  static bool _isAuthError(Object? error) {
    if (error == null) return false;
    final s = error.toString().toLowerCase();
    return s.contains('401') ||
        s.contains('403') ||
        s.contains('unauthorized') ||
        s.contains('forbidden') ||
        s.contains('was not upgraded to websocket');
  }

  static bool _isOfflineError(Object? error) {
    if (error == null) return false;
    final s = error.toString().toLowerCase();
    return s.contains('network is unreachable') ||
        s.contains('no address associated with hostname') ||
        s.contains('failed host lookup') ||
        s.contains('network unreachable');
  }

  /// Called when device connectivity changes
  void onConnectivityChanged(bool isOnline) {
    if (_isOffline == !isOnline) return;
    _isOffline = !isOnline;
    AppLogger.info(
      'WebSocket network state: ${isOnline ? "online" : "offline"}',
      tag: 'WebSocketService',
    );
    if (isOnline &&
        !_isConnected &&
        !_isDisposed &&
        !_isAuthBlocked &&
        !_isAppBackgrounded) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      connect();
    }
  }

  /// Called when Firebase ID token is refreshed
  void onTokenRefreshed() {
    AppLogger.info(
      'WebSocket auth token refreshed. Resuming retries.',
      tag: 'WebSocketService',
    );
    _isAuthBlocked = false;
    _reconnectAttempts = 0;
    if (!_isConnected && !_isDisposed && !_isOffline && !_isAppBackgrounded) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      connect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onAppLifecycleStateChanged(state);
  }

  @visibleForTesting
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    final isBackground =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    _isAppBackgrounded = isBackground;
    if (state == AppLifecycleState.resumed) {
      AppLogger.info(
        'WebSocket app resumed to foreground.',
        tag: 'WebSocketService',
      );
      if (!_isConnected && !_isDisposed && !_isAuthBlocked && !_isOffline) {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        connect();
      }
    }
  }

  @visibleForTesting
  void setMockChannel(WebSocketChannel channel) {
    _channel = channel;
    _isConnected = true;
    _connectionStateController.add(true);
  }

  @visibleForTesting
  void setMockConnected(bool connected) {
    _isConnected = connected;
    _connectionStateController.add(connected);
  }

  @visibleForTesting
  bool get isAppBackgrounded => _isAppBackgrounded;

  @visibleForTesting
  Timer? get reconnectTimer => _reconnectTimer;

  @visibleForTesting
  Timer? get stableConnectionTimer => _stableConnectionTimer;

  @visibleForTesting
  Timer? get heartbeatTimer => _heartbeatTimer;

  @visibleForTesting
  bool get isDisposed => _isDisposed;

  /// Gracefully closes connection
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(false);
    }
  }

  void dispose() {
    _isDisposed = true;
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _authSub?.cancel();
    disconnect();
    _presenceController.close();
    _runnerLeftController.close();
    _alertController.close();
    _broadcastController.close();
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
  }
}
