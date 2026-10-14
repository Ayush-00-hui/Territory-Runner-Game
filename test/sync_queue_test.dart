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

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_sync_test');
    Hive.init(tempDir.path);
    testBox = await Hive.openBox<String>('test_unsynced_runs');
  });

  tearDown(() async {
    if (testBox.isOpen) {
      await testBox.close();
    }
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SyncQueueService Tests', () {
    test('enqueueRun saves run in persistent Hive queue and updates count', () async {
      final mockClient = MockClient((req) async {
        return http.Response('{"status":"accepted"}', 201);
      });
      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mock', maxRetries: 0);
      final syncQueue = SyncQueueService(apiClient: apiClient, overrideBox: testBox);

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
    });

    test('syncPendingRuns successfully uploads run and clears queue', () async {
      int submitCalls = 0;
      final mockClient = MockClient((req) async {
        submitCalls++;
        return http.Response(
          '{"run_id":"run_synced","idempotency_key":"test_sync_002","player_total_area_sqm":5000.0}',
          201,
        );
      });
      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mock', maxRetries: 0);
      final syncQueue = SyncQueueService(apiClient: apiClient, overrideBox: testBox);

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
      expect(testBox.isEmpty, isTrue, reason: 'Synced runs must be removed from queue');
      expect(syncQueue.statusNotifier.value, equals(SyncStatus.synced));
      expect(syncQueue.unsettledCountNotifier.value, equals(0));
    });

    test('Network failure retains run in queue and sets SyncStatus.offline', () async {
      final mockClient = MockClient((req) async {
        // Simulates connection failure
        throw const SocketException('No route to host');
      });
      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://mock', maxRetries: 0);
      final syncQueue = SyncQueueService(apiClient: apiClient, overrideBox: testBox);

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
      expect(testBox.containsKey('test_offline_003'), isTrue, reason: 'Offline runs must remain preserved in queue');
      expect(syncQueue.statusNotifier.value, equals(SyncStatus.offline));
      expect(syncQueue.unsettledCountNotifier.value, equals(1));
    });
  });
}
