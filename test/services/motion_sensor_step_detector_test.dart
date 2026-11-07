import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/motion_sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotionSensorService Online Step Detector & Cadence Tests', () {
    test('Simulated genuine walking: counts 100 steps at 110 SPM with high confidence', () {
      final service = MotionSensorService(customStream: const Stream.empty());
      service.start();

      // Walking cadence: 110 SPM = 1.833 Hz
      // 100 steps = 100 / 1.8333 = 54.545 seconds of walking
      const double cadenceHz = 110.0 / 60.0;
      const double dt = 0.04; // 25 Hz
      const int targetSteps = 100;
      final int totalSamples = (targetSteps / cadenceHz / dt).round();

      for (int i = 0; i < totalSamples; i++) {
        final t = i * dt;
        // Sinusoidal magnitude representing walking impact bounce + arm swing
        final signal = 1.5 * math.sin(2 * math.pi * cadenceHz * t);
        final x = signal * 0.4;
        final y = signal * 0.9;
        final z = signal * 0.2;
        service.addRawSample(t, x, y, z);
      }

      service.stop();

      // Steps detected should match within +/- 2 steps of 100
      expect(service.liveStepCount, inInclusiveRange(98, 102));
      // Cadence should track ~110 SPM (+- 8 SPM)
      expect(service.currentCadenceSpm, inInclusiveRange(102.0, 118.0));
      // High cadence confidence (> 0.70)
      expect(service.currentCadenceConfidence, greaterThan(0.70));
      // Confirmed sensor steps should NOT be marked as estimated
      expect(service.isStepCountEstimated, isFalse);
    });

    test('Simulated genuine running: counts 100 steps at 165 SPM with high confidence', () {
      final service = MotionSensorService(customStream: const Stream.empty());
      service.start();

      // Running cadence: 165 SPM = 2.75 Hz
      // 100 steps = 100 / 2.75 = 36.36 seconds of running
      const double cadenceHz = 165.0 / 60.0;
      const double dt = 0.04; // 25 Hz
      const int targetSteps = 100;
      final int totalSamples = (targetSteps / cadenceHz / dt).round();

      for (int i = 0; i < totalSamples; i++) {
        final t = i * dt;
        // Stronger sinusoidal acceleration for running impact
        final signal = 3.2 * math.sin(2 * math.pi * cadenceHz * t);
        final x = signal * 0.5;
        final y = signal * 0.85;
        final z = signal * 0.15;
        service.addRawSample(t, x, y, z);
      }

      service.stop();

      // Assert exactly ~100 steps detected (+- 2 steps)
      expect(service.liveStepCount, inInclusiveRange(98, 102));
      // Cadence should track ~165 SPM (+- 8 SPM)
      expect(service.currentCadenceSpm, inInclusiveRange(157.0, 173.0));
      expect(service.currentCadenceConfidence, greaterThan(0.75));
      expect(service.isStepCountEstimated, isFalse);
    });

    test('Simulated stationary / vehicle vibration: 0 steps, low confidence, marked as estimated', () {
      final service = MotionSensorService(customStream: const Stream.empty());
      service.start();

      // 10 seconds of vehicle road noise (< 0.08 m/s^2)
      const double dt = 0.04;
      final rng = math.Random(99);
      for (int i = 0; i < 250; i++) {
        final t = i * dt;
        final x = (rng.nextDouble() - 0.5) * 0.06;
        final y = (rng.nextDouble() - 0.5) * 0.06;
        final z = (rng.nextDouble() - 0.5) * 0.06;
        service.addRawSample(t, x, y, z);
      }

      service.stop();

      // Should detect 0 steps
      expect(service.liveStepCount, equals(0));
      expect(service.currentCadenceSpm, equals(0.0));
      expect(service.currentCadenceConfidence, lessThan(0.30));
      // Unreliable steps flagged as estimated
      expect(service.isStepCountEstimated, isTrue);
    });

    test('Stride length computation from speed and cadence', () {
      final service = MotionSensorService(customStream: const Stream.empty());
      service.start();

      // Feed running at 165 SPM
      const double cadenceHz = 165.0 / 60.0;
      const double dt = 0.04;
      for (int i = 0; i < 150; i++) {
        final t = i * dt;
        final s = 3.0 * math.sin(2 * math.pi * cadenceHz * t);
        service.addRawSample(t, s * 0.6, s * 0.8, 0.1);
      }

      // At 10 km/h (2.778 m/s), running at ~165 SPM (~2.75 steps/s)
      // Stride length = 2.778 / 2.75 = ~1.01 meters
      final stride = service.computeStrideLength(10.0);
      expect(stride, isNotNull);
      expect(stride!, closeTo(1.01, 0.10));

      // When stopped / speed < 1.0 km/h, returns null
      expect(service.computeStrideLength(0.0), isNull);
    });
  });
}
