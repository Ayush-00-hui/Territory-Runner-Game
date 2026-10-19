import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/features/security/anomaly_service.dart';
import 'package:territory_runner/models/activity_type.dart';

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

    test('Vehicle-speed telemetry (> 25 km/h) triggers instant rule rejection', () {
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
    });

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
          speed: 3.5, // 12.6 km/h (jogging speed, exceeds 10 km/h walking ceiling)
          speedAccuracy: 0.5,
          isMocked: false,
        ),
      ];

      final result = anomalyService.scoreSegment(positions, ExerciseActivityType.walking);
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
      final runningResult = anomalyService.scoreSegment(positions, ExerciseActivityType.running);
      expect(runningResult.isAnomaly, isTrue);
      expect(runningResult.reason.contains('exceeded 25 km/h'), isTrue);

      // Under cycling mode: valid (<= 50 km/h urban cycling ceiling)
      final cyclingResult = anomalyService.scoreSegment(positions, ExerciseActivityType.cycling);
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

      final result = anomalyService.scoreSegment(positions, ExerciseActivityType.cycling);
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('exceeded 50 km/h'), isTrue);
    });

    test('Running mode rejects superhuman sustained average pace (> 22 km/h)', () {
      final now = DateTime.now();
      final positions = List.generate(5, (i) {
        return Position(
          latitude: 37.7749 + (i * 0.00006), // ~6.6m per second = ~24 km/h displacement
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

      final result = anomalyService.scoreSegment(positions, ExerciseActivityType.running);
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('endurance ceiling'), isTrue);
    });

    test('Biomechanical acceleration limit rejects impossible speed spikes', () {
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

      final runningResult = anomalyService.scoreSegment(positions, ExerciseActivityType.running);
      expect(runningResult.isAnomaly, isTrue);
      expect(runningResult.reason.contains('Biomechanical acceleration limit exceeded'), isTrue);

      // Same 12 m/s² acceleration is permitted under cycling (12.0 m/s² ceiling)
      final cyclingResult = anomalyService.scoreSegment(positions, ExerciseActivityType.cycling);
      expect(cyclingResult.isAnomaly, isFalse);
    });

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

      final result = anomalyService.scoreSegment(positions, ExerciseActivityType.running);
      expect(result.isAnomaly, isTrue);
      expect(result.reason.contains('Excessive frozen/replay identical GPS breadcrumbs detected'), isTrue);
    });
  });
}
