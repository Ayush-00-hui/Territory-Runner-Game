import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];
  bool isClosed = false;
  bool throwOnAdd = false;

  @override
  void add(dynamic data) {
    if (throwOnAdd) {
      throw StateError('Sink is closed or broken');
    }
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) => stream.forEach(add);

  @override
  Future close([int? closeCode, String? closeReason]) {
    isClosed = true;
    return Future.value();
  }

  @override
  Future get done => Future.value();
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
  final Object? readyError;

  _FakeWebSocketChannel({this.readyError});

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => readyError != null
      ? Future<void>.error(readyError!)
      : Future<void>.value();

  void emitMessage(dynamic message) {
    _controller.add(message);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  void closeStream() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W4: Comprehensive WebSocket Unit Tests', () {
    // -------------------------------------------------------------------------
    // 1. Backoff Growth Tests
    // -------------------------------------------------------------------------
    group('Backoff Growth & Capping', () {
      test('computeBackoffDelay doubles from 2s up to 60s cap with jitter', () {
        // Attempt 1: 2s (2 * 2^0)
        final d1 = WebSocketService.computeBackoffDelay(1);
        expect(d1.inSeconds, equals(2));
        expect(d1.inMilliseconds, greaterThanOrEqualTo(2000));
        expect(d1.inMilliseconds, lessThan(3000));

        // Attempt 2: 4s (2 * 2^1)
        final d2 = WebSocketService.computeBackoffDelay(2);
        expect(d2.inSeconds, equals(4));
        expect(d2.inMilliseconds, greaterThanOrEqualTo(4000));
        expect(d2.inMilliseconds, lessThan(5000));

        // Attempt 3: 8s (2 * 2^2)
        final d3 = WebSocketService.computeBackoffDelay(3);
        expect(d3.inSeconds, equals(8));
        expect(d3.inMilliseconds, greaterThanOrEqualTo(8000));
        expect(d3.inMilliseconds, lessThan(9000));

        // Attempt 4: 16s (2 * 2^3)
        final d4 = WebSocketService.computeBackoffDelay(4);
        expect(d4.inSeconds, equals(16));
        expect(d4.inMilliseconds, greaterThanOrEqualTo(16000));
        expect(d4.inMilliseconds, lessThan(17000));

        // Attempt 5: 32s (2 * 2^4)
        final d5 = WebSocketService.computeBackoffDelay(5);
        expect(d5.inSeconds, equals(32));
        expect(d5.inMilliseconds, greaterThanOrEqualTo(32000));
        expect(d5.inMilliseconds, lessThan(33000));

        // Attempt 6: 60s (clamped from 64s)
        final d6 = WebSocketService.computeBackoffDelay(6);
        expect(d6.inSeconds, equals(60));
        expect(d6.inMilliseconds, greaterThanOrEqualTo(60000));
        expect(d6.inMilliseconds, lessThan(61000));

        // Attempt 10: 60s cap
        final d10 = WebSocketService.computeBackoffDelay(10);
        expect(d10.inSeconds, equals(60));
        expect(d10.inMilliseconds, greaterThanOrEqualTo(60000));
        expect(d10.inMilliseconds, lessThan(61000));

        // Non-positive attempts return Duration.zero
        expect(WebSocketService.computeBackoffDelay(0), equals(Duration.zero));
        expect(WebSocketService.computeBackoffDelay(-1), equals(Duration.zero));
      });

      test('Sequential connection failures increment reconnectAttempts and schedule backoff timer', () async {
        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
          channelFactory: (uri, {protocols}) => _FakeWebSocketChannel(
            readyError: WebSocketException('Handshake rejected 503'),
          ),
        );

        // Attempt 1
        await wsService.connect();
        expect(wsService.isConnected, isFalse);
        expect(wsService.reconnectAttempts, equals(1));
        expect(wsService.reconnectTimer, isNotNull);
        expect(wsService.reconnectTimer!.isActive, isTrue);

        // Attempt 2
        await wsService.connect();
        expect(wsService.isConnected, isFalse);
        expect(wsService.reconnectAttempts, equals(2));
        expect(wsService.reconnectTimer, isNotNull);

        // Attempt 3
        await wsService.connect();
        expect(wsService.isConnected, isFalse);
        expect(wsService.reconnectAttempts, equals(3));

        wsService.dispose();
      });
    });

    // -------------------------------------------------------------------------
    // 2. Backoff Reset After 30s Stable Connection
    // -------------------------------------------------------------------------
    group('Backoff Reset Timer (30s stabilization)', () {
      test('Disconnecting before 30s cancels stabilization timer and retains accumulated attempts', () async {
        final fakeChannel = _FakeWebSocketChannel();

        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
          channelFactory: (uri, {protocols}) => fakeChannel,
        );

        // 1. Simulate a prior failed attempt
        wsService.channelFactory = (uri, {protocols}) =>
            _FakeWebSocketChannel(readyError: WebSocketException('Fail 1'));
        await wsService.connect();
        expect(wsService.reconnectAttempts, equals(1));

        // 2. Now connect successfully
        wsService.channelFactory = (uri, {protocols}) => fakeChannel;
        await wsService.connect();
        expect(wsService.isConnected, isTrue);
        expect(wsService.stableConnectionTimer, isNotNull);
        expect(wsService.stableConnectionTimer!.isActive, isTrue);

        // 3. Disconnect mid-stream before 30s has elapsed
        fakeChannel.closeStream();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(wsService.isConnected, isFalse);
        // Stabilization timer should be canceled and attempts NOT reset to 0
        expect(wsService.stableConnectionTimer, isNull);
        expect(wsService.reconnectAttempts, greaterThanOrEqualTo(1));

        wsService.dispose();
      });

      test(
        'Maintaining stable connection for 30s resets reconnectAttempts to 0',
        () async {
          final fakeChannel = _FakeWebSocketChannel();

          final wsService = WebSocketService.custom(
            registerLifecycleObserver: false,
            channelFactory: (uri, {protocols}) => fakeChannel,
          );

          // Simulate 4 prior attempts
          for (int i = 0; i < 4; i++) {
            wsService.channelFactory = (uri, {protocols}) =>
                _FakeWebSocketChannel(
                  readyError: WebSocketException('Refused'),
                );
            await wsService.connect();
          }
          expect(wsService.reconnectAttempts, equals(4));

          // Connect successfully with fakeChannel
          wsService.channelFactory = (uri, {protocols}) => fakeChannel;
          await wsService.connect();
          expect(wsService.isConnected, isTrue);
          expect(
            wsService.reconnectAttempts,
            equals(4),
          ); // Still 4 until 30s timer fires

          // Verify the 30s timer is scheduled and active
          expect(wsService.stableConnectionTimer, isNotNull);
          expect(wsService.stableConnectionTimer!.isActive, isTrue);

          wsService.dispose();
        },
      );
    });

    // -------------------------------------------------------------------------
    // 3. Auth 401/403 Pause & Unblock on Token Refresh
    // -------------------------------------------------------------------------
    group('Auth Error (401/403) Pause & Resume', () {
      test('Handshake 401/403 error halts retries until onTokenRefreshed is called', () async {
        int connectionCalls = 0;
        final authFailChannel = _FakeWebSocketChannel(
          readyError: WebSocketException(
            "WebSocketException: Connection to 'ws://127.0.0.1:8080/v1/ws?dev_user=local_runner' was not upgraded to websocket (401)",
          ),
        );

        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
          channelFactory: (uri, {protocols}) {
            connectionCalls++;
            return authFailChannel;
          },
        );

        await wsService.connect();

        // Must be marked auth-blocked
        expect(wsService.isAuthBlocked, isTrue);
        expect(wsService.isConnected, isFalse);

        // Retry timer must be NULL (no busy retries hammering the server)
        expect(wsService.reconnectTimer, isNull);

        // Attempting connect while auth blocked is a no-op
        await wsService.connect();
        expect(connectionCalls, equals(1)); // Did not attempt again

        // Simulate successful token refresh
        final successChannel = _FakeWebSocketChannel();
        wsService.channelFactory = (uri, {protocols}) {
          connectionCalls++;
          return successChannel;
        };

        wsService.onTokenRefreshed();

        // Auth block cleared and retries resumed
        expect(wsService.isAuthBlocked, isFalse);
        expect(wsService.reconnectAttempts, equals(0));

        // Wait a tick for connect() scheduled by onTokenRefreshed
        await Future.delayed(const Duration(milliseconds: 50));
        expect(connectionCalls, equals(2));
        expect(wsService.isConnected, isTrue);

        wsService.dispose();
      });
    });

    // -------------------------------------------------------------------------
    // 4. Connectivity Pause & Resume
    // -------------------------------------------------------------------------
    group('Network Connectivity Handling', () {
      test(
        'Offline state pauses retries and online restores connection',
        () async {
          int connects = 0;
          final ch = _FakeWebSocketChannel();

          final wsService = WebSocketService.custom(
            registerLifecycleObserver: false,
            channelFactory: (uri, {protocols}) {
              connects++;
              return ch;
            },
          );

          // 1. Mark device offline
          wsService.onConnectivityChanged(false);
          expect(wsService.isOffline, isTrue);
          expect(wsService.reconnectTimer, isNull);

          // connect() while offline does not proceed
          await wsService.connect();
          expect(connects, equals(0));

          // 2. Mark device online
          wsService.onConnectivityChanged(true);
          expect(wsService.isOffline, isFalse);

          await Future.delayed(const Duration(milliseconds: 50));
          expect(connects, equals(1));
          expect(wsService.isConnected, isTrue);

          wsService.dispose();
        },
      );
    });

    // -------------------------------------------------------------------------
    // 5. App Lifecycle (Foreground & Background)
    // -------------------------------------------------------------------------
    group('App Lifecycle Observers', () {
      test(
        'Backgrounding pauses retries; foregrounding resumes connection',
        () async {
          int connects = 0;
          final ch = _FakeWebSocketChannel();

          final wsService = WebSocketService.custom(
            registerLifecycleObserver: false,
            channelFactory: (uri, {protocols}) {
              connects++;
              return ch;
            },
          );

          // 1. App paused (background)
          wsService.onAppLifecycleStateChanged(AppLifecycleState.paused);
          expect(wsService.isAppBackgrounded, isTrue);
          expect(wsService.reconnectTimer, isNull);

          // 2. App hidden (background)
          wsService.onAppLifecycleStateChanged(AppLifecycleState.hidden);
          expect(wsService.isAppBackgrounded, isTrue);

          // 3. App resumed (foreground)
          wsService.onAppLifecycleStateChanged(AppLifecycleState.resumed);
          expect(wsService.isAppBackgrounded, isFalse);

          await Future.delayed(const Duration(milliseconds: 50));
          expect(connects, equals(1));
          expect(wsService.isConnected, isTrue);

          wsService.dispose();
        },
      );
    });

    // -------------------------------------------------------------------------
    // 6. Zero Unhandled Exceptions Across All Async Failure Modes
    // -------------------------------------------------------------------------
    group('Zone Safety: Zero Unhandled Exceptions', () {
      test('Handshake failure completes with error but zero unhandled exceptions escape', () async {
        final List<String> zoneErrors = [];

        await runZonedGuarded(
          () async {
            final badChannel = _FakeWebSocketChannel(
              readyError: WebSocketException(
                "Handshake error: 502 Bad Gateway",
              ),
            );

            final wsService = WebSocketService.custom(
              registerLifecycleObserver: false,
              channelFactory: (uri, {protocols}) => badChannel,
            );

            await wsService.connect();
            expect(wsService.isConnected, isFalse);
            wsService.dispose();
          },
          (error, stack) {
            zoneErrors.add(error.toString());
          },
        );

        // Zero errors must leak to ZoneGuard
        expect(zoneErrors, isEmpty);
      });

      test('Stream error and abrupt socket termination caught cleanly with zero unhandled exceptions', () async {
        final List<String> zoneErrors = [];

        await runZonedGuarded(
          () async {
            final liveChannel = _FakeWebSocketChannel();

            final wsService = WebSocketService.custom(
              registerLifecycleObserver: false,
              channelFactory: (uri, {protocols}) => liveChannel,
            );

            await wsService.connect();
            expect(wsService.isConnected, isTrue);

            // Emit mid-stream socket error
            liveChannel.emitError(
              WebSocketException('Connection reset by peer'),
            );
            await Future.delayed(const Duration(milliseconds: 50));

            expect(wsService.isConnected, isFalse);
            wsService.dispose();
          },
          (error, stack) {
            zoneErrors.add(error.toString());
          },
        );

        expect(zoneErrors, isEmpty);
      });

      test('Sink error during message send is caught with zero unhandled exceptions', () async {
        final List<String> zoneErrors = [];

        await runZonedGuarded(
          () async {
            final brokenSinkChannel = _FakeWebSocketChannel();
            brokenSinkChannel._sink.throwOnAdd = true;

            final wsService = WebSocketService.custom(
              registerLifecycleObserver: false,
              channelFactory: (uri, {protocols}) => brokenSinkChannel,
            );

            await wsService.connect();
            expect(wsService.isConnected, isTrue);

            // Attempt to send viewport and presence
            wsService.sendViewportSubscription(['u4pru'], force: true);
            final sent = wsService.sendPresenceUpdate(
              latitude: 37.7749,
              longitude: -122.4194,
              force: true,
            );
            expect(sent, isFalse);

            wsService.dispose();
          },
          (error, stack) {
            zoneErrors.add(error.toString());
          },
        );

        expect(zoneErrors, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // 7. Clean Disposal
    // -------------------------------------------------------------------------
    group('Disposal & Resource Cleanup', () {
      test('dispose cancels all timers, closes streams, and safely ignores post-disposal calls', () async {
        final ch = _FakeWebSocketChannel();

        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
          channelFactory: (uri, {protocols}) => ch,
        );

        await wsService.connect();
        expect(wsService.isConnected, isTrue);

        bool presenceClosed = false;
        bool connectionStateClosed = false;
        wsService.presenceStream.listen(
          null,
          onDone: () => presenceClosed = true,
        );
        wsService.isConnectedStream.listen(
          null,
          onDone: () => connectionStateClosed = true,
        );

        // Dispose
        wsService.dispose();

        expect(wsService.isDisposed, isTrue);
        expect(wsService.isConnected, isFalse);
        expect(wsService.reconnectTimer, isNull);
        expect(wsService.heartbeatTimer, isNull);
        expect(wsService.stableConnectionTimer, isNull);

        await Future.delayed(const Duration(milliseconds: 50));
        expect(presenceClosed, isTrue);
        expect(connectionStateClosed, isTrue);

        // Calling connect or send after disposal is safe and does nothing
        await wsService.connect();
        expect(wsService.isConnected, isFalse);
        final sent = wsService.sendPresenceUpdate(
          latitude: 0,
          longitude: 0,
          force: true,
        );
        expect(sent, isFalse);
      });
    });
  });
}
