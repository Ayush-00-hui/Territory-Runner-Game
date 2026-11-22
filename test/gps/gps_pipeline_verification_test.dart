import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/services/gps_distance_filter.dart';

void main() {
  group('Phase C4: GPS Pipeline & Smoothing Verification Tests', () {
    test('Stationary Track: 2 minutes stationary GPS jitter produces 0.0m phantom drift', () {
      final filter = GpsDistanceFilter();
      final baseLat = 51.5074;
      final baseLng = -0.1278;
      final startTime = DateTime(2026, 11, 22, 10, 0, 0);

      double rawDistanceSumMeters = 0.0;
      double filteredDistanceSumMeters = 0.0;
      Position? prevPos;

      // Deterministic pseudo-random Gaussian jitter generator (Box-Muller)
      double gaussian(int seed) {
        final u1 = ((seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
        final u2 =
            (((seed + 1) * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
        return math.sqrt(-2.0 * math.log(math.max(1e-9, u1))) *
            math.cos(2.0 * math.pi * u2);
      }

      // 120 fixes over 2 minutes (1 fix per second)
      for (int i = 0; i < 120; i++) {
        final jitterEastMeters = gaussian(i * 2) * 3.5;
        final jitterNorthMeters = gaussian(i * 2 + 1) * 3.5;

        // Convert meter offsets to lat/lng offsets
        final latOffset = jitterNorthMeters / 111320.0;
        final lngOffset =
            jitterEastMeters / (111320.0 * math.cos(baseLat * math.pi / 180.0));

        final pos = Position(
          latitude: baseLat + latOffset,
          longitude: baseLng + lngOffset,
          timestamp: startTime.add(Duration(seconds: i)),
          accuracy: 5.0 + (gaussian(i + 50).abs() * 2.0),
          altitude: 15.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.05, // Doppler speed indicates stationary
          speedAccuracy: 0.1,
        );

        if (prevPos != null) {
          final delta = Geolocator.distanceBetween(
            prevPos.latitude,
            prevPos.longitude,
            pos.latitude,
            pos.longitude,
          );
          if (delta >= 2.0) {
            rawDistanceSumMeters += delta;
          }
        }
        prevPos = pos;

        final result = filter.processFix(
          pos,
          isAutoPaused: false,
          smoothedSpeedKmh: 0.0,
        );
        filteredDistanceSumMeters += result.distanceDeltaMeters;
      }

      // Raw distance summation suffered phantom drift (> 50m over 2 min stationary)
      expect(rawDistanceSumMeters, greaterThan(50.0));

      // Speed-gated ZUPT Kalman filter records strictly 0.0m phantom drift
      expect(filteredDistanceSumMeters, equals(0.0));
    });

    test('Straight 1000m Track: Dampens lateral jitter to match true distance within 1.5%', () {
      final filter = GpsDistanceFilter();
      final baseLat = 51.5000;
      final baseLng = -0.1200;
      final startTime = DateTime(2026, 11, 22, 10, 0, 0);

      double rawDistanceSumMeters = 0.0;
      double filteredDistanceSumMeters = 0.0;
      Position? prevPos;

      // 100 seconds at 10 m/s (36 km/h) = exactly 1000m north
      for (int i = 0; i <= 100; i++) {
        final progressMeters = i * 10.0;
        // Cross-track lateral jitter (sinusoidal + noise)
        final lateralJitterMeters = math.sin(i * 0.3) * 3.0;

        final latOffset = progressMeters / 111320.0;
        final lngOffset =
            lateralJitterMeters /
            (111320.0 * math.cos(baseLat * math.pi / 180.0));

        final pos = Position(
          latitude: baseLat + latOffset,
          longitude: baseLng + lngOffset,
          timestamp: startTime.add(Duration(seconds: i)),
          accuracy: 5.0,
          altitude: 20.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 10.0, // 36 km/h
          speedAccuracy: 0.5,
        );

        if (prevPos != null) {
          final delta = Geolocator.distanceBetween(
            prevPos.latitude,
            prevPos.longitude,
            pos.latitude,
            pos.longitude,
          );
          rawDistanceSumMeters += delta;
        }
        prevPos = pos;

        final result = filter.processFix(
          pos,
          isAutoPaused: false,
          smoothedSpeedKmh: 36.0,
        );
        filteredDistanceSumMeters += result.distanceDeltaMeters;
      }

      // Raw summation overestimates due to lateral noise
      expect(rawDistanceSumMeters, greaterThanOrEqualTo(1000.0));

      // Filtered distance tracks the ground truth (1000m) accurately
      expect(filteredDistanceSumMeters, closeTo(1000.0, 15.0)); // within 1.5%
    });

    test('Dynamic loop closure scaling adjusts based on horizontal satellite accuracy', () {
      final engine = PolygonEnclosureEngine(minClosureDistanceMeters: 35.0);

      // 1. Without accuracy: returns calibrated default 35.0m
      expect(engine.effectiveClosureDistance(), equals(35.0));
      expect(
        engine.effectiveClosureDistance(horizontalAccuracyMeters: 0.0),
        equals(35.0),
      );

      // 2. High-precision GNSS (< 5m): tightens closure radius
      expect(
        engine.effectiveClosureDistance(horizontalAccuracyMeters: 5.0),
        equals(33.0),
      );

      // 3. Standard GNSS (10m): exactly 35.0m
      expect(
        engine.effectiveClosureDistance(horizontalAccuracyMeters: 10.0),
        equals(35.0),
      );

      // 4. Urban canyon / degraded GNSS (25m): expands to 41.0m
      expect(
        engine.effectiveClosureDistance(horizontalAccuracyMeters: 25.0),
        equals(41.0),
      );

      // 5. Clamped boundaries [25.0m, 50.0m]
      expect(
        engine.effectiveClosureDistance(horizontalAccuracyMeters: 0.1),
        equals(31.04),
      );
      expect(
        engine.effectiveClosureDistance(horizontalAccuracyMeters: 90.0),
        equals(50.0),
      );
    });

    test('Auto-pause freezes distance accumulation regardless of GPS sensor jitter', () {
      final filter = GpsDistanceFilter();
      final baseLat = 51.5074;
      final baseLng = -0.1278;
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);

      // Initial fix
      filter.processFix(
        Position(
          latitude: baseLat,
          longitude: baseLng,
          timestamp: t0,
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        isAutoPaused: false,
        smoothedSpeedKmh: 0.0,
      );

      // Next fix with 8m displacement while auto-paused
      final result = filter.processFix(
        Position(
          latitude: baseLat + (8.0 / 111320.0),
          longitude: baseLng,
          timestamp: t0.add(const Duration(seconds: 1)),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 2.0,
          speedAccuracy: 0.0,
        ),
        isAutoPaused: true,
        smoothedSpeedKmh: 0.0,
      );

      expect(result.isStationary, isTrue);
      expect(result.distanceDeltaMeters, equals(0.0));
    });
  });
}
