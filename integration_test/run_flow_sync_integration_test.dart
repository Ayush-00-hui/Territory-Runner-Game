import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/map/map_screen.dart';
import 'package:territory_runner/features/map/widgets/map_run_finisher.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/battery_saver_service.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/services/hive_encryption_service.dart';
import 'package:territory_runner/services/location_service.dart';
import 'package:territory_runner/services/run_recovery_service.dart';
import 'package:territory_runner/services/sync_queue.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Territory> territoryBox;
  late Box<RunnerProfile> profileBox;
  late Box<String> syncBox;
  late Box<String> rejectedBox;
  late Box<String> recoveryBox;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('integration_test_hive_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }

    final encryptionService = HiveEncryptionService();
    final syncCipher = await encryptionService.getCipherForBox('sync_box');
    final recoveryCipher = await encryptionService.getCipherForBox('rec_box');

    territoryBox = await Hive.openBox<Territory>('test_territories');
    profileBox = await Hive.openBox<RunnerProfile>('test_profile');
    syncBox = await Hive.openBox<String>(
      'sync_box',
      encryptionCipher: syncCipher,
    );
    rejectedBox = await Hive.openBox<String>('test_rejected');
    recoveryBox = await Hive.openBox<String>(
      'rec_box',
      encryptionCipher: recoveryCipher,
    );

    await profileBox.put(
      'profile',
      RunnerProfile(
        id: 'runner_integration_01',
        username: 'ApexRunner',
        faction: 'Cyber Vanguard',
        totalDistanceKm: 12.0,
        xp: 600,
        level: 3,
      ),
    );
  });

  tearDownAll(() async {
    await territoryBox.close();
    await profileBox.close();
    await syncBox.close();
    await rejectedBox.close();
    await recoveryBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Position createPosition(double lat, double lng, {double speed = 3.5}) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 4.0,
      altitude: 15.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: speed,
      speedAccuracy: 0.5,
    );
  }

  testWidgets(
    'End-to-End Run Flow: Start run -> Record points -> Offline finish -> Encrypted Queue -> Reconnect Sync -> Summary Sheet',
    (tester) async {
      bool isNetworkOnline = false;
      int serverUploadCalls = 0;

      final mockHttpClient = MockClient((req) async {
        if (!isNetworkOnline) {
          throw const SocketException('Connection failed (Runner is offline)');
        }
        if (req.url.path.contains('/runs') || req.url.path.contains('submit')) {
          serverUploadCalls++;
          return http.Response(
            '{"run_id":"run_e2e_verified","status":"accepted","xp_earned":120}',
            201,
          );
        }
        return http.Response('{"status":"ok"}', 200);
      });

      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        baseUrl: 'https://api.territoryrunner.mock/v1',
        maxRetries: 0,
      );

      final territoryService = TerritoryService();
      final syncQueueService = SyncQueueService(
        apiClient: apiClient,
        territoryService: territoryService,
        overrideBox: syncBox,
        overrideRejectedBox: rejectedBox,
      );
      final recoveryService = RunRecoveryService(overrideBox: recoveryBox);
      final runController = MapRunController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: apiClient),
            Provider<TerritoryService>.value(value: territoryService),
            Provider<SyncQueueService>.value(value: syncQueueService),
            Provider<RunRecoveryService>.value(value: recoveryService),
            Provider<LocationService>.value(value: LocationService()),
            Provider<BatterySaverService>.value(value: BatterySaverService()),
            Provider<AppPreferences>.value(value: AppPreferences()),
            Provider<FirebaseService>.value(value: FirebaseService()),
            ChangeNotifierProvider<MapRunController>.value(
              value: runController,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MapScreen())),
        ),
      );

      await tester.pumpAndSettle();

      // =======================================================================
      // STEP 1: START RUN
      // =======================================================================
      expect(runController.isRunActive, isFalse);
      expect(MapScreen.isRunActiveNotifier.value, isFalse);

      runController.startRun();
      await tester.pumpAndSettle();

      expect(runController.isRunActive, isTrue);
      expect(MapScreen.isRunActiveNotifier.value, isTrue);

      // =======================================================================
      // STEP 2: RECORD POINTS (GPS Loop Trajectory)
      // =======================================================================
      const double originLat = 51.5074;
      const double originLng = -0.1278;

      final waypoints = [
        createPosition(originLat, originLng),
        createPosition(originLat + 0.0010, originLng),
        createPosition(originLat + 0.0010, originLng + 0.0015),
        createPosition(originLat, originLng + 0.0015),
        createPosition(originLat, originLng), // Closed loop
      ];

      for (final pt in waypoints) {
        runController.processPosition(pt);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      expect(runController.runCoordinates.length, equals(waypoints.length));
      expect(
        runController.telemetryNotifier.value.distanceKm,
        greaterThan(0.0),
      );
      expect(runController.stepCount, greaterThan(0));

      // =======================================================================
      // STEP 3: OFFLINE ENVIRONMENT & RUN FINISH
      // =======================================================================
      isNetworkOnline = false; // Runner goes into tunnel / airplane mode

      final recordedCoordinates = List<LatLng>.from(
        runController.runCoordinates,
      );
      final recordedDistance = runController.telemetryNotifier.value.distanceKm;
      expect(recordedCoordinates.length, equals(waypoints.length));
      expect(recordedDistance, greaterThan(0.0));

      final context = tester.element(find.byType(MapScreen));
      handleFinishRun(
        context: context,
        controller: runController,
        onTerritoriesUpdated: () {},
      );

      await tester.pumpAndSettle();

      expect(runController.isRunActive, isFalse);
      expect(MapScreen.isRunActiveNotifier.value, isFalse);

      // Verify the run was persisted into the encrypted Hive queue box while offline
      expect(syncBox.length, equals(1));
      expect(syncQueueService.unsettledCountNotifier.value, equals(1));
      expect(syncQueueService.statusNotifier.value, equals(SyncStatus.pending));
      expect(serverUploadCalls, equals(0)); // Nothing sent yet

      // =======================================================================
      // STEP 4: RECONNECT SYNC
      // =======================================================================
      isNetworkOnline = true; // Connection restored!

      await syncQueueService.syncPendingRuns();
      await tester.pumpAndSettle();

      expect(serverUploadCalls, equals(1));
      expect(syncBox.length, equals(0)); // Queue cleared
      expect(syncQueueService.unsettledCountNotifier.value, equals(0));
      expect(syncQueueService.statusNotifier.value, equals(SyncStatus.synced));

      // =======================================================================
      // STEP 5: VERIFY SUMMARY SHEET PRESENTATION & CONTENT
      // =======================================================================
      expect(find.byType(SummarySheet), findsOneWidget);
      expect(find.text('Run complete'), findsOneWidget);
      expect(find.textContaining('ApexRunner'), findsOneWidget);
      expect(find.textContaining('Cyber Vanguard'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Saved locally • Synced to cloud'), findsOneWidget);

      final doneButton = find.widgetWithText(PrimaryButton, 'Done');
      expect(doneButton, findsOneWidget);

      await tester.tap(doneButton);
      await tester.pumpAndSettle();

      expect(find.byType(SummarySheet), findsNothing);
    },
  );
}
