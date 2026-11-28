import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/locomotion_verification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocomotionVerificationService RTX 5070 Biometrics Model Tests', () {
    late LocomotionVerificationService service;

    setUp(() {
      service = LocomotionVerificationService();
    });

    test('Initializes with default calibrated metadata', () async {
      await service.initialize();
      expect(service.isModelLoaded, true);
      expect(service.currentSampleSize, 0);
    });

    test('Evaluates empty window gracefully', () {
      final res = service.evaluateWindow();
      expect(res.isValidForTerritoryClaim, true);
      expect(res.regime, LocomotionRegime.humanRunning);
      expect(res.label, contains('Awaiting'));
    });

    test('Verifies legitimate athletic human running', () {
      final now = DateTime.now();
      for (int i = 0; i < 32; i++) {
        service.addSample(
          LocomotionSensorSample(
            speedMps: 3.5, // ~12.6 km/h
            accelerationMps2: 0.05,
            bearingRateRads: 0.02,
            cadenceSpm: 172.0, // Active running cadence
            verticalOscillationCm: 8.5, // Biological vertical bounce
            gnssAccuracyM: 4.5,
            jerkMps3: 0.01,
            pitchDeg: 0.5,
            timestamp: now.add(Duration(milliseconds: i * 100)),
          ),
        );
      }

      final res = service.evaluateWindow();
      expect(res.regime, LocomotionRegime.humanRunning);
      expect(res.isValidForTerritoryClaim, true);
      expect(res.legitimacyScore, greaterThanOrEqualTo(0.95));
      expect(res.anomalyFlag, isNull);
      expect(res.explanation, contains('172 spm'));
    });

    test('Verifies legitimate pedestrian walking recovery', () {
      final now = DateTime.now();
      for (int i = 0; i < 32; i++) {
        service.addSample(
          LocomotionSensorSample(
            speedMps: 1.4, // ~5.0 km/h
            accelerationMps2: 0.01,
            bearingRateRads: 0.04,
            cadenceSpm: 110.0, // Walking cadence
            verticalOscillationCm: 3.8, // Walk bounce
            gnssAccuracyM: 3.5,
            jerkMps3: 0.01,
            pitchDeg: 0.2,
            timestamp: now.add(Duration(milliseconds: i * 100)),
          ),
        );
      }

      final res = service.evaluateWindow();
      expect(res.regime, LocomotionRegime.humanWalking);
      expect(res.isValidForTerritoryClaim, true);
      expect(res.legitimacyScore, greaterThanOrEqualTo(0.90));
      expect(res.anomalyFlag, isNull);
      expect(res.label, contains('Human Walk'));
    });

    test('Detects motor vehicle transit and blocks territory claim', () {
      final now = DateTime.now();
      for (int i = 0; i < 32; i++) {
        service.addSample(
          LocomotionSensorSample(
            speedMps: 15.0, // 54.0 km/h (Car/Motorcycle)
            accelerationMps2: 0.2,
            bearingRateRads: 0.01,
            cadenceSpm: 0.0, // Zero footsteps
            verticalOscillationCm: 0.2, // Rigid vehicle chassis
            gnssAccuracyM: 5.0,
            jerkMps3: 0.05,
            pitchDeg: 0.0,
            timestamp: now.add(Duration(milliseconds: i * 100)),
          ),
        );
      }

      final res = service.evaluateWindow();
      expect(res.regime, LocomotionRegime.vehicleTransit);
      expect(res.isValidForTerritoryClaim, false);
      expect(res.legitimacyScore, 0.0);
      expect(res.anomalyFlag, 'VEHICLE_SPEED_ANOMALY');
      expect(res.label, contains('Motor Vehicle'));
    });

    test('Detects electric scooter glide without active cadence', () {
      final now = DateTime.now();
      for (int i = 0; i < 32; i++) {
        service.addSample(
          LocomotionSensorSample(
            speedMps: 5.5, // ~20 km/h
            accelerationMps2: 0.1,
            bearingRateRads: 0.03,
            cadenceSpm: 2.0, // Near zero cadence despite 20 km/h
            verticalOscillationCm: 0.8, // Flat standing deck
            gnssAccuracyM: 4.0,
            jerkMps3: 0.02,
            pitchDeg: -0.5,
            timestamp: now.add(Duration(milliseconds: i * 100)),
          ),
        );
      }

      final res = service.evaluateWindow();
      expect(res.regime, LocomotionRegime.eScooterGlide);
      expect(res.isValidForTerritoryClaim, false);
      expect(res.anomalyFlag, 'E_SCOOTER_GLIDE_ANOMALY');
      expect(res.label, contains('Electric Scooter'));
    });

    test('Detects fake GPS joystick and emulator cheating', () {
      final now = DateTime.now();
      for (int i = 0; i < 32; i++) {
        service.addSample(
          LocomotionSensorSample(
            speedMps: 3.5, // 12.6 km/h synthetic joystick
            accelerationMps2: 0.0, // Unnatural zero acceleration jitter
            bearingRateRads: i % 8 == 0 ? 0.785 : 0.0, // Discrete 45 deg angles
            cadenceSpm: 0.0, // No real pedometer steps
            verticalOscillationCm: 0.0, // Zero vertical displacement
            gnssAccuracyM: 3.0, // Synthetic constant accuracy
            jerkMps3: 0.0,
            pitchDeg: 0.0,
            timestamp: now.add(Duration(milliseconds: i * 100)),
          ),
        );
      }

      final res = service.evaluateWindow();
      expect(res.regime, LocomotionRegime.mockJoystick);
      expect(res.isValidForTerritoryClaim, false);
      expect(res.legitimacyScore, 0.0);
      expect(res.anomalyFlag, 'MOCK_JOYSTICK_EMULATOR');
      expect(res.label, contains('Fake Location Emulator'));
    });

    test('Maintains sliding window size and supports clearWindow', () {
      final now = DateTime.now();
      for (int i = 0; i < 50; i++) {
        service.addSample(
          LocomotionSensorSample(
            speedMps: 3.0,
            accelerationMps2: 0.0,
            bearingRateRads: 0.0,
            cadenceSpm: 160.0,
            verticalOscillationCm: 7.0,
            gnssAccuracyM: 4.0,
            jerkMps3: 0.0,
            pitchDeg: 0.0,
            timestamp: now.add(Duration(milliseconds: i * 100)),
          ),
        );
      }

      expect(service.currentSampleSize, 32); // Capped at requiredWindowSize

      service.clearWindow();
      expect(service.currentSampleSize, 0);
    });
  });
}
