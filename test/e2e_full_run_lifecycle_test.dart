import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/models/activity_type.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/sync_queue.dart';

void main() {
  late Directory tempDir;
  late Box<String> testUnsyncedBox;
  late Box<String> testRejectedBox;
  late Box<Territory> testTerritoryBox;
  late Box<RunnerProfile> testProfileBox;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('e2e_client_lifecycle_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testUnsyncedBox = await Hive.openBox<String>(
      'test_unsynced_runs_${DateTime.now().microsecondsSinceEpoch}',
    );
    testRejectedBox = await Hive.openBox<String>(
      'test_rejected_runs_${DateTime.now().microsecondsSinceEpoch}',
    );
    testTerritoryBox = await Hive.openBox<Territory>('territories_v3');
    testProfileBox = await Hive.openBox<RunnerProfile>('profile');
    await testUnsyncedBox.clear();
    await testRejectedBox.clear();
    await testTerritoryBox.clear();
    await testProfileBox.clear();
  });

  tearDown(() async {
    if (testUnsyncedBox.isOpen) await testUnsyncedBox.close();
    if (testRejectedBox.isOpen) await testRejectedBox.close();
    if (testTerritoryBox.isOpen) await testTerritoryBox.close();
    if (testProfileBox.isOpen) await testProfileBox.close();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Client-Side End-to-End Full Run Lifecycle', () {
    test('Complete run: GPS tracking -> loop enclosure -> optimistic territory -> offline queue -> cloud sync & reconciliation', () async {
      // 1. Initialize GPS Enclosure Engine
      final engine = PolygonEnclosureEngine(
        minClosureDistanceMeters: 35.0,
        minPointsRequired: 4,
        minLoopDistanceMeters: 40.0,
      );

      // 2. Simulate runner's GPS breadcrumbs forming a ~100m x 100m loop in London (~7,000 m²)
      final p1 = const LatLng(51.5000, -0.1200);
      final p2 = const LatLng(51.5009, -0.1200);
      final p3 = const LatLng(51.5009, -0.1214);
      final p4 = const LatLng(51.5000, -0.1214);
      final p5 = const LatLng(
        51.5001,
        -0.1201,
      ); // within ~15m of p1 (closure threshold)

      expect(engine.addPosition(p1), isNull);
      expect(engine.addPosition(p2), isNull);
      expect(engine.addPosition(p3), isNull);
      expect(engine.addPosition(p4), isNull);

      // Enclosure detection fires on 5th position
      final EnclosedLoopEvent? loopEvent = engine.addPosition(p5);
      expect(
        loopEvent,
        isNotNull,
        reason: 'Engine must detect loop closure within 35m proximity',
      );
      expect(loopEvent!.polygon.length, equals(5));
      expect(loopEvent.areaSqMeters, greaterThan(5000.0));
      expect(loopEvent.loopDistanceMeters, greaterThan(200.0));

      // 3. Optimistic local territory capture via TerritoryService
      final territoryService = TerritoryService();
      final optimisticTerritory = await territoryService
          .capturePolygonTerritory(
            polygon: loopEvent.polygon,
            areaSqMeters: loopEvent.areaSqMeters,
            ownerId: 'test_runner_e2e_001',
          );

      expect(optimisticTerritory, isNotNull);
      expect(optimisticTerritory.areaSqMeters, greaterThan(5000.0));
      expect(
        territoryService.getCapturedTerritories(),
        contains(optimisticTerritory.id),
      );
      expect(territoryService.lastCaptureXp, greaterThan(0));

      // 4. Configure Mock Backend HTTP Client for Authoritative Reconciliation
      int serverReceivedCalls = 0;
      final mockClient = MockClient((http.Request req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/runs')) {
          serverReceivedCalls++;
          final reqPayload = jsonDecode(req.body) as Map<String, dynamic>;

          expect(
            reqPayload['activity_type'],
            equals(ExerciseActivityType.running.id),
          );
          expect(reqPayload['idempotency_key'], equals('idem_client_e2e_001'));
          expect(reqPayload['points'], hasLength(5));

          // Return authoritative PostGIS response with +150 m² server-side calculation bonus
          final authoritativeClaimedArea = loopEvent.areaSqMeters + 150.0;
          return http.Response(
            jsonEncode({
              'run_id': 'run_srv_e2e_authoritative_999',
              'idempotency_key': reqPayload['idempotency_key'],
              'activity_type': 'running',
              'status': 'accepted',
              'anomaly_score': 0.0,
              'anomaly_reasons': <String>[],
              'loop_detected': true,
              'area_claimed_sqm': authoritativeClaimedArea,
              'player_total_area_sqm': authoritativeClaimedArea,
              'xp_awarded': 350,
              'rivals_affected': <String>[],
              'territory_geojson': '{"type":"MultiPolygon","coordinates":[[[[-0.1200,51.5000],[-0.1200,51.5009],[-0.1214,51.5009],[-0.1214,51.5000],[-0.1200,51.5000]]]]}',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://test-server',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        territoryService: territoryService,
        overrideBox: testUnsyncedBox,
        overrideRejectedBox: testRejectedBox,
      );

      // 5. Enqueue completed run into persistent offline queue
      final queuedItem = await syncQueue.enqueueRun(
        idempotencyKey: 'idem_client_e2e_001',
        activityType: ExerciseActivityType.running.id,
        points: loopEvent.polygon,
        durationSeconds: 360,
        distanceMeters: loopEvent.loopDistanceMeters,
        clientPreviewArea: loopEvent.areaSqMeters,
        clientPreviewXp: territoryService.lastCaptureXp,
        autoSync: false, // Manual trigger to verify discrete step transitions
      );

      expect(queuedItem.idempotencyKey, equals('idem_client_e2e_001'));
      expect(queuedItem.activityType, equals('running'));
      expect(testUnsyncedBox.containsKey('idem_client_e2e_001'), isTrue);
      expect(syncQueue.unsettledCountNotifier.value, equals(1));
      expect(syncQueue.statusNotifier.value, equals(SyncStatus.pending));

      // 6. Execute synchronization
      final syncSuccess = await syncQueue.syncPendingRuns();

      // 7. Verify sync completion and authoritative state reconciliation
      expect(syncSuccess, isTrue);
      expect(serverReceivedCalls, equals(1));
      expect(
        testUnsyncedBox.isEmpty,
        isTrue,
        reason: 'Pending queue must be completely drained upon 201 Created',
      );
      expect(syncQueue.unsettledCountNotifier.value, equals(0));
      expect(syncQueue.statusNotifier.value, equals(SyncStatus.synced));

      // Verify authoritative server discrepancy notification was triggered
      expect(syncQueue.reconciliationToastNotifier.value, isNotNull);
      expect(
        syncQueue.reconciliationToastNotifier.value,
        contains('Server verified +150.0 m² bonus'),
        reason: 'Authoritative server area difference must trigger runner toast notification',
      );

      // Verify territory in local storage was replaced with authoritative server MultiPolygon
      final updatedTerritories = territoryService.getCapturedTerritoryObjects();
      expect(updatedTerritories.isNotEmpty, isTrue);
    });

    test('Network failure retains run in persistent queue with incremented retry count and offline status', () async {
      final mockClient = MockClient((req) async {
        throw const SocketException('Network interface unavailable');
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://test-server',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        overrideBox: testUnsyncedBox,
        overrideRejectedBox: testRejectedBox,
      );

      await syncQueue.enqueueRun(
        idempotencyKey: 'idem_offline_002',
        activityType: ExerciseActivityType.running.id,
        points: const [LatLng(51.5, -0.12), LatLng(51.501, -0.12)],
        durationSeconds: 120,
        distanceMeters: 200.0,
        clientPreviewArea: 1000.0,
        clientPreviewXp: 50,
        autoSync: false,
      );

      expect(testUnsyncedBox.containsKey('idem_offline_002'), isTrue);

      final success = await syncQueue.syncPendingRuns();

      expect(success, isFalse);
      expect(
        testUnsyncedBox.containsKey('idem_offline_002'),
        isTrue,
        reason: 'Run must not be dropped on transient error',
      );
      expect(syncQueue.statusNotifier.value, equals(SyncStatus.offline));
      expect(syncQueue.unsettledCountNotifier.value, equals(1));

      final rawStored = testUnsyncedBox.get('idem_offline_002');
      expect(rawStored, isNotNull);
      final decoded = jsonDecode(rawStored!) as Map<String, dynamic>;
      expect(decoded['retryCount'], equals(1));
    });

    test('Permanent 4xx rejection (anti-cheat anomaly) archives run and clears pending queue', () async {
      final mockClient = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': 'ANOMALY_REJECTED',
            'detail':
                'Instantaneous speed exceeded 25 km/h for running activity',
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://test-server',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        overrideBox: testUnsyncedBox,
        overrideRejectedBox: testRejectedBox,
      );

      await syncQueue.enqueueRun(
        idempotencyKey: 'idem_anomaly_003',
        activityType: ExerciseActivityType.running.id,
        points: const [LatLng(51.5, -0.12)],
        durationSeconds: 10,
        distanceMeters: 5000.0,
        clientPreviewArea: 0.0,
        clientPreviewXp: 0,
        autoSync: false,
      );

      final success = await syncQueue.syncPendingRuns();

      expect(
        success,
        isTrue,
        reason: 'Permanent failures are removed from queue without blocking',
      );
      expect(
        testUnsyncedBox.isEmpty,
        isTrue,
        reason: 'Permanently rejected run must not loop in retry queue',
      );
      expect(
        testRejectedBox.length,
        equals(1),
        reason: 'Permanently rejected run is archived for runner review',
      );
      expect(syncQueue.lastRejectionNotifier.value, isNotNull);
      expect(
        syncQueue.lastRejectionNotifier.value!.humanReason,
        contains('GPS anomaly detected'),
      );
    });
  });
}
