import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/features/security/anomaly_service.dart';

void main() {
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
  });
}
