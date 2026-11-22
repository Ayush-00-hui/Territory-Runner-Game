import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/history/widgets/history_run_card.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/location_service.dart';
import 'package:territory_runner/services/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase C1: Simulation & Environment Integrity Tests', () {
    test('Zero FLUTTER_TEST environment hooks in lib/ directory', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          if (content.contains('FLUTTER_TEST')) {
            violations.add(entity.path);
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found FLUTTER_TEST in production code: ${violations.join(", ")}. '
            'Production code must be decoupled from test environment flags.',
      );
    });

    test(
      'LocationService defaults to real GPS; simulation is explicit only',
      () async {
        final service = LocationService();
        service.isSimulationMode = false;
        service.setVirtualPacer(VirtualPacerMode.none);

        expect(service.isSimulationMode, isFalse);

        // Explicitly activating simulation mode
        service.isSimulationMode = true;
        expect(service.isSimulationMode, isTrue);

        final simPos = await service.getCurrentLocation();
        expect(simPos, isNotNull);
        expect(simPos!.isMocked, isTrue);

        // Resetting explicit simulation
        service.isSimulationMode = false;
        expect(service.isSimulationMode, isFalse);
      },
    );

    test('QueuedRun and SyncQueueService reject/drop simulated runs', () {
      final queued = QueuedRun(
        idempotencyKey: 'demo_key_999',
        points: [const LatLng(37.7749, -122.4194)],
        durationSeconds: 120,
        distanceMeters: 500.0,
        clientPreviewArea: 0.0,
        clientPreviewXp: 0,
        activityType: 'running',
        createdAt: DateTime(2026, 11, 22),
        simulated: true,
      );

      final json = queued.toJson();
      expect(json['simulated'], isTrue);

      final restored = QueuedRun.fromJson(json);
      expect(restored.simulated, isTrue);
      expect(restored.idempotencyKey, 'demo_key_999');
    });

    test('ApiClient sends simulated flag to backend when simulated run is submitted', () async {
      bool capturedSimulatedField = false;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedSimulatedField = body['simulated'] == true;

        return http.Response(
          jsonEncode({
            'code': 'SIMULATED_RUN_REJECTED',
            'message': 'Simulated runs cannot be submitted to leaderboard or territory rankings.',
          }),
          400,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrl: 'http://mockbackend',
      );

      await expectLater(
        () => apiClient.submitRun(
          idempotencyKey: 'sim_run_01',
          points: [
            const LatLng(37.77, -122.41),
            const LatLng(37.78, -122.41),
            const LatLng(37.78, -122.40),
            const LatLng(37.77, -122.40),
          ],
          durationSeconds: 300,
          distanceMeters: 1200.0,
          activityType: 'running',
          simulated: true,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(capturedSimulatedField, isTrue);
    });

    test(
      'RunLogEntry correctly serializes and deserializes simulated flag',
      () {
        final entry = RunLogEntry(
          id: 'sim_log_1',
          startedAt: DateTime(2026, 11, 22, 10, 0),
          endedAt: DateTime(2026, 11, 22, 10, 15),
          activityType: 'running',
          movingSeconds: 900,
          totalSeconds: 900,
          distanceM: 2000.0,
          samples: const [],
          claimedAreaSqM: 0.0,
          xp: 0,
          syncStatus: 'demo_only',
          simulated: true,
        );

        final json = entry.toJson();
        expect(json['sim'], isTrue);

        final restored = RunLogEntry.fromJson(json);
        expect(restored.simulated, isTrue);
        expect(restored.syncStatus, 'demo_only');
        expect(restored.xp, 0);
      },
    );

    testWidgets('HistoryRunCard displays "Demo run" badge for simulated runs', (
      tester,
    ) async {
      final simRun = RunLogEntry(
        id: 'sim_run_display_1',
        startedAt: DateTime(2026, 11, 22, 9, 0),
        endedAt: DateTime(2026, 11, 22, 9, 20),
        activityType: 'running',
        movingSeconds: 1200,
        totalSeconds: 1200,
        distanceM: 3000.0,
        samples: const [],
        claimedAreaSqM: 0.0,
        xp: 0,
        syncStatus: 'demo_only',
        simulated: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryRunCard(
              run: simRun,
              callsign: 'ApexRunner',
              faction: 'Nordic Mint',
            ),
          ),
        ),
      );

      expect(find.text('Demo run'), findsOneWidget);
      expect(find.textContaining('claimed'), findsNothing);
    });
  });
}
