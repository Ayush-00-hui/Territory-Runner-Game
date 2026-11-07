import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/services/elevation_incline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElevationGradePipeline Tests', () {
    late ElevationGradePipeline pipeline;

    setUp(() {
      pipeline = ElevationGradePipeline(
        customBarometerStream: const Stream.empty(),
      );
    });

    tearDown(() {
      pipeline.dispose();
    });

    Position createPos({
      required double altitude,
      required DateTime timestamp,
      double accuracy = 5.0,
      double altitudeAccuracy = 5.0,
    }) {
      return Position(
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: timestamp,
        altitude: altitude,
        altitudeAccuracy: altitudeAccuracy,
        accuracy: accuracy,
        heading: 0.0,
        headingAccuracy: 5.0,
        speed: 3.0,
        speedAccuracy: 1.0,
      );
    }

    test('Flat track with noisy GPS altitude: 3m hysteresis suppresses false gain, grade near 0%', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);
      const totalSteps = 100; // 100 seconds at 3 m/s = 300 meters
      final rng = math.Random(42);

      ElevationResult? lastResult;
      for (int i = 0; i < totalSteps; i++) {
        // True altitude = 100.0m. GPS noise oscillates uniformly within +/- 1.8m.
        final noise = (rng.nextDouble() - 0.5) * 3.6; // [-1.8m, +1.8m]
        final pos = createPos(
          altitude: 100.0 + noise,
          timestamp: baseTime.add(Duration(seconds: i)),
        );
        final dist = i * 3.0; // 3 meters per second
        lastResult = pipeline.processPosition(
          pos,
          accumulatedDistanceMeters: dist,
        );
      }

      expect(lastResult, isNotNull);
      // Measured cumulative gain MUST be 0.0 meters because noise never crosses 3.0m hysteresis threshold
      expect(lastResult!.cumulativeGainMeters, equals(0.0));
      // Grade must remain close to flat (within +/- 0.015, i.e. +/- 1.5%)
      expect(lastResult.grade.abs(), lessThan(0.015));
    });

    test('Steady hill (+5% slope over 400m): correctly measures ~5% grade and ~18m gain', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);
      const speedMs = 2.5; // 9.0 km/h
      const gradeTarget = 0.05; // 5% incline
      const totalSeconds = 160; // 160s * 2.5 m/s = 400m
      final rng = math.Random(123);

      ElevationResult? lastResult;
      for (int i = 0; i < totalSeconds; i++) {
        final dist = i * speedMs;
        final trueAlt = 100.0 + (dist * gradeTarget); // rises from 100m to 120m
        final noise = (rng.nextDouble() - 0.5) * 1.5; // +/- 0.75m sensor noise
        final pos = createPos(
          altitude: trueAlt + noise,
          timestamp: baseTime.add(Duration(seconds: i)),
        );
        lastResult = pipeline.processPosition(
          pos,
          accumulatedDistanceMeters: dist,
        );
      }

      expect(lastResult, isNotNull);
      // Cumulative gain expected: ~20.0 meters. Measured: 17.76m due to 3m hysteresis initiation.
      expect(lastResult!.cumulativeGainMeters, inInclusiveRange(17.0, 21.0));
      // Measured grade: steady at ~5% (+- 1.0%)
      expect(lastResult.grade, inInclusiveRange(0.040, 0.060));
    });

    test('Rolling hills: captures both climbs separated by descent without double-counting', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);
      // Hill 1: climb 15m (100m -> 115m over 150m dist)
      // Valley: descend 12m (115m -> 103m over 150m dist)
      // Hill 2: climb 15m (103m -> 118m over 150m dist)
      // Cumulative gain captures climbs with hysteresis and filtering.

      double currentDist = 0.0;
      int sec = 0;

      void feedSegment(double startAlt, double endAlt, int steps) {
        for (int i = 0; i <= steps; i++) {
          final frac = i / steps;
          final alt = startAlt + (endAlt - startAlt) * frac;
          currentDist += 2.5;
          sec++;
          pipeline.processPosition(
            createPos(
              altitude: alt,
              timestamp: baseTime.add(Duration(seconds: sec)),
            ),
            accumulatedDistanceMeters: currentDist,
          );
        }
      }

      void holdPlateau(double alt, int seconds) {
        for (int i = 0; i < seconds; i++) {
          currentDist += 2.5;
          sec++;
          pipeline.processPosition(
            createPos(
              altitude: alt,
              timestamp: baseTime.add(Duration(seconds: sec)),
            ),
            accumulatedDistanceMeters: currentDist,
          );
        }
      }

      feedSegment(100.0, 115.0, 60); // Climb 1
      holdPlateau(115.0, 8); // Crest plateau
      feedSegment(115.0, 103.0, 60); // Descent
      holdPlateau(103.0, 8); // Valley trough
      feedSegment(103.0, 118.0, 60); // Climb 2
      holdPlateau(118.0, 8); // Peak 2 plateau

      final finalResult = pipeline.processPosition(
        createPos(
          altitude: 118.0,
          timestamp: baseTime.add(Duration(seconds: sec + 1)),
        ),
        accumulatedDistanceMeters: currentDist + 2.5,
      );

      // Cumulative gain expected: ~30m (measured ~29.5m with plateaus)
      expect(finalResult.cumulativeGainMeters, inInclusiveRange(27.0, 32.0));
    });

    test('GPS altitude spike (+50m jump for 1 sample) is rejected and does not corrupt gain', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

      // 10 samples of normal flat track at 100m
      for (int i = 0; i < 10; i++) {
        pipeline.processPosition(
          createPos(
            altitude: 100.0,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          accumulatedDistanceMeters: i * 3.0,
        );
      }

      // Single GPS spike at i=10 (+50m spike in 1s = 50 m/s vertical speed jump)
      final spikePos = createPos(
        altitude: 150.0,
        timestamp: baseTime.add(const Duration(seconds: 10)),
      );
      final spikeResult = pipeline.processPosition(
        spikePos,
        accumulatedDistanceMeters: 33.0,
      );

      // 10 subsequent samples returning to 100m
      ElevationResult? postSpikeResult;
      for (int i = 11; i < 20; i++) {
        postSpikeResult = pipeline.processPosition(
          createPos(
            altitude: 100.0,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          accumulatedDistanceMeters: i * 3.0,
        );
      }

      expect(spikeResult.cumulativeGainMeters, equals(0.0));
      expect(postSpikeResult!.cumulativeGainMeters, equals(0.0));
      expect(postSpikeResult.smoothedAltitude, closeTo(100.0, 0.5));
    });

    test('Incline grade is strictly clamped to +/- 20% limit', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

      // Initialize baseline at distance 0m, altitude 100m
      pipeline.processPosition(
        createPos(altitude: 100.0, timestamp: baseTime),
        accumulatedDistanceMeters: 0.0,
      );

      // Steep climb over 30m distance: rises 20m (raw grade = 20 / 30 = 66.7%)
      // Feed samples at 1m/s vertical rate (within 15 m/s threshold)
      ElevationResult? result;
      for (int i = 1; i <= 30; i++) {
        result = pipeline.processPosition(
          createPos(
            altitude: 100.0 + (i * (20.0 / 30.0)),
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          accumulatedDistanceMeters: i * 1.0, // 30m accumulated horizontal dist
        );
      }

      expect(result, isNotNull);
      // Must be clamped to maxGradeClamp (+0.20 = +20%)
      expect(result!.grade, equals(0.20));
      expect(result.gradePercentString, equals('+20.0%'));
    });

    test('Rejects degraded accuracy fixes (accuracy > 30m or altitudeAccuracy > 25m)', () {
      final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

      final validResult = pipeline.processPosition(
        createPos(
          altitude: 100.0,
          accuracy: 10.0,
          altitudeAccuracy: 8.0,
          timestamp: baseTime,
        ),
        accumulatedDistanceMeters: 10.0,
      );
      expect(validResult.smoothedAltitude, equals(100.0));

      // Bad horizontal accuracy (40m > 30m)
      final badHorizontalResult = pipeline.processPosition(
        createPos(
          altitude: 200.0,
          accuracy: 40.0,
          altitudeAccuracy: 8.0,
          timestamp: baseTime.add(const Duration(seconds: 1)),
        ),
        accumulatedDistanceMeters: 13.0,
      );
      expect(badHorizontalResult.smoothedAltitude, equals(100.0));

      // Bad altitude accuracy (35m > 25m)
      final badVerticalResult = pipeline.processPosition(
        createPos(
          altitude: 200.0,
          accuracy: 8.0,
          altitudeAccuracy: 35.0,
          timestamp: baseTime.add(const Duration(seconds: 2)),
        ),
        accumulatedDistanceMeters: 16.0,
      );
      expect(badVerticalResult.smoothedAltitude, equals(100.0));
    });

    test(
      'Barometer fusion: pressure drop produces hypsometric altitude climb',
      () {
        final baseTime = DateTime(2026, 11, 7, 10, 0, 0);

        // Ingest initial GPS fix at sea level (1013.25 hPa reference)
        pipeline.processPosition(
          createPos(altitude: 100.0, timestamp: baseTime),
          accumulatedDistanceMeters: 0.0,
        );

        // Ingest baseline barometer reading: 1013.25 hPa
        pipeline.addBarometerReading(1013.25);
        expect(pipeline.isBarometerActive, isTrue);

        // Atmospheric pressure drops by 2.0 hPa (to 1011.25 hPa)
        // Standard hypsometric gradient: ~8.43 m per hPa => ~16.8 meters rise
        pipeline.addBarometerReading(1011.25);

        // Smoothed altitude should have adjusted upwards by ~16.8m from 100m (~116.8m)
        expect(pipeline.smoothedAltitude, closeTo(116.8, 1.5));
      },
    );
  });
}
