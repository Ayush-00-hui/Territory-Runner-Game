import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/models/privacy_zone.dart';
import 'package:territory_runner/services/privacy_zone_service.dart';
import 'package:territory_runner/services/user_settings_service.dart';
import 'package:territory_runner/services/websocket_service.dart';
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WebSocketService Privacy Zone Suppression & Scale Throttling', () {
    test('Suppresses presence updates inside active privacy zones (defense-in-depth)', () async {
      final privacyService = PrivacyZoneService();
      await privacyService.loadZones();

      // Configure a 200m privacy zone centered at (37.7749, -122.4194)
      final homeZone = PrivacyZone(
        id: 'home_zone',
        name: 'Home',
        latitude: 37.7749,
        longitude: -122.4194,
        radiusMeters: 200.0,
        isEnabled: true,
        createdAt: DateTime.now(),
      );
      await privacyService.addZone(homeZone);

      final settingsService = UserSettingsService.custom(initial: LiveVisibility.nearby);
      final wsService = WebSocketService.custom(
        privacyZoneService: privacyService,
        userSettingsService: settingsService,
      );

      final fakeChannel = _FakeWebSocketChannel();
      wsService.setMockChannel(fakeChannel);

      // Coordinate directly at home center (inside 200m zone)
      final insideDispatched = wsService.sendPresenceUpdate(
        latitude: 37.7749,
        longitude: -122.4194,
        speed: 3.2,
      );

      expect(insideDispatched, isFalse);
      expect(fakeChannel._sink.sentMessages, isEmpty);

      // Coordinate 50 meters from home center (still inside 200m zone)
      final insideCloseDispatched = wsService.sendPresenceUpdate(
        latitude: 37.7753,
        longitude: -122.4194,
        speed: 3.2,
      );

      expect(insideCloseDispatched, isFalse);
      expect(fakeChannel._sink.sentMessages, isEmpty);

      // Coordinate 1,000 meters away (outside privacy zone)
      final outsideDispatched = wsService.sendPresenceUpdate(
        latitude: 37.7849,
        longitude: -122.4194,
        speed: 3.2,
        force: true, // bypass time throttle for test
      );

      expect(outsideDispatched, isTrue);
      expect(fakeChannel._sink.sentMessages.length, equals(1));
      expect(fakeChannel._sink.sentMessages.first, contains('presence_update'));
      expect(fakeChannel._sink.sentMessages.first, contains('37.7849'));
    });

    test('Throttles presence updates to minimum interval (2500ms)', () async {
      final privacyService = PrivacyZoneService();
      await privacyService.loadZones();

      final wsService = WebSocketService.custom(
        privacyZoneService: privacyService,
        userSettingsService: UserSettingsService.custom(initial: LiveVisibility.nearby),
      );

      final fakeChannel = _FakeWebSocketChannel();
      wsService.setMockChannel(fakeChannel);

      // First update succeeds
      final first = wsService.sendPresenceUpdate(
        latitude: 51.5074,
        longitude: -0.1278,
        speed: 2.5,
      );
      expect(first, isTrue);

      // Immediate second update (0ms elapsed) is throttled
      final second = wsService.sendPresenceUpdate(
        latitude: 51.5080,
        longitude: -0.1280,
        speed: 2.5,
      );
      expect(second, isFalse);

      // Forced update bypasses frequency throttling
      final forced = wsService.sendPresenceUpdate(
        latitude: 51.5080,
        longitude: -0.1280,
        speed: 2.5,
        force: true,
      );
      expect(forced, isTrue);
      expect(fakeChannel._sink.sentMessages.length, equals(2));
    });

    test('Stationary jitter deduplication suppresses duplicate static updates', () async {
      final privacyService = PrivacyZoneService();
      final wsService = WebSocketService.custom(
        privacyZoneService: privacyService,
        userSettingsService: UserSettingsService.custom(initial: LiveVisibility.nearby),
      );

      final fakeChannel = _FakeWebSocketChannel();
      wsService.setMockChannel(fakeChannel);

      // First fix
      final first = wsService.sendPresenceUpdate(
        latitude: 40.7128,
        longitude: -74.0060,
        speed: 0.1, // stationary
        force: true,
      );
      expect(first, isTrue);

      // Minor GPS jitter (< 1 meter away, speed < 0.5 m/s)
      final jitter = wsService.sendPresenceUpdate(
        latitude: 40.7128001,
        longitude: -74.0060001,
        speed: 0.1,
      );
      expect(jitter, isFalse);
      expect(fakeChannel._sink.sentMessages.length, equals(1));
    });

    test('Exponential backoff with jitter bounds and 15s ceiling', () {
      final minRandom = math.Random(0);

      // Attempt 1: 2^1 = 2 seconds + jitter
      final delay1 = WebSocketService.computeBackoffDelay(1, random: minRandom);
      expect(delay1.inSeconds, inInclusiveRange(2, 3));

      // Attempt 2: 2^2 = 4 seconds + jitter
      final delay2 = WebSocketService.computeBackoffDelay(2, random: minRandom);
      expect(delay2.inSeconds, inInclusiveRange(4, 5));

      // Attempt 3: 2^3 = 8 seconds + jitter
      final delay3 = WebSocketService.computeBackoffDelay(3, random: minRandom);
      expect(delay3.inSeconds, inInclusiveRange(8, 9));

      // Attempt 4+: Capped at 15 seconds + jitter
      final delay4 = WebSocketService.computeBackoffDelay(4, random: minRandom);
      expect(delay4.inSeconds, inInclusiveRange(15, 16));

      final delay10 = WebSocketService.computeBackoffDelay(10, random: minRandom);
      expect(delay10.inSeconds, inInclusiveRange(15, 16));
    });
  });
}
