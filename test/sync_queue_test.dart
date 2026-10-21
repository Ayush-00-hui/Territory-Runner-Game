import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/sync_queue.dart';

void main() {
  late Directory tempDir;
  late Box<String> testBox;
  late Box<String> testRejectedBox;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_sync_test');
    Hive.init(tempDir.path);
    testBox = await Hive.openBox<String>('test_unsynced_runs');
    testRejectedBox = await Hive.openBox<String>('test_rejected_runs');
  });

  tearDown(() async {
    if (testBox.isOpen) {
      await testBox.close();
    }
    if (testRejectedBox.isOpen) {
      await testRejectedBox.close();
    }
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SyncQueueService Tests', () {
    test(
      'enqueueRun saves run in persistent Hive queue and updates count',
      () async {
        final mockClient = MockClient((req) async {
          return http.Response('{"status":"accepted"}', 201);
        });
        final apiClient = ApiClient(
          httpClient: mockClient,
          baseUrl: 'http://mock',
          maxRetries: 0,
        );
        final syncQueue = SyncQueueService(
          apiClient: apiClient,
          overrideBox: testBox,
          overrideRejectedBox: testRejectedBox,
        );

        final run = await syncQueue.enqueueRun(
          idempotencyKey: 'test_enqueue_001',
          points: [const LatLng(51.5, -0.12), const LatLng(51.501, -0.12)],
          durationSeconds: 120,
          distanceMeters: 200.0,
          clientPreviewArea: 1500.0,
          clientPreviewXp: 100,
          autoSync: false,
        );

        expect(run.idempotencyKey, equals('test_enqueue_001'));
        expect(testBox.containsKey('test_enqueue_001'), isTrue);
        expect(syncQueue.unsettledCountNotifier.value, equals(1));
      },
    );

    test('syncPendingRuns successfully uploads run and clears queue', () async {
      int submitCalls = 0;
      final mockClient = MockClient((req) async {
        submitCalls++;
        return http.Response(
          '{"run_id":"run_synced","idempotency_key":"test_sync_002","player_total_area_sqm":5000.0}',
          201,
        );
      });
      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mock',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        overrideBox: testBox,
        overrideRejectedBox: testRejectedBox,
      );

      await syncQueue.enqueueRun(
        idempotencyKey: 'test_sync_002',
        points: [const LatLng(51.5, -0.12)],
        durationSeconds: 60,
        distanceMeters: 100.0,
        clientPreviewArea: 0.0,
        clientPreviewXp: 0,
        autoSync: false,
      );

      final success = await syncQueue.syncPendingRuns();

      expect(success, isTrue);
      expect(submitCalls, equals(1));
      expect(
        testBox.isEmpty,
        isTrue,
        reason: 'Synced runs must be removed from queue',
      );
      expect(syncQueue.statusNotifier.value, equals(SyncStatus.synced));
      expect(syncQueue.unsettledCountNotifier.value, equals(0));
    });

    test(
      'Network failure retains run in queue and sets SyncStatus.offline',
      () async {
        final mockClient = MockClient((req) async {
          // Simulates connection failure
          throw const SocketException('No route to host');
        });
        final apiClient = ApiClient(
          httpClient: mockClient,
          baseUrl: 'http://mock',
          maxRetries: 0,
        );
        final syncQueue = SyncQueueService(
          apiClient: apiClient,
          overrideBox: testBox,
          overrideRejectedBox: testRejectedBox,
        );

        await syncQueue.enqueueRun(
          idempotencyKey: 'test_offline_003',
          points: [const LatLng(51.5, -0.12)],
          durationSeconds: 60,
          distanceMeters: 100.0,
          clientPreviewArea: 0.0,
          clientPreviewXp: 0,
          autoSync: false,
        );

        final success = await syncQueue.syncPendingRuns();

        expect(success, isFalse);
        expect(
          testBox.containsKey('test_offline_003'),
          isTrue,
          reason: 'Offline runs must remain preserved in queue',
        );
        expect(syncQueue.statusNotifier.value, equals(SyncStatus.offline));
        expect(syncQueue.unsettledCountNotifier.value, equals(1));
      },
    );

    test(
      'isPermanentFailure distinguishes permanent 4xx from transient errors',
      () {
        expect(
          SyncQueueService.isPermanentFailure(
            const ApiException(
              statusCode: 400,
              code: 'INVALID_LOOP',
              message: '',
            ),
          ),
          isTrue,
        );
        expect(
          SyncQueueService.isPermanentFailure(
            const ApiException(
              statusCode: 422,
              code: 'ANOMALY_REJECTED',
              message: '',
            ),
          ),
          isTrue,
        );
        expect(
          SyncQueueService.isPermanentFailure(
            const ApiException(statusCode: 404, code: 'NOT_FOUND', message: ''),
          ),
          isTrue,
        );
        expect(
          SyncQueueService.isPermanentFailure(
            const ApiException(statusCode: 408, code: 'TIMEOUT', message: ''),
          ),
          isFalse,
        );
        expect(
          SyncQueueService.isPermanentFailure(
            const ApiException(
              statusCode: 429,
              code: 'RATE_LIMIT',
              message: '',
            ),
          ),
          isFalse,
        );
        expect(
          SyncQueueService.isPermanentFailure(
            const ApiException(
              statusCode: 500,
              code: 'SERVER_ERROR',
              message: '',
            ),
          ),
          isFalse,
        );
        expect(
          SyncQueueService.isPermanentFailure(const SocketException('fail')),
          isFalse,
        );
      },
    );

    test('Permanent 4xx rejection (INVALID_LOOP) archives run, clears it from queue, and sets lastRejectionNotifier', () async {
      final mockClient = MockClient((req) async {
        return http.Response(
          '{"error":"INVALID_LOOP","detail":"Loop too large: 6000000 m² > 5000000 m² maximum limit"}',
          400,
        );
      });
      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mock',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        overrideBox: testBox,
        overrideRejectedBox: testRejectedBox,
      );

      await syncQueue.enqueueRun(
        idempotencyKey: 'test_rejected_004',
        points: [const LatLng(51.5, -0.12)],
        durationSeconds: 120,
        distanceMeters: 500.0,
        clientPreviewArea: 6000000.0,
        clientPreviewXp: 500,
        autoSync: false,
      );

      final success = await syncQueue.syncPendingRuns();

      expect(
        success,
        isTrue,
        reason: 'Permanent failures are removed from queue, allowing queue to settle',
      );
      expect(
        testBox.isEmpty,
        isTrue,
        reason: 'Permanently rejected run must not stay in retry queue',
      );
      expect(testRejectedBox.containsKey('test_rejected_004'), isTrue);

      final rejected = syncQueue.lastRejectionNotifier.value;
      expect(rejected, isNotNull);
      expect(rejected!.code, equals('INVALID_LOOP'));
      expect(rejected.humanReason, contains('Loop too large'));

      final allRejected = await syncQueue.getRejectedRuns();
      expect(allRejected.length, equals(1));
      expect(allRejected.first.run.idempotencyKey, equals('test_rejected_004'));
    });

    test(
      'Permanent rejection does not block subsequent valid runs in FIFO queue',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((req) async {
          requestCount++;
          if (req.body.contains('bad_run')) {
            return http.Response(
              '{"error":"ANOMALY_REJECTED","detail":"GPS anomaly detected: speed exceeds 45 km/h"}',
              422,
            );
          }
          return http.Response(
            '{"run_id":"good_run_id","idempotency_key":"good_run","player_total_area_sqm":1000.0}',
            201,
          );
        });
        final apiClient = ApiClient(
          httpClient: mockClient,
          baseUrl: 'http://mock',
          maxRetries: 0,
        );
        final syncQueue = SyncQueueService(
          apiClient: apiClient,
          overrideBox: testBox,
          overrideRejectedBox: testRejectedBox,
        );

        await syncQueue.enqueueRun(
          idempotencyKey: 'bad_run',
          points: [const LatLng(51.5, -0.12)],
          durationSeconds: 10,
          distanceMeters: 1000.0,
          clientPreviewArea: 0.0,
          clientPreviewXp: 0,
          autoSync: false,
        );

        await syncQueue.enqueueRun(
          idempotencyKey: 'good_run',
          points: [const LatLng(51.5, -0.12)],
          durationSeconds: 60,
          distanceMeters: 200.0,
          clientPreviewArea: 1000.0,
          clientPreviewXp: 100,
          autoSync: false,
        );

        expect(testBox.length, equals(2));

        final success = await syncQueue.syncPendingRuns();

        expect(success, isTrue);
        expect(requestCount, equals(2));
        expect(
          testBox.isEmpty,
          isTrue,
          reason: 'Both the rejected and the good run should be removed from pending queue',
        );
        expect(testRejectedBox.containsKey('bad_run'), isTrue);
        expect(syncQueue.statusNotifier.value, equals(SyncStatus.synced));
        expect(
          syncQueue.lastRejectionNotifier.value?.code,
          equals('ANOMALY_REJECTED'),
        );
        expect(
          syncQueue.lastRejectionNotifier.value?.humanReason,
          contains('GPS anomaly detected'),
        );
      },
    );

    test('Server reconciliation notifies user when server claimed area differs from client preview', () async {
      final mockClient = MockClient((req) async {
        return http.Response(
          '{"run_id":"run_bonus","idempotency_key":"test_bonus","area_claimed_sqm":1250.0,"player_total_area_sqm":5000.0}',
          201,
        );
      });
      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mock',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        overrideBox: testBox,
        overrideRejectedBox: testRejectedBox,
      );

      await syncQueue.enqueueRun(
        idempotencyKey: 'test_bonus',
        points: [const LatLng(51.5, -0.12)],
        durationSeconds: 60,
        distanceMeters: 200.0,
        clientPreviewArea: 1000.0,
        clientPreviewXp: 100,
        autoSync: false,
      );

      final success = await syncQueue.syncPendingRuns();

      expect(success, isTrue);
      expect(syncQueue.reconciliationToastNotifier.value, isNotNull);
      expect(
        syncQueue.reconciliationToastNotifier.value,
        contains('+250.0 m² bonus'),
      );
    });

    test('Server reconciliation notifies user when server area is reduced due to overlap', () async {
      final mockClient = MockClient((req) async {
        return http.Response(
          '{"run_id":"run_deduct","idempotency_key":"test_deduct","area_claimed_sqm":850.0,"player_total_area_sqm":5000.0}',
          201,
        );
      });
      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mock',
        maxRetries: 0,
      );
      final syncQueue = SyncQueueService(
        apiClient: apiClient,
        overrideBox: testBox,
        overrideRejectedBox: testRejectedBox,
      );

      await syncQueue.enqueueRun(
        idempotencyKey: 'test_deduct',
        points: [const LatLng(51.5, -0.12)],
        durationSeconds: 60,
        distanceMeters: 200.0,
        clientPreviewArea: 1000.0,
        clientPreviewXp: 100,
        autoSync: false,
      );

      final success = await syncQueue.syncPendingRuns();

      expect(success, isTrue);
      expect(syncQueue.reconciliationToastNotifier.value, isNotNull);
      expect(
        syncQueue.reconciliationToastNotifier.value,
        contains('Server adjusted -150.0 m²'),
      );
    });
  });
}
