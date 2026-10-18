import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/logging/app_logger.dart';
import '../models/ws_events.dart';
import 'api_client.dart';
import 'firebase_service.dart';

/// Real-Time WebSocket Service for live rival runner presence and territory alerts
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  final FirebaseService _firebaseService;
  final ApiClient _apiClient;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  bool _isConnected = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  final _presenceController = StreamController<RunnerPresenceEvent>.broadcast();
  final _runnerLeftController = StreamController<String>.broadcast();
  final _alertController = StreamController<TerritoryAlertEvent>.broadcast();
  final _broadcastController = StreamController<ConquestBroadcastEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<RunnerPresenceEvent> get presenceStream => _presenceController.stream;
  Stream<String> get runnerLeftStream => _runnerLeftController.stream;
  Stream<TerritoryAlertEvent> get alertStream => _alertController.stream;
  Stream<ConquestBroadcastEvent> get broadcastStream => _broadcastController.stream;
  Stream<bool> get isConnectedStream => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  WebSocketService._internal({FirebaseService? firebaseService, ApiClient? apiClient})
      : _firebaseService = firebaseService ?? FirebaseService(),
        _apiClient = apiClient ?? ApiClient();

  /// Visible for testing constructor
  @visibleForTesting
  WebSocketService.custom({required this._firebaseService, required this._apiClient});

  /// Establishes the real-time WebSocket connection to the Go backend
  void connect() {
    if (_isConnected || _isDisposed) return;

    _reconnectTimer?.cancel();
    final uid = _firebaseService.currentUserId;
    final httpBase = _apiClient.baseUrl;

    final wsScheme = httpBase.startsWith('https') ? 'wss' : 'ws';
    final hostAndPort = httpBase.replaceFirst(RegExp(r'^https?://'), '');
    final wsUri = Uri.parse('$wsScheme://$hostAndPort/v1/ws?user_id=$uid');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      AppLogger.info('Connected to real-time hub: $wsUri', tag: 'WebSocketService');

      _startHeartbeat();

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (err) {
          AppLogger.warning('WebSocket error: $err', tag: 'WebSocketService');
          _handleDisconnect();
        },
        onDone: () {
          AppLogger.info('WebSocket connection closed by server', tag: 'WebSocketService');
          _handleDisconnect();
        },
      );
    } catch (e) {
      AppLogger.warning('Failed to initiate WebSocket connection: $e', tag: 'WebSocketService');
      _handleDisconnect();
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
      AppLogger.error('Error parsing inbound WebSocket packet', error: e, stackTrace: st, tag: 'WebSocketService');
    }
  }

  /// Sends periodic kinematic position updates to nearby peers
  void sendPresenceUpdate({
    required double latitude,
    required double longitude,
    double speed = 0.0,
    double heading = 0.0,
  }) {
    if (!_isConnected || _channel == null) return;

    final packet = {
      'type': 'presence_update',
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
    };

    try {
      _channel!.sink.add(jsonEncode(packet));
    } catch (e) {
      AppLogger.warning('Failed to send presence update: $e', tag: 'WebSocketService');
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
    final backoffSec = math.min(15, math.pow(2, math.min(_reconnectAttempts, 4)).toInt());
    final jitterMs = math.Random().nextInt(1000);
    final delay = Duration(seconds: backoffSec, milliseconds: jitterMs);

    AppLogger.debug('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...', tag: 'WebSocketService');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
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
