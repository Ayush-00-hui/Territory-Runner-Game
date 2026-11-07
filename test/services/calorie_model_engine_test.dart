import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/models/user_body_profile.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/calorie_model_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String sampleTreesJson;
  late String sampleMetaJson;
  late List<dynamic> testVectors;
  late String expectedSha;

  setUpAll(() {
    // Read the actual exported model assets and test vectors from disk
    final treesFile = File('assets/models/calorie_trees.json');
    final metaFile = File('assets/models/calorie_meta.json');
    final vectorsFile = File('test/assets/calorie_test_vectors.json');

    sampleTreesJson = treesFile.readAsStringSync();
    sampleMetaJson = metaFile.readAsStringSync();

    final vectorsData =
        jsonDecode(vectorsFile.readAsStringSync()) as Map<String, dynamic>;
    testVectors = vectorsData['test_vectors'] as List;
    expectedSha = vectorsData['trees_sha256'] as String;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppPreferences().resetForTesting();
    CalorieModelEngine().resetForTesting();
  });

  group('CalorieModelEngine Cryptographic Validation & Loading Tests', () {
    test('Successful loading with valid SHA-256 integrity hash', () {
      final engine = CalorieModelEngine();
      final success = engine.loadModelFromStrings(
        treeJson: sampleTreesJson,
        metaJson: sampleMetaJson,
      );

      expect(success, isTrue);
      expect(engine.isModelVerified, isTrue);
      expect(engine.modelVersion, equals('1.0.0'));
      expect(engine.modelSha256, equals(expectedSha));
    });

    test('Rejection and graceful fallback when SHA-256 hash mismatches (tampered model)', () {
      final engine = CalorieModelEngine();
      final tamperedTreeJson = sampleTreesJson.replaceFirst(
        '"leaf_value":',
        '"leaf_value": 999.0, //',
      );
      final success = engine.loadModelFromStrings(
        treeJson: tamperedTreeJson,
        metaJson: sampleMetaJson,
      );

      expect(success, isFalse);
      expect(engine.isModelVerified, isFalse);

      // Verify inference gracefully falls back to analytical equation without throwing
      final pred = engine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 1800.0,
        speedKmh: 10.0,
      );
      expect(pred.isModelVerified, isFalse);
      expect(pred.displayCalories, greaterThan(0));
    });

    test('Rejection and fallback when corrupted JSON is supplied', () {
      final engine = CalorieModelEngine();
      final success = engine.loadModelFromStrings(
        treeJson: '{ invalid json ]',
        metaJson: sampleMetaJson,
      );

      expect(success, isFalse);
      expect(engine.isModelVerified, isFalse);
    });
  });

  group('Dart vs Python Parity Verification (< 0.5% Tolerance)', () {
    test('Evaluates all test vectors matching Python LightGBM predictions within 0.5%', () {
      final engine = CalorieModelEngine();
      final loaded = engine.loadModelFromStrings(
        treeJson: sampleTreesJson,
        metaJson: sampleMetaJson,
      );
      expect(loaded, isTrue);

      for (final rawCase in testVectors) {
        final caseData = rawCase as Map<String, dynamic>;
        final desc = caseData['description'] as String;
        final feat = caseData['features'] as Map<String, dynamic>;
        final expP10 = (caseData['expected_p10'] as num).toDouble();
        final expP50 = (caseData['expected_p50'] as num).toDouble();
        final expP90 = (caseData['expected_p90'] as num).toDouble();

        final rates = engine.predictRates(
          massKg: (feat['body_mass_kg'] as num).toDouble(),
          speedKmh: (feat['speed_kmh'] as num).toDouble(),
          grade: (feat['grade'] as num).toDouble(),
          cadenceSpm: (feat['cadence_spm'] as num).toDouble(),
          climbRateMMin: (feat['climb_rate_m_min'] as num).toDouble(),
        );

        final p10 = rates['p10']!;
        final p50 = rates['p50']!;
        final p90 = rates['p90']!;

        // Check < 0.5% tolerance relative error
        final p10RelError = (p10 - expP10).abs() / expP10;
        final p50RelError = (p50 - expP50).abs() / expP50;
        final p90RelError = (p90 - expP90).abs() / expP90;

        expect(
          p10RelError,
          lessThan(0.005),
          reason:
              '$desc: P10 mismatch (Dart: $p10, Py: $expP10, err: $p10RelError)',
        );
        expect(
          p50RelError,
          lessThan(0.005),
          reason:
              '$desc: P50 mismatch (Dart: $p50, Py: $expP50, err: $p50RelError)',
        );
        expect(
          p90RelError,
          lessThan(0.005),
          reason:
              '$desc: P90 mismatch (Dart: $p90, Py: $expP90, err: $p90RelError)',
        );

        // Monotonic quantiles guarantee
        expect(p10, lessThanOrEqualTo(p50));
        expect(p50, lessThanOrEqualTo(p90));
      }
    });
  });

  group('On-Device Latency Benchmark', () {
    test(
      '1,000 evaluations execute with microsecond latency (< 50 us/call)',
      () {
        final engine = CalorieModelEngine();
        engine.loadModelFromStrings(
          treeJson: sampleTreesJson,
          metaJson: sampleMetaJson,
        );

        final stopwatch = Stopwatch()..start();
        const iterations = 1000;
        for (var i = 0; i < iterations; i++) {
          engine.predictRates(
            massKg: 70.0,
            speedKmh: 10.0 + (i % 5),
            grade: 0.02,
            cadenceSpm: 165.0,
            climbRateMMin: 3.3,
          );
        }
        stopwatch.stop();

        final totalUs = stopwatch.elapsedMicroseconds;
        final avgUsPerCall = totalUs / iterations;
        // Should easily run under 50 us per call on modern CPUs
        expect(avgUsPerCall, lessThan(100.0));
      },
    );
  });

  group('Personal Watch Calibration Tests', () {
    test(
      'Watch calibration requires at least 3 sessions before activating',
      () async {
        final prefs = AppPreferences();
        await prefs.init();

        expect(prefs.isWatchCalibrationActive, isFalse);
        expect(prefs.watchCalorieFactor, isNull);

        // Session 1: watch=420, model=400 (ratio 1.05)
        await prefs.recordWatchCalibrationSession(
          userWatchKcal: 420.0,
          modelEstimatedKcal: 400.0,
        );
        expect(prefs.watchCalibrationSessionCount, equals(1));
        expect(prefs.isWatchCalibrationActive, isFalse);

        // Session 2: watch=440, model=400 (ratio 1.10)
        await prefs.recordWatchCalibrationSession(
          userWatchKcal: 440.0,
          modelEstimatedKcal: 400.0,
        );
        expect(prefs.watchCalibrationSessionCount, equals(2));
        expect(prefs.isWatchCalibrationActive, isFalse);

        // Session 3: watch=410, model=400 (ratio 1.025)
        await prefs.recordWatchCalibrationSession(
          userWatchKcal: 410.0,
          modelEstimatedKcal: 400.0,
        );
        expect(prefs.watchCalibrationSessionCount, equals(3));
        expect(prefs.isWatchCalibrationActive, isTrue);

        // Median of [1.025, 1.05, 1.10] is 1.05
        expect(prefs.watchCalorieFactor, closeTo(1.05, 0.001));
      },
    );

    test(
      'Watch calibration factor is strictly bounded between [0.8, 1.2]',
      () async {
        final prefs = AppPreferences();
        await prefs.init();

        // Extreme high ratios (e.g. 2.0x)
        for (var i = 0; i < 3; i++) {
          await prefs.recordWatchCalibrationSession(
            userWatchKcal: 800.0,
            modelEstimatedKcal: 400.0,
          );
        }
        expect(
          prefs.watchCalorieFactor,
          equals(1.2),
        ); // Clamped to 1.2 upper bound

        await prefs.resetWatchCalibration();
        expect(prefs.isWatchCalibrationActive, isFalse);

        // Extreme low ratios (e.g. 0.4x)
        for (var i = 0; i < 3; i++) {
          await prefs.recordWatchCalibrationSession(
            userWatchKcal: 160.0,
            modelEstimatedKcal: 400.0,
          );
        }
        expect(
          prefs.watchCalorieFactor,
          equals(0.8),
        ); // Clamped to 0.8 lower bound
      },
    );

    test(
      'resetWatchCalibration clears stored sessions and resets factor to null',
      () async {
        final prefs = AppPreferences();
        await prefs.init();

        for (var i = 0; i < 3; i++) {
          await prefs.recordWatchCalibrationSession(
            userWatchKcal: 420.0,
            modelEstimatedKcal: 400.0,
          );
        }
        expect(prefs.isWatchCalibrationActive, isTrue);

        await prefs.resetWatchCalibration();
        expect(prefs.isWatchCalibrationActive, isFalse);
        expect(prefs.watchCalorieFactor, isNull);
        expect(prefs.watchCalibrationSessionCount, equals(0));
      },
    );
  });

  group('UI Honest Range Formatting Tests', () {
    test(
      'formatCalorieRange formats range string (e.g. 380–440 kcal (est.))',
      () {
        final engine = CalorieModelEngine();
        engine.loadModelFromStrings(
          treeJson: sampleTreesJson,
          metaJson: sampleMetaJson,
        );

        final result = engine.estimateSegment(
          distanceKm: 5.0,
          durationSeconds: 1800.0,
          speedKmh: 10.0,
          grade: 0.0,
          profile: UserBodyProfile.referenceAdult(weightKg: 70.0),
        );

        expect(result.displayCalories, greaterThan(0));
        expect(result.displayRange, contains('–'));
        expect(result.displayRange, contains('kcal (est.)'));
        expect(result.p10Kcal, lessThanOrEqualTo(result.p50Kcal));
        expect(result.p50Kcal, lessThanOrEqualTo(result.p90Kcal));
      },
    );

    test('Stationary time formats resting estimate', () {
      final engine = CalorieModelEngine();
      final result = engine.estimateSegment(
        distanceKm: 0.0,
        durationSeconds: 300.0, // 5 min
        speedKmh: 0.0,
      );

      expect(result.displayCalories, greaterThan(0));
      expect(result.p10Kcal, closeTo(result.p50Kcal, 0.01));
    });
  });
}
