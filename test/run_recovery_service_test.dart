import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/services/run_recovery_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_recovery_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(RunRecoveryService.boxName);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('RunRecoveryService Tests', () {
    test(
      'saveActiveRun persists snapshot and hasRecoverableRun returns true',
      () async {
        final service = RunRecoveryService();
        await service.init();

        expect(service.hasRecoverableRun(), isFalse);

        final now = DateTime.now().toUtc();
        final pos1 = Position(
          latitude: 51.5000,
          longitude: -0.1200,
          timestamp: now,
          accuracy: 4.0,
          altitude: 15.0,
          altitudeAccuracy: 1.0,
          heading: 90.0,
          headingAccuracy: 2.0,
          speed: 2.8,
          speedAccuracy: 0.2,
          isMocked: false,
        );
        final pos2 = Position(
          latitude: 51.5010,
          longitude: -0.1210,
          timestamp: now.add(const Duration(minutes: 1)),
          accuracy: 4.5,
          altitude: 16.0,
          altitudeAccuracy: 1.0,
          heading: 95.0,
          headingAccuracy: 2.0,
          speed: 3.1,
          speedAccuracy: 0.2,
          isMocked: false,
        );

        await service.saveActiveRun(
          positions: [pos1, pos2],
          coordinates: [
            const LatLng(51.5000, -0.1200),
            const LatLng(51.5010, -0.1210),
          ],
          startTime: now,
          elapsedDurationSeconds: 180,
          movingDurationSeconds: 175,
          distanceKm: 0.45,
          territoriesClaimed: 2,
          accumulatedPreviewArea: 6500.0,
          accumulatedPreviewXp: 325,
        );

        expect(service.hasRecoverableRun(), isTrue);

        final snapshot = service.getRecoverableRun();
        expect(snapshot, isNotNull);
        expect(snapshot!.distanceKm, closeTo(0.45, 0.001));
        expect(snapshot.elapsedDurationSeconds, equals(180));
        expect(snapshot.movingDurationSeconds, equals(175));
        expect(snapshot.territoriesClaimed, equals(2));
        expect(snapshot.coordinates.length, equals(2));
        expect(snapshot.positions.length, equals(2));
        expect(snapshot.positions.first.latitude, equals(51.5000));
        expect(snapshot.accumulatedPreviewArea, equals(6500.0));
        expect(snapshot.accumulatedPreviewXp, equals(325));
      },
    );

    test('clearRecovery deletes active snapshot and hasRecoverableRun returns false', () async {
      final service = RunRecoveryService();
      await service.init();

      final now = DateTime.now().toUtc();
      await service.saveActiveRun(
        positions: [
          Position(
            latitude: 37.77,
            longitude: -122.41,
            timestamp: now,
            accuracy: 3.0,
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 2.5,
            speedAccuracy: 0.1,
            isMocked: false,
          ),
          Position(
            latitude: 37.78,
            longitude: -122.42,
            timestamp: now.add(const Duration(seconds: 30)),
            accuracy: 3.0,
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 2.5,
            speedAccuracy: 0.1,
            isMocked: false,
          ),
        ],
        coordinates: [
          const LatLng(37.77, -122.41),
          const LatLng(37.78, -122.42),
        ],
        startTime: now,
        elapsedDurationSeconds: 60,
        movingDurationSeconds: 60,
        distanceKm: 0.2,
        territoriesClaimed: 0,
        accumulatedPreviewArea: 0.0,
        accumulatedPreviewXp: 0,
      );

      expect(service.hasRecoverableRun(), isTrue);

      await service.clearRecovery();
      expect(service.hasRecoverableRun(), isFalse);
      expect(service.getRecoverableRun(), isNull);
    });
  });
}
