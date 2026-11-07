import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/services/speed_smoothing_service.dart';

void main() {
  group('SpeedSmoothingPipeline Tests', () {
    late SpeedSmoothingPipeline pipeline;

    setUp(() {
      pipeline = SpeedSmoothingPipeline();
    });

    Position createPos({
      required double latitude,
      required double longitude,
      required double speedMps,
      required double accuracy,
      required DateTime timestamp,
    }) {
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        altitude: 100.0,
        altitudeAccuracy: 5.0,
        accuracy: accuracy,
        heading: 0.0,
        headingAccuracy: 5.0,
        speed: speedMps,
        speedAccuracy: 1.0,
      );
    }

    test('Doppler speed smoothing reduces jitter over rolling window', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

      // Simulate a runner running at ~10 km/h (~2.78 m/s) with Doppler jitter:
      // 2.5 m/s (9.0 km/h), 3.1 m/s (11.16 km/h), 2.7 m/s (9.72 km/h), 2.8 m/s (10.08 km/h)
      final speedsMps = [2.5, 3.1, 2.7, 2.8];
      double lastSmoothed = 0.0;

      for (int i = 0; i < speedsMps.length; i++) {
        final pos = createPos(
          latitude: 12.9716 + (i * 0.00002),
          longitude: 77.5946,
          speedMps: speedsMps[i],
          accuracy: 5.0,
          timestamp: baseTime.add(Duration(seconds: i)),
        );
        lastSmoothed = pipeline.processPosition(pos, isAutoPaused: false);
      }

      // Final smoothed speed should be smoothed near 10.0 km/h (+- 0.5 km/h)
      expect(lastSmoothed, closeTo(10.0, 0.6));
    });

    test(
      'Falls back to geodesic displacement when Doppler speed is 0 or missing',
      () {
        final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

        // First fix: stationary reference
        pipeline.processPosition(
          createPos(
            latitude: 12.971600,
            longitude: 77.594600,
            speedMps: 0.0, // No Doppler speed
            accuracy: 5.0,
            timestamp: baseTime,
          ),
          isAutoPaused: false,
        );

        // Second fix 1 second later: moved ~2.78 meters north (approx 10 km/h)
        // 1 degree latitude ~= 111,000 meters. 2.78m ~= 0.000025 deg.
        final pos2 = createPos(
          latitude: 12.971625,
          longitude: 77.594600,
          speedMps: 0.0, // No Doppler speed
          accuracy: 5.0,
          timestamp: baseTime.add(const Duration(seconds: 1)),
        );

        final speed = pipeline.processPosition(pos2, isAutoPaused: false);
        // Measured displacement ~2.77 meters in 1 second = ~10.0 km/h
        expect(speed, inInclusiveRange(9.0, 11.0));
      },
    );

    test('Rejects poor accuracy GPS fixes (> 30m) without updating speed', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

      // Valid fix at 12 km/h (3.33 m/s)
      final validPos = createPos(
        latitude: 12.971600,
        longitude: 77.594600,
        speedMps: 3.33,
        accuracy: 8.0,
        timestamp: baseTime,
      );
      final initialSpeed = pipeline.processPosition(
        validPos,
        isAutoPaused: false,
      );
      expect(initialSpeed, closeTo(12.0, 0.1));

      // Degraded fix with 45m accuracy (e.g., indoor multipath jump at 40 km/h)
      final degradedPos = createPos(
        latitude: 12.972000,
        longitude: 77.594600,
        speedMps: 11.11, // 40 km/h
        accuracy: 45.0, // > 30m threshold
        timestamp: baseTime.add(const Duration(seconds: 1)),
      );
      final rejectedSpeed = pipeline.processPosition(
        degradedPos,
        isAutoPaused: false,
      );

      // Speed must remain untouched at initial valid speed
      expect(rejectedSpeed, equals(initialSpeed));
    });

    test('Auto-pause immediately forces speed to 0.0 and clears buffer', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

      // Running at 12 km/h
      pipeline.processPosition(
        createPos(
          latitude: 12.971600,
          longitude: 77.594600,
          speedMps: 3.33,
          accuracy: 5.0,
          timestamp: baseTime,
        ),
        isAutoPaused: false,
      );

      // Auto-pause kicks in (stoplight)
      final pausedSpeed = pipeline.processPosition(
        createPos(
          latitude: 12.971600,
          longitude: 77.594600,
          speedMps: 0.1,
          accuracy: 5.0,
          timestamp: baseTime.add(const Duration(seconds: 2)),
        ),
        isAutoPaused: true,
      );

      expect(pausedSpeed, equals(0.0));
      expect(pipeline.currentSmoothedSpeedKmh, equals(0.0));
    });
  });
}
