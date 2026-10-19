import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/core/utils/geohash_utils.dart';
import 'package:territory_runner/features/profile/widgets/live_visibility_sheet.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/services/privacy_zone_service.dart';
import 'package:territory_runner/services/user_settings_service.dart';
import 'package:territory_runner/services/websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeSink implements WebSocketSink {
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

class _FakeChannel implements WebSocketChannel {
  final _FakeSink _sink = _FakeSink();
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

class _FakeUser implements User {
  final String token;
  bool forceRefreshPassed = false;

  _FakeUser({this.token = 'mock_jwt_token_prod'});

  @override
  String get uid => 'auth_runner_42';

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    forceRefreshPassed = forceRefresh;
    return token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseService implements FirebaseService {
  final User? mockUser;
  final String mockUserId;

  _FakeFirebaseService({this.mockUser, this.mockUserId = 'dev_runner_99'});

  @override
  User? get currentUser => mockUser;

  @override
  String get currentUserId => mockUserId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApiClient implements ApiClient {
  @override
  final String baseUrl;
  Map<String, dynamic>? mockSettings;
  Map<String, dynamic>? updatedSettings;

  _FakeApiClient({this.baseUrl = 'http://127.0.0.1:8080', this.mockSettings});

  @override
  Future<Map<String, dynamic>?> getSettings() async => mockSettings;

  @override
  Future<Map<String, dynamic>?> updateSettings(Map<String, dynamic> settings) async {
    updatedSettings = settings;
    return settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserSettingsService().resetForTesting();
  });

  group('WebSocket Authentication & Subprotocol Negotiation', () {
    test('Authenticated user sends ID token via Sec-WebSocket-Protocol and strips query params', () async {
      final fakeUser = _FakeUser(token: 'header_token_secret');
      final fakeFirebase = _FakeFirebaseService(mockUser: fakeUser);
      final fakeApi = _FakeApiClient(baseUrl: 'https://api.territoryrunner.com');

      final ws = WebSocketService.custom(
        firebaseService: fakeFirebase,
        apiClient: fakeApi,
      );

      final params = await ws.buildConnectionParams(forceRefresh: false);

      expect(params.uri.scheme, equals('wss'));
      expect(params.uri.host, equals('api.territoryrunner.com'));
      expect(params.uri.path, equals('/v1/ws'));
      expect(params.uri.query, isEmpty, reason: 'Tokens and user IDs must never leak into query strings in production');
      expect(params.protocols, equals(['bearer', 'header_token_secret']));
      expect(fakeUser.forceRefreshPassed, isFalse);
    });

    test('Reconnect forces token refresh to handle expired credentials', () async {
      final fakeUser = _FakeUser(token: 'refreshed_token');
      final fakeFirebase = _FakeFirebaseService(mockUser: fakeUser);
      final fakeApi = _FakeApiClient(baseUrl: 'http://10.0.2.2:8080');

      final ws = WebSocketService.custom(
        firebaseService: fakeFirebase,
        apiClient: fakeApi,
      );

      final params = await ws.buildConnectionParams(forceRefresh: true);
      expect(fakeUser.forceRefreshPassed, isTrue);
      expect(params.protocols, equals(['bearer', 'refreshed_token']));
    });

    test('Unauthenticated / Dev runner connects via ?dev_user with no subprotocols', () async {
      final fakeFirebase = _FakeFirebaseService(mockUser: null, mockUserId: 'local_dev_tester');
      final fakeApi = _FakeApiClient(baseUrl: 'http://localhost:8080');

      final ws = WebSocketService.custom(
        firebaseService: fakeFirebase,
        apiClient: fakeApi,
      );

      final params = await ws.buildConnectionParams();

      expect(params.uri.scheme, equals('ws'));
      expect(params.uri.queryParameters, equals({'dev_user': 'local_dev_tester'}));
      expect(params.protocols, isNull);
    });
  });

  group('UserSettingsService Privacy Defaults & Offline-First Persistence', () {
    test('Defaults to LiveVisibility.off on fresh install', () {
      final service = UserSettingsService.custom();
      expect(service.liveVisibility, equals(LiveVisibility.off));
      expect(service.liveVisibility.displayName, equals('Off'));
      expect(service.liveVisibility.description, contains('never shared'));
    });

    test('Enum serialization round-trips correctly with safe default fallback', () {
      expect(LiveVisibility.fromString('off'), equals(LiveVisibility.off));
      expect(LiveVisibility.fromString('friends'), equals(LiveVisibility.friends));
      expect(LiveVisibility.fromString('nearby'), equals(LiveVisibility.nearby));
      expect(LiveVisibility.fromString('invalid_mode'), equals(LiveVisibility.off));
      expect(LiveVisibility.fromString(null), equals(LiveVisibility.off));

      expect(LiveVisibility.off.toApiValue(), equals('off'));
      expect(LiveVisibility.friends.toApiValue(), equals('friends'));
      expect(LiveVisibility.nearby.toApiValue(), equals('nearby'));
    });

    test('setLiveVisibility updates memory, persists to SharedPreferences, and calls API', () async {
      final fakeApi = _FakeApiClient();
      final service = UserSettingsService.custom(apiClient: fakeApi);

      await service.setLiveVisibility(LiveVisibility.nearby);

      expect(service.liveVisibility, equals(LiveVisibility.nearby));
      expect(fakeApi.updatedSettings, equals({'live_visibility': 'nearby'}));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_live_visibility'), equals('nearby'));
    });

    test('syncWithServer loads remote visibility preference and syncs to SharedPreferences', () async {
      final fakeApi = _FakeApiClient(mockSettings: {'live_visibility': 'friends'});
      final service = UserSettingsService.custom(apiClient: fakeApi, initial: LiveVisibility.off);

      await service.syncWithServer();

      expect(service.liveVisibility, equals(LiveVisibility.friends));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_live_visibility'), equals('friends'));
    });
  });

  group('WebSocketService Presence Suppression by Consent', () {
    test('Suppresses outbound presence packet entirely when liveVisibility is off', () async {
      final privacyService = PrivacyZoneService();
      await privacyService.loadZones();

      final settingsService = UserSettingsService.custom(initial: LiveVisibility.off);
      final ws = WebSocketService.custom(
        privacyZoneService: privacyService,
        userSettingsService: settingsService,
      );

      final channel = _FakeChannel();
      ws.setMockChannel(channel);

      final dispatched = ws.sendPresenceUpdate(
        latitude: 37.7749,
        longitude: -122.4194,
        speed: 3.5,
        force: true,
      );

      expect(dispatched, isFalse, reason: 'Outbound presence must be dropped on client when visibility is off');
      expect(channel._sink.sentMessages, isEmpty);
    });

    test('Dispatches presence update when liveVisibility is nearby and outside privacy zone', () async {
      final privacyService = PrivacyZoneService();
      await privacyService.loadZones();

      final settingsService = UserSettingsService.custom(initial: LiveVisibility.nearby);
      final ws = WebSocketService.custom(
        privacyZoneService: privacyService,
        userSettingsService: settingsService,
      );

      final channel = _FakeChannel();
      ws.setMockChannel(channel);

      final dispatched = ws.sendPresenceUpdate(
        latitude: 37.7749,
        longitude: -122.4194,
        speed: 3.5,
        force: true,
      );

      expect(dispatched, isTrue);
      expect(channel._sink.sentMessages.length, equals(1));
    });
  });

  group('GeohashUtils Standard Precision 6 & Spatial Neighbors', () {
    test('Encodes standard coordinates with precision 6', () {
      final hash = GeohashUtils.encode(37.7749, -122.4194, 6);
      expect(hash.length, equals(6));
      expect(hash, equals('9q8yyk'));
    });

    test('Calculates 8 unique neighboring cells around a geohash', () {
      final center = '9q8yyk';
      final n = GeohashUtils.neighbors(center);
      expect(n.length, equals(8));
      expect(n.toSet().length, equals(8), reason: 'All 8 neighbors must be unique');
      expect(n.contains(center), isFalse);
    });

    test('Decodes bounds covering original point', () {
      final hash = '9q8yyk';
      final bounds = GeohashUtils.decodeBounds(hash);
      expect(37.7749, inInclusiveRange(bounds.minLat, bounds.maxLat));
      expect(-122.4194, inInclusiveRange(bounds.minLng, bounds.maxLng));
    });

    test('computeViewportCells returns center plus 8 neighbors (9 cells total)', () {
      final cells = GeohashUtils.computeViewportCells(const LatLng(37.7749, -122.4194));
      expect(cells.length, equals(9));
      expect(cells.first, equals('9q8yyk'));
      expect(cells.toSet().length, equals(9));
    });
  });

  group('LiveVisibilitySheet UI Widget Tests', () {
    testWidgets('Renders all visibility options and displays default off state', (tester) async {
      final settings = UserSettingsService();
      settings.resetForTesting(initial: LiveVisibility.off);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveVisibilitySheetContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Location Visibility'), findsOneWidget);
      expect(find.text('Off (Recommended)'), findsOneWidget);
      expect(find.text('Friends only'), findsOneWidget);
      expect(find.text('Nearby runners'), findsOneWidget);

      // Verify that radio icon is checked for Off
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_off), findsNWidgets(2));
    });

    testWidgets('Tapping Nearby runners option updates UserSettingsService', (tester) async {
      final settings = UserSettingsService();
      settings.resetForTesting(initial: LiveVisibility.off);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveVisibilitySheetContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nearby runners'));
      await tester.pumpAndSettle();

      expect(settings.liveVisibility, equals(LiveVisibility.nearby));
    });
  });
}
