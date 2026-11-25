import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/map/controllers/map_run_controller.dart';
import 'package:territory_runner/services/gps_distance_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase S: Memory Growth Benchmark over Long Simulated Run', () {
    test('Simulate 5,000 GPS fixes (~83 min run) and measure memory / coordinate growth', () {
      final filter = GpsDistanceFilter();
      final controller = MapRunController(distanceFilter: filter);

      // Force garbage collection / record initial baseline RSS
      final initialRss = ProcessInfo.currentRss;
      print('Initial Process RSS: ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB');

      final startTime = DateTime(2026, 11, 26, 6, 0, 0);
      const startLat = 51.5074;
      const startLng = -0.1278;

      controller.startRun();

      // Simulate 5,000 GPS fixes (1 sample per second = 5,000 seconds = ~83.3 minutes)
      // Moving in an expanding spiral / multi-loop path at 3.0 m/s (~10.8 km/h)
      for (int i = 0; i < 5000; i++) {
        final angle = (i * 0.05) % (2 * 3.1415926535);
        final radius = 0.0005 + (i * 0.0000005);
        final lat = startLat + radius * (angle / 6.28);
        final lng = startLng + radius * (angle / 6.28);

        final pos = Position(
          latitude: lat,
          longitude: lng,
          timestamp: startTime.add(Duration(seconds: i)),
          accuracy: 4.0,
          altitude: 20.0,
          altitudeAccuracy: 1.0,
          heading: 90.0,
          headingAccuracy: 2.0,
          speed: 3.0,
          speedAccuracy: 0.2,
          isMocked: false,
        );

        controller.processPosition(pos);
      }

      final finalRss = ProcessInfo.currentRss;
      final rssDeltaMb = (finalRss - initialRss) / (1024 * 1024);
      print('Final Process RSS: ${(finalRss / (1024 * 1024)).toStringAsFixed(2)} MB');
      print('Memory Growth Delta: ${rssDeltaMb.toStringAsFixed(2)} MB over 5,000 GPS fixes');

      // Assertions:
      // 1. Controller accumulated coordinates properly
      expect(controller.runCoordinates.length, greaterThan(1000));
      expect(controller.runDistanceKm, greaterThan(1.0));

      // 2. Memory growth must stay well under safety threshold (< 50 MB growth for 5,000 points)
      expect(rssDeltaMb, lessThan(50.0), reason: 'Memory growth must be bounded without unbounded leak');

      controller.stopRun();
      controller.dispose();
    });
  });
}
