import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/logging/app_logger.dart';
import '../models/ws_events.dart';
import 'api_client.dart';
import 'firebase_service.dart';
import 'privacy_zone_service.dart';
import 'user_settings_service.dart';

/// Real-Time WebSocket Service for live rival runner presence and territory alerts
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  final FirebaseService _firebaseService;
  final ApiClient _apiClient;
  final PrivacyZoneService _privacyZoneService;
  final UserSettingsService _userSettingsService;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  bool _isConnected = false;
  bool _isDisposed = false;
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
  int get reconnectAttempts => _reconnectAttempts;

  WebSocketService._internal({
    FirebaseService? firebaseService,
    ApiClient? apiClient,
    PrivacyZoneService? privacyZoneService,
    UserSettingsService? userSettingsService,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _apiClient = apiClient ?? ApiClient(),
       _privacyZoneService = privacyZoneService ?? PrivacyZoneService(),
       _userSettingsService = userSettingsService ?? UserSettingsService();

  /// Visible for testing constructor
  @visibleForTesting
  WebSocketService.custom({
    FirebaseService? firebaseService,
    ApiClient? apiClient,
    PrivacyZoneService? privacyZoneService,
    UserSettingsService? userSettingsService,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _apiClient = apiClient ?? ApiClient(),
       _privacyZoneService = privacyZoneService ?? PrivacyZoneService(),
       _userSettingsService = userSettingsService ?? UserSettingsService();

  /// Computes the WebSocket URI and subprotocols according to authentication mode.
  /// When authenticated with Firebase, ID token is sent via Sec-WebSocket-Protocol (`bearer`, `<token>`)
  /// and `?user_id` is removed from the URI.
  /// In unauthenticated/dev mode, `?dev_user=<uid>` is used.
  Future<({Uri uri, Iterable<String>? protocols})> buildConnectionParams({
    bool forceRefresh = false,
  }) async {
    final httpBase = _apiClient.baseUrl;
    final wsScheme = httpBase.startsWith('https') ? 'wss' : 'ws';
    final hostAndPort = httpBase.replaceFirst(RegExp(r'^https?://'), '');

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

  /// Establishes the real-time WebSocket connection to the Go backend
  Future<void> connect() async {
    if (_isConnected || _isDisposed) return;

    _reconnectTimer?.cancel();
    final forceRefresh = _reconnectAttempts > 0;
    final params = await buildConnectionParams(forceRefresh: forceRefresh);

    try {
      _channel = WebSocketChannel.connect(
        params.uri,
        protocols: params.protocols,
      );
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      AppLogger.info(
        'Connected to real-time hub: ${params.uri}',
        tag: 'WebSocketService',
      );

      _startHeartbeat();

      if (_lastSubscribedCells.isNotEmpty) {
        sendViewportSubscription(_lastSubscribedCells);
      }

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (err) {
          AppLogger.warning('WebSocket error: $err', tag: 'WebSocketService');
          _handleDisconnect();
        },
        onDone: () {
          AppLogger.info(
            'WebSocket connection closed by server',
            tag: 'WebSocketService',
          );
          _handleDisconnect();
        },
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to initiate WebSocket connection: $e',
        tag: 'WebSocketService',
      );
      _handleDisconnect();
    }
  }

  /// Sends a lightweight subscription message declaring the runner's visible viewport spatial cells.
  void sendViewportSubscription(List<String> cells) {
    if (listEquals(_lastSubscribedCells, cells)) return;
    _lastSubscribedCells = List.from(cells);
    if (!_isConnected || _channel == null || cells.isEmpty) return;

    try {
      final packet = {'type': 'viewport_subscribe', 'cells': cells};
      _channel!.sink.add(jsonEncode(packet));
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
          // Don't echo self presence
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
  /// Suppresses updates if live_visibility is 'off', coordinate falls inside a privacy zone,
  /// or when throttled by minPresenceInterval or stationary jitter.
  /// Returns true if dispatched to the WebSocket sink, or false if suppressed or throttled.
  bool sendPresenceUpdate({
    required double latitude,
    required double longitude,
    double speed = 0.0,
    double heading = 0.0,
    bool force = false,
  }) {
    if (!_isConnected || _channel == null) return false;

    // 0. Client-side Live Visibility Consent Check (Defense-in-depth)
    if (_userSettingsService.liveVisibility == LiveVisibility.off) {
      return false;
    }

    final targetPoint = LatLng(latitude, longitude);

    // 1. Client-Side Privacy Zone Suppression (Defense-in-depth)
    if (_privacyZoneService.isPointInPrivacyZone(targetPoint)) {
      AppLogger.debug(
        'Presence update suppressed: coordinate is within an active privacy exclusion zone',
        tag: 'WebSocketService',
      );
      return false;
    }

    final now = DateTime.now();

    // 2. Frequency Throttling (unless forced)
    if (!force && _lastPresenceSentTime != null) {
      final elapsed = now.difference(_lastPresenceSentTime!);
      if (elapsed < minPresenceInterval) {
        return false;
      }
    }

    // 3. Stationary Jitter Deduplication
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
      _channel!.sink.add(jsonEncode(packet));
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

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStateController.add(false);
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_isDisposed) return;

    // Exponential backoff with jitter (max 15s)
    _reconnectAttempts++;
    final delay = computeBackoffDelay(_reconnectAttempts);

    AppLogger.debug(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...',
      tag: 'WebSocketService',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  /// Calculates exponential backoff duration with random jitter up to 15 seconds.
  static Duration computeBackoffDelay(int attempts, {math.Random? random}) {
    final backoffSec = math.min(15, math.pow(2, math.min(attempts, 4)).toInt());
    final jitterMs = (random ?? math.Random()).nextInt(1000);
    return Duration(seconds: backoffSec, milliseconds: jitterMs);
  }

  @visibleForTesting
  void setMockChannel(WebSocketChannel channel) {
    _channel = channel;
    _isConnected = true;
  }

  /// Gracefully closes connection
  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _presenceController.close();
    _runnerLeftController.close();
    _alertController.close();
    _broadcastController.close();
    _connectionStateController.close();
  }
}
