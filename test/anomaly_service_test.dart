import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/features/security/anomaly_service.dart';
import 'package:territory_runner/models/activity_type.dart';
import 'package:territory_runner/services/motion_sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnomalyService Anti-Cheat Tests', () {
    final AnomalyService anomalyService = AnomalyService();

    test('Genuine running trace passes anomaly check', () {
      final now = DateTime.now();
      final positions = List.generate(10, (i) {
        return Position(
          latitude: 37.7749 + (i * 0.00003),
          longitude: -122.4194 + (i * 0.00003),
          timestamp: now.add(Duration(seconds: i)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 45.0 + (i % 3),
          headingAccuracy: 1.0,
          speed: 2.7, // ~9.7 km/h (typical human jogging pace)
          speedAccuracy: 0.5,
          isMocked: false,
        );
      });

      final result = anomalyService.scoreSegment(positions);
      expect(result.isAnomaly, isFalse);
      expect(result.anomalyScore, lessThan(3.0));
    });

    test(
      'Vehicle-speed telemetry (> 25 km/h) triggers instant rule rejection',
      () {
        final now = DateTime.now();
        final positions = [
          Position(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: now,
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            accuracy: 5.0,
            heading: 90.0,
            headingAccuracy: 1.0,
            speed: 16.6, // ~60 km/h (Car driving)
            speedAccuracy: 0.5,
            isMocked: false,
          ),
        ];

        final result = anomalyService.scoreSegment(positions);
        expect(result.isAnomaly, isTrue);
        expect(result.reason.contains('exceeded 25 km/h'), isTrue);
      },
    );

    test('isMocked flag triggers immediate cheat rejection', () {
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 2.0,
          speedAccuracy: 0.5,
          isMocked: true, // Spoofed GPS
        ),
      ];

      final result = anomalyService.scoreSegment(positions);
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('Mock location'), isTrue);
    });

    test('Teleport jump (>50m in 1s) triggers anomaly detection', () {
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 2.0,
          speedAccuracy: 0.5,
          isMocked: false,
        ),
        Position(
          latitude: 37.7849, // ~1.1km jump
          longitude: -122.4194,
          timestamp: now.add(const Duration(seconds: 1)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 2.0,
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      final result = anomalyService.scoreSegment(positions);
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('teleportation'), isTrue);
    });

    test('Walking mode rejects running pace (> 10 km/h)', () {
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed:
              3.5, // 12.6 km/h (jogging speed, exceeds 10 km/h walking ceiling)
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      final result = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.walking,
      );
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('exceeded 10 km/h'), isTrue);
    });

    test('Cycling mode accepts cycling pace (~28 km/h) but running mode rejects it', () {
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 7.8, // 28.08 km/h
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      // Under running mode: flagged as cheat (> 25 km/h human sprinting ceiling)
      final runningResult = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.running,
      );
      expect(runningResult.isAnomaly, isTrue);
      expect(runningResult.reason.contains('exceeded 25 km/h'), isTrue);

      // Under cycling mode: valid (<= 50 km/h urban cycling ceiling)
      final cyclingResult = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.cycling,
      );
      expect(cyclingResult.isAnomaly, isFalse);
    });

    test('Cycling mode rejects motorized highway speeds (> 50 km/h)', () {
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 20.0, // 72 km/h (Car driving)
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      final result = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.cycling,
      );
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('exceeded 50 km/h'), isTrue);
    });

    test(
      'Running mode rejects superhuman sustained average pace (> 22 km/h)',
      () {
        final now = DateTime.now();
        final positions = List.generate(5, (i) {
          return Position(
            latitude:
                37.7749 +
                (i * 0.00006), // ~6.6m per second = ~24 km/h displacement
            longitude: -122.4194,
            timestamp: now.add(Duration(seconds: i)),
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            accuracy: 5.0,
            heading: 0.0,
            headingAccuracy: 1.0,
            speed: 6.0, // Instantaneous 21.6 km/h (under 25 km/h)
            speedAccuracy: 0.5,
            isMocked: false,
          );
        });

        final result = anomalyService.scoreSegment(
          positions,
          ExerciseActivityType.running,
        );
        expect(result.isAnomaly, isTrue);
        expect(result.reason.contains('endurance ceiling'), isTrue);
      },
    );

    test(
      'Biomechanical acceleration limit rejects impossible speed spikes',
      () {
        final now = DateTime.now();
        // Burst from 0 m/s to 6 m/s in 0.5s = 12.0 m/s² (exceeds 8.0 m/s² running limit)
        final positions = [
          Position(
            latitude: 37.774900,
            longitude: -122.4194,
            timestamp: now,
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            accuracy: 5.0,
            heading: 0.0,
            headingAccuracy: 1.0,
            speed: 0.0,
            speedAccuracy: 0.5,
            isMocked: false,
          ),
          Position(
            latitude: 37.774913,
            longitude: -122.4194,
            timestamp: now.add(const Duration(milliseconds: 500)),
            altitude: 10.0,
            altitudeAccuracy: 1.0,
            accuracy: 5.0,
            heading: 0.0,
            headingAccuracy: 1.0,
            speed: 6.0,
            speedAccuracy: 0.5,
            isMocked: false,
          ),
        ];

        final runningResult = anomalyService.scoreSegment(
          positions,
          ExerciseActivityType.running,
        );
        expect(runningResult.isAnomaly, isTrue);
        expect(
          runningResult.reason.contains(
            'Biomechanical acceleration limit exceeded',
          ),
          isTrue,
        );

        // Same 12 m/s² acceleration is permitted under cycling (12.0 m/s² ceiling)
        final cyclingResult = anomalyService.scoreSegment(
          positions,
          ExerciseActivityType.cycling,
        );
        expect(cyclingResult.isAnomaly, isFalse);
      },
    );

    test('Excessive frozen GPS breadcrumbs (> 50% identical) triggers replay detection', () {
      final now = DateTime.now();
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 1.5,
          speedAccuracy: 0.5,
          isMocked: false,
        ),
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now.add(const Duration(seconds: 1)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 1.5,
          speedAccuracy: 0.5,
          isMocked: false,
        ),
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now.add(const Duration(seconds: 2)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 1.5,
          speedAccuracy: 0.5,
          isMocked: false,
        ),
        Position(
          latitude: 37.774913,
          longitude: -122.4194,
          timestamp: now.add(const Duration(seconds: 3)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 1.5,
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      final result = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.running,
      );
      expect(result.isAnomaly, isTrue);
      expect(
        result.reason.contains(
          'Excessive frozen/replay identical GPS breadcrumbs detected',
        ),
        isTrue,
      );
    });

    test('Cross-language parity: anomaly vectors match Go backend within 1e-6', () {
      final file = File('test_fixtures/anomaly_vectors.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'test_fixtures/anomaly_vectors.json must exist',
      );
      final Map<String, dynamic> jsonMap = jsonDecode(file.readAsStringSync());
      expect(jsonMap['model_type'], equals('WeightedZScoreDetector'));

      final List testCases = jsonMap['test_cases'] as List;
      for (final tc in testCases) {
        final String name = tc['name'] as String;
        final List<double> features = (tc['features'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        final double expectedScore = (tc['expected_score'] as num).toDouble();
        final double actualScore = anomalyService.scoreFeatureVector(features);

        expect(
          (actualScore - expectedScore).abs(),
          lessThan(1e-6),
          reason:
              'Parity mismatch on vector "$name": expected $expectedScore, got $actualScore',
        );
      }
    });

    test('Regression: Genuine 25-point run window containing 2 stopped samples is NOT flagged', () {
      final now = DateTime.now();
      double lat = 37.77490;
      const double lng = -122.41940;
      const double latStep =
          0.000024; // ~2.7m per second (typical 9.7 km/h jogging pace)

      final positions = List.generate(25, (i) {
        final isStop = (i == 10 || i == 11);
        if (i > 0 && i != 10 && i != 11 && i != 12) {
          lat += latStep;
        }
        return Position(
          latitude: lat,
          longitude: lng,
          timestamp: now.add(Duration(seconds: i)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 45.0,
          headingAccuracy: 1.0,
          speed: isStop ? 0.0 : 2.7,
          speedAccuracy: 0.5,
          isMocked: false,
        );
      });

      final result = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.running,
      );
      expect(
        result.isAnomaly,
        isFalse,
        reason: 'A genuine 25-point run window containing 2 stopped samples must NOT be flagged',
      );
      expect(result.anomalyScore, lessThan(anomalyService.anomalyThreshold));
      expect(result.reason.contains('Genuine'), isTrue);
    });

    test('Cryptographic SHA256 and model version integrity check', () {
      final treesFile = File('assets/models/anomaly_detector_trees.json');
      final metaFile = File('assets/models/anomaly_detector_meta.json');
      expect(treesFile.existsSync(), isTrue);
      expect(metaFile.existsSync(), isTrue);

      final treeStr = treesFile.readAsStringSync();
      final metaStr = metaFile.readAsStringSync();

      // Valid load
      final loaded = anomalyService.loadModelFromStrings(
        treeJson: treeStr,
        metaJson: metaStr,
      );
      expect(loaded, isTrue);
      expect(anomalyService.isModelVerified, isTrue);
      expect(anomalyService.modelVersion, equals('3.0.0'));
      expect(anomalyService.modelSha256.isNotEmpty, isTrue);

      // Tampered tree payload check: corrupted character must fail verification
      final tamperedTrees = treeStr.replaceFirst(
        'split_feature',
        'corrupted_field',
      );
      final tamperedLoaded = anomalyService.loadModelFromStrings(
        treeJson: tamperedTrees,
        metaJson: metaStr,
      );
      expect(tamperedLoaded, isFalse);
      expect(anomalyService.isModelVerified, isFalse);

      // Restore valid model for subsequent tests
      anomalyService.loadModelFromStrings(treeJson: treeStr, metaJson: metaStr);
      expect(anomalyService.isModelVerified, isTrue);
    });

    test('Cross-Language Parity: 200 Fixed Windows (Dart vs Go vs Python)', () {
      // Ensure verified model is loaded
      final treesFile = File('assets/models/anomaly_detector_trees.json');
      final metaFile = File('assets/models/anomaly_detector_meta.json');
      anomalyService.loadModelFromStrings(
        treeJson: treesFile.readAsStringSync(),
        metaJson: metaFile.readAsStringSync(),
      );
      expect(anomalyService.isModelVerified, isTrue);

      final parityFile = File('test_fixtures/parity_200_windows.json');
      expect(
        parityFile.existsSync(),
        isTrue,
        reason: 'test_fixtures/parity_200_windows.json must exist',
      );

      final Map<String, dynamic> data = jsonDecode(
        parityFile.readAsStringSync(),
      );
      expect(data['model_version'], equals('3.0.0'));
      expect(data['total_windows'], equals(200));

      final testCases = data['test_cases'] as List;
      expect(testCases.length, equals(200));

      final stopwatch = Stopwatch()..start();
      double maxDiff = 0.0;
      int mismatchDecisions = 0;

      for (final tc in testCases) {
        final id = tc['id'] as String;
        final features = (tc['features'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        final expectedProb = (tc['expected_probability'] as num).toDouble();
        final expectedAnomaly = tc['expected_is_anomaly'] as bool;

        final actualProb = anomalyService.predictProbability(features);
        final diff = (actualProb - expectedProb).abs();
        if (diff > maxDiff) {
          maxDiff = diff;
        }

        expect(
          diff,
          lessThan(1e-4),
          reason:
              'Parity mismatch on window $id: expected $expectedProb, got $actualProb (diff: $diff)',
        );

        final actualAnomaly = actualProb >= 0.50;
        if (actualAnomaly != expectedAnomaly) {
          mismatchDecisions++;
        }
      }

      stopwatch.stop();
      final double avgLatencyUs =
          (stopwatch.elapsedMicroseconds) / testCases.length;

      // Assert zero decision mismatches across all 200 windows
      expect(
        mismatchDecisions,
        equals(0),
        reason: 'Zero decision mismatches across all 200 parity windows',
      );
      expect(
        maxDiff,
        lessThan(1e-4),
        reason: 'Max floating point diff must be < 1e-4',
      );
      // Latency verification: pure Dart evaluation is fast (< 100 µs per window)
      expect(avgLatencyUs, lessThan(100.0));
    });

    test('Feature flag fallback: useMlModel = false falls back to Tier 1 + Z-score', () {
      final now = DateTime.now();
      final positions = List.generate(10, (i) {
        return Position(
          latitude: 37.7749 + (i * 0.00003),
          longitude: -122.4194 + (i * 0.00003),
          timestamp: now.add(Duration(seconds: i)),
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 45.0,
          headingAccuracy: 1.0,
          speed: 2.7,
          speedAccuracy: 0.5,
          isMocked: false,
        );
      });

      final motionWindows = <MotionWindow>[
        MotionWindow(
          startTime: now,
          durationSeconds: 10.0,
          cadenceSpm: 165.0,
          motionEnergy: 0.42,
          cadenceConfidence: 0.95,
        ),
      ];

      // With ML enabled: features include ml_anomaly_prob
      anomalyService.useMlModel = true;
      final withMl = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.running,
        motionWindows,
      );
      expect(withMl.features.containsKey('ml_anomaly_prob'), isTrue);

      // With ML disabled: fallback to rules-only / Z-score
      anomalyService.useMlModel = false;
      final withoutMl = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.running,
        motionWindows,
      );
      expect(withoutMl.features.containsKey('ml_anomaly_prob'), isFalse);

      // Restore flag
      anomalyService.useMlModel = true;
    });

    test('Tier 1 Cadence Stillness Rule: high speed (>6 km/h) with stationary cadence triggers rejection', () {
      final now = DateTime.now();
      // Moving at 14.4 km/h (4.0 m/s) with near-zero cadence
      final positions = [
        Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          accuracy: 5.0,
          heading: 90.0,
          headingAccuracy: 1.0,
          speed: 4.0, // 14.4 km/h
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      final vehicleMotion = <MotionWindow>[
        MotionWindow(
          startTime: now,
          durationSeconds: 10.0,
          cadenceSpm: 12.0, // low cadence (stationary / car passenger)
          motionEnergy: 0.02, // low energy
          cadenceConfidence: 0.15,
        ),
      ];

      final result = anomalyService.scoreSegment(
        positions,
        ExerciseActivityType.running,
        vehicleMotion,
      );
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('Vehicle transit detected'), isTrue);
      expect(result.anomalyScore, greaterThanOrEqualTo(60.0));
    });
  });
}
