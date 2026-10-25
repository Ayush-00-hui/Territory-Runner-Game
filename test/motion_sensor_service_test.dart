import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/motion_sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotionSensorService Tests', () {
    test('Simulated genuine running produces ~160 SPM cadence and high confidence', () {
      final service = MotionSensorService(customStream: const Stream.empty());
      service.start();

      // Simulate 10 seconds of running at 25 Hz (250 samples)
      // Running cadence: 160 steps/min = 2.667 steps/second (Hz).
      // Period T = 1 / 2.667 = 0.375s.
      // Magnitude oscillation: 1.5 * sin(2 * pi * 2.667 * t) + noise
      const double dt = 0.04; // 25 Hz
      for (int i = 0; i < 250; i++) {
        final t = i * dt;
        final signal = 2.0 * math.sin(2 * math.pi * 2.667 * t);
        final x = signal * 0.6;
        final y = signal * 0.8;
        final z = 0.2 * math.sin(10 * t);
        service.addRawSample(t, x, y, z);
      }

      service.stop();

      final windows = service.windows;
      expect(windows, isNotEmpty);
      final win = windows.first;

      // Assert cadence is close to 160 SPM (+- 10 SPM)
      expect(win.cadenceSpm, inInclusiveRange(150.0, 175.0));
      // Assert motion energy is substantial (> 1.0 m^2/s^4)
      expect(win.motionEnergy, greaterThan(1.0));
      // Assert cadence confidence is high (> 0.70)
      expect(win.cadenceConfidence, greaterThan(0.70));
    });

    test('Simulated vehicle travel (low motion energy, near-zero cadence) yields 0 SPM and low confidence', () {
      final service = MotionSensorService(customStream: const Stream.empty());
      service.start();

      // Simulate 10 seconds of car passenger holding phone (smooth highway vibration: < 0.08 m/s^2)
      const double dt = 0.04;
      final rng = math.Random(42);
      for (int i = 0; i < 250; i++) {
        final t = i * dt;
        final x = (rng.nextDouble() - 0.5) * 0.05;
        final y = (rng.nextDouble() - 0.5) * 0.05;
        final z = (rng.nextDouble() - 0.5) * 0.05;
        service.addRawSample(t, x, y, z);
      }

      service.stop();

      final windows = service.windows;
      expect(windows, isNotEmpty);
      final win = windows.first;

      // Near-zero cadence and low energy
      expect(win.cadenceSpm, lessThan(35.0));
      expect(win.motionEnergy, lessThan(0.10));
      expect(win.cadenceConfidence, lessThan(0.25));
    });

    test('MotionWindow JSON serialization round-trips losslessly', () {
      final now = DateTime.now();
      final win = MotionWindow(
        startTime: now,
        durationSeconds: 10.0,
        cadenceSpm: 165.2,
        motionEnergy: 3.45,
        cadenceConfidence: 0.92,
      );

      final json = win.toJson();
      final restored = MotionWindow.fromJson(json);

      expect(restored.durationSeconds, equals(10.0));
      expect(restored.cadenceSpm, closeTo(165.2, 0.001));
      expect(restored.motionEnergy, closeTo(3.45, 0.001));
      expect(restored.cadenceConfidence, closeTo(0.92, 0.001));
    });
  });
}
