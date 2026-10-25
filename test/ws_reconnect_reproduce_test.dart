// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/websocket_service.dart';

void main() {
  group('WebSocketService W2 Verification Tests', () {
    test('Scenario (a) - Backend stopped: caught cleanly with zero unhandled exceptions and exponential backoff scheduled', () async {
      final tempServer = await ServerSocket.bind('127.0.0.1', 0);
      final closedPort = tempServer.port;
      await tempServer.close();

      final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:$closedPort');
      final wsService = WebSocketService.custom(
        apiClient: apiClient,
        registerLifecycleObserver: false,
      );

      Object? unhandledZoneError;
      await runZonedGuarded(
        () async {
          await wsService.connect();
          // Give event loop time to process
          await Future.delayed(const Duration(milliseconds: 2500));
        },
        (error, stack) {
          unhandledZoneError = error;
        },
      );

      expect(
        unhandledZoneError,
        isNull,
        reason: 'channel.ready error must be caught inside connect() with zero unhandled zone exceptions',
      );
      expect(wsService.isConnected, isFalse);
      expect(wsService.reconnectAttempts, greaterThanOrEqualTo(1));

      wsService.disconnect();
      wsService.dispose();
    });

    test('Scenario (b) - Backend running in dev mode: connects and processes events', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.transform(WebSocketTransformer()).listen((WebSocket ws) {
        ws.add(
          '{"type":"conquest_broadcast","attacker_name":"Runner1","area_claimed_sqm":100}',
        );
      });

      final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final wsService = WebSocketService.custom(
        apiClient: apiClient,
        registerLifecycleObserver: false,
      );

      final completer = Completer<String>();
      final sub = wsService.broadcastStream.listen((event) {
        if (!completer.isCompleted) completer.complete(event.attackerName);
      });

      await wsService.connect();
      final attacker = await completer.future.timeout(
        const Duration(seconds: 2),
      );

      expect(wsService.isConnected, isTrue);
      expect(attacker, equals('Runner1'));

      await sub.cancel();
      wsService.disconnect();
      wsService.dispose();
      await server.close(force: true);
    });

    test('Scenario (c) - Backend in production/firebase mode (401 Unauthorized): caught cleanly, stops retries, unblocks on token refresh', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((HttpRequest req) {
        req.response.statusCode = HttpStatus.unauthorized;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          '{"error":"UNAUTHORIZED","message":"Missing or invalid credentials for WebSocket"}',
        );
        req.response.close();
      });

      final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final wsService = WebSocketService.custom(
        apiClient: apiClient,
        registerLifecycleObserver: false,
      );

      Object? unhandledZoneError;
      await runZonedGuarded(
        () async {
          await wsService.connect();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        (error, stack) {
          unhandledZoneError = error;
        },
      );

      expect(
        unhandledZoneError,
        isNull,
        reason: 'Handshake 401 error must be caught inside connect() with zero unhandled zone exceptions',
      );
      expect(wsService.isConnected, isFalse);
      expect(
        wsService.isAuthBlocked,
        isTrue,
        reason: 'Auth rejection must set isAuthBlocked to prevent infinite retry loops',
      );

      // Verify that token refresh unblocks auth retries
      await runZonedGuarded(
        () async {
          wsService.onTokenRefreshed();
          expect(wsService.isAuthBlocked, isFalse);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        (error, stack) {
          unhandledZoneError = error;
        },
      );

      expect(unhandledZoneError, isNull);

      wsService.disconnect();
      wsService.dispose();
      await server.close(force: true);
    });
  });
}
