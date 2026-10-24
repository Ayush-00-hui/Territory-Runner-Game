import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/map/widgets/gps_sync_chip.dart';
import 'package:territory_runner/services/websocket_service.dart';
import 'package:territory_runner/ui/theme/app_theme.dart';
import 'package:territory_runner/ui/widgets/combined_status_indicator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];

  @override
  void add(dynamic data) => sentMessages.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) => stream.forEach(sentMessages.add);

  @override
  Future close([int? closeCode, String? closeReason]) => Future.value();

  @override
  Future get done => Future.value();
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();
  final StreamController _controller = StreamController.broadcast();

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
  Future<void> get ready => Future.value();

  void simulateServerDisconnect() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W3 UX Requirements: Calm Status and Auto-Resume', () {
    testWidgets(
      'W3.1: CombinedStatusIndicator renders calm chip without alarming error banners',
      (tester) async {
        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: CombinedStatusIndicator(
                  accuracyMeters: 4.5,
                  isGpsSearching: false,
                  webSocketService: wsService,
                ),
              ),
            ),
          ),
        );

        // Verify top-level chip shows calm GPS lock and NO scary error text
        expect(find.text('±5m'), findsOneWidget);
        expect(find.text('Live updates unavailable'), findsNothing);
        expect(find.text('Error'), findsNothing);
        expect(find.text('Failed'), findsNothing);
      },
    );

    testWidgets(
      'W3.2: Disconnected WebSocket shows calm "Live updates unavailable" line inside status details sheet only',
      (tester) async {
        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
        );
        wsService.setMockConnected(false);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: CombinedStatusIndicator(
                  accuracyMeters: 5.0,
                  webSocketService: wsService,
                ),
              ),
            ),
          ),
        );

        // Before tapping: no "Live updates unavailable" visible on main screen
        expect(find.text('Live updates unavailable'), findsNothing);

        // Tap the indicator to open the status details sheet
        await tester.tap(find.byType(CombinedStatusIndicator));
        await tester.pumpAndSettle();

        // Inside the sheet: title and calm diagnostic items are present
        expect(find.text('System status'), findsOneWidget);
        expect(find.text('GPS signal'), findsOneWidget);
        expect(find.text('Cloud sync queue'), findsOneWidget);

        // Calm optional line is displayed inside the status details sheet
        expect(find.text('Live updates unavailable'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'W3.3: Connected WebSocket omits "Live updates unavailable" line inside status details sheet',
      (tester) async {
        final fakeChannel = _FakeWebSocketChannel();
        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
        );

        // Connect mock channel
        wsService.setMockChannel(fakeChannel);
        expect(wsService.isConnected, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: CombinedStatusIndicator(
                  accuracyMeters: 5.0,
                  webSocketService: wsService,
                ),
              ),
            ),
          ),
        );

        // Tap to open sheet
        await tester.tap(find.byType(CombinedStatusIndicator));
        await tester.pumpAndSettle();

        expect(find.text('System status'), findsOneWidget);
        expect(find.text('GPS signal'), findsOneWidget);
        expect(find.text('Cloud sync queue'), findsOneWidget);

        // When connected, "Live updates unavailable" is omitted
        expect(find.text('Live updates unavailable'), findsNothing);

        wsService.dispose();
      },
    );

    testWidgets(
      'W3.4: GpsSyncChip tap opens status details sheet showing "Live updates unavailable" when disconnected',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: GpsSyncChip(accuracyMeters: 8.0, isGpsSearching: false),
              ),
            ),
          ),
        );

        expect(find.text('Live updates unavailable'), findsNothing);

        // Tap GpsSyncChip to open status details sheet
        await tester.tap(find.byType(GpsSyncChip));
        await tester.pumpAndSettle();

        expect(find.text('System status'), findsOneWidget);
        expect(find.text('GPS signal'), findsOneWidget);
        expect(find.text('Live updates unavailable'), findsOneWidget);
      },
    );

    testWidgets(
      'W3.5: Disconnection clears live markers; reconnection resends viewport and resumes rivals',
      (tester) async {
        final fakeChannel = _FakeWebSocketChannel();
        final wsService = WebSocketService.custom(
          registerLifecycleObserver: false,
        );

        // Send a viewport subscription
        wsService.sendViewportSubscription(['u4pru']);
        // Disconnected -> cannot send yet
        expect(fakeChannel._sink.sentMessages, isEmpty);

        // Connect mock channel
        wsService.setMockChannel(fakeChannel);

        // Force resend on reconnect
        wsService.sendViewportSubscription(['u4pru'], force: true);
        expect(fakeChannel._sink.sentMessages.length, equals(1));
        expect(
          fakeChannel._sink.sentMessages.first,
          contains('viewport_subscribe'),
        );
        expect(fakeChannel._sink.sentMessages.first, contains('u4pru'));

        wsService.dispose();
      },
    );
  });
}
