import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/services/exploration_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('exploration_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ExplorationService Fog of War Tests', () {
    test('Coordinate discretization produces consistent grid cell IDs', () {
      const coord1 = LatLng(51.50001, -0.12001);
      const coord2 = LatLng(51.50003, -0.12003); // within same ~100m box
      const coordFar = LatLng(51.51000, -0.12000); // 1.1km north

      final key1 = ExplorationService.getCellKey(
        coord1.latitude,
        coord1.longitude,
      );
      final key2 = ExplorationService.getCellKey(
        coord2.latitude,
        coord2.longitude,
      );
      final keyFar = ExplorationService.getCellKey(
        coordFar.latitude,
        coordFar.longitude,
      );

      expect(key1, equals(key2));
      expect(key1, isNot(equals(keyFar)));
    });

    test('recordVisitedPoints records cells into local storage', () async {
      final service = ExplorationService();

      final runPoints = [
        const LatLng(51.5100, -0.1200),
        const LatLng(51.5120, -0.1200),
      ];

      final recordedCount = await service.recordVisitedPoints(runPoints);
      expect(recordedCount, greaterThanOrEqualTo(2));

      final total = await service.getTotalExploredCells();
      expect(total, greaterThanOrEqualTo(2));
    });

    test('Exploration percentage calculation within radius', () async {
      final service = ExplorationService();
      const center = LatLng(51.5000, -0.1200);

      final points = List.generate(
        10,
        (i) => LatLng(51.5000 + (i * 0.001), -0.1200),
      );
      await service.recordVisitedPoints(points);

      final percentage = await service.getAreaExplorationPercentage(
        center: center,
        radiusKm: 2.0,
      );

      expect(percentage, greaterThan(0.0));
      expect(percentage, lessThanOrEqualTo(100.0));
    });
  });
}
