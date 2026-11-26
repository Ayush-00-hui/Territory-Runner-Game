import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/map/controllers/map_run_controller.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/gps_distance_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  group('Phase S: Memory Growth Benchmark over Long Simulated Run', () {
    test('Simulate 5,000 GPS fixes (~83 min run) and measure memory / coordinate growth', () async {
      final filter = GpsDistanceFilter();
      final controller = MapRunController(distanceFilter: filter);

      final initialRss = ProcessInfo.currentRss;
      // ignore: avoid_print
      print(
        'Initial Process RSS: ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      final startTime = DateTime(2026, 11, 26, 6, 0, 0);
      double currentLat = 51.5074;
      double currentLng = -0.1278;

      controller.startRun();

      // Simulate 5,000 continuous GPS fixes at 1 Hz (5,000 seconds = ~83.3 min)
      // Moving at steady 2.8 m/s (~10 km/h) around a 400m track loop
      const stepMeters = 2.8;
      const meterToLat = 1.0 / 111320.0;

      for (int i = 0; i < 5000; i++) {
        final headingRad = (i * 0.02) % (2 * math.pi);
        currentLat += math.cos(headingRad) * stepMeters * meterToLat;
        currentLng += math.sin(headingRad) * stepMeters * meterToLat;

        final pos = Position(
          latitude: currentLat,
          longitude: currentLng,
          timestamp: startTime.add(Duration(seconds: i)),
          accuracy: 4.0,
          altitude: 20.0,
          altitudeAccuracy: 1.0,
          heading: headingRad * (180.0 / math.pi),
          headingAccuracy: 2.0,
          speed: 2.8,
          speedAccuracy: 0.2,
          isMocked: false,
        );

        controller.processPosition(pos);
      }

      final finalRss = ProcessInfo.currentRss;
      final rssDeltaMb = (finalRss - initialRss) / (1024 * 1024);
      // ignore: avoid_print
      print(
        'Final Process RSS: ${(finalRss / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
      // ignore: avoid_print
      print(
        'Memory Growth Delta: ${rssDeltaMb.toStringAsFixed(2)} MB over 5,000 GPS fixes',
      );

      // Assertions:
      expect(controller.runCoordinates.length, greaterThan(1000));
      expect(controller.runDistanceKm, greaterThan(1.0));
      expect(
        rssDeltaMb,
        lessThan(50.0),
        reason: 'Memory growth must be bounded without unbounded leak',
      );

      controller.stopRun();
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    });
  });
}
