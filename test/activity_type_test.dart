import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/activity_type.dart';
import 'package:territory_runner/services/location_service.dart';
import 'package:territory_runner/services/sync_queue.dart';

void main() {
  group('Phase 2: ExerciseActivityType & Speed Ceiling Kinematics Tests', () {
    test('ExerciseActivityType enum has calibrated speed and endurance ceilings', () {
      expect(ExerciseActivityType.running.id, equals('running'));
      expect(ExerciseActivityType.running.displayName, equals('Running'));
      expect(ExerciseActivityType.running.maxSpeedKmh, equals(25.0));
      expect(ExerciseActivityType.running.maxAverageSpeedKmh, equals(22.0));

      expect(ExerciseActivityType.walking.id, equals('walking'));
      expect(ExerciseActivityType.walking.displayName, equals('Walking'));
      expect(ExerciseActivityType.walking.maxSpeedKmh, equals(10.0));
      expect(ExerciseActivityType.walking.maxAverageSpeedKmh, equals(8.5));

      expect(ExerciseActivityType.cycling.id, equals('cycling'));
      expect(ExerciseActivityType.cycling.displayName, equals('Cycling'));
      expect(ExerciseActivityType.cycling.maxSpeedKmh, equals(50.0));
      expect(ExerciseActivityType.cycling.maxAverageSpeedKmh, equals(40.0));

      // Parsing helpers
      expect(ExerciseActivityType.fromString('running'), equals(ExerciseActivityType.running));
      expect(ExerciseActivityType.fromString('RUNNING'), equals(ExerciseActivityType.running));
      expect(ExerciseActivityType.fromString('walking'), equals(ExerciseActivityType.walking));
      expect(ExerciseActivityType.fromString('cycling'), equals(ExerciseActivityType.cycling));
      expect(ExerciseActivityType.fromString('unknown'), equals(ExerciseActivityType.running));
      expect(ExerciseActivityType.fromString(null), equals(ExerciseActivityType.running));
    });

    test('LocationService.isValidFix rejects speeds exceeding activity ceiling', () {
      final locationService = LocationService();
      final now = DateTime.now();

      final lastPos = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 2.5, // 9 km/h
        speedAccuracy: 1.0,
      );

      // 1. Normal running fix (12 km/h) -> valid for running, walking fails
      final runningPos = Position(
        latitude: 37.7750, // ~11m displacement in 3 seconds = ~13.2 km/h
        longitude: -122.4194,
        timestamp: now.add(const Duration(seconds: 3)),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 3.3, // ~11.9 km/h
        speedAccuracy: 1.0,
      );
      expect(locationService.isValidFix(runningPos, lastPos, exerciseActivity: ExerciseActivityType.running), isTrue);
      // Exceeds walking max speed (10.0 + 2.0 = 12.0 km/h)
      expect(locationService.isValidFix(runningPos, lastPos, exerciseActivity: ExerciseActivityType.walking), isFalse);

      // 2. Cycling fix (~30 km/h, 8.3 m/s -> ~16.6m in 2s ~ 0.00015 deg lat)
      final cyclingPos = Position(
        latitude: 37.77505,
        longitude: -122.4194,
        timestamp: now.add(const Duration(seconds: 2)),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 8.3, // ~29.9 km/h
        speedAccuracy: 1.0,
      );
      expect(locationService.isValidFix(cyclingPos, lastPos, exerciseActivity: ExerciseActivityType.running), isFalse);
      expect(locationService.isValidFix(cyclingPos, lastPos, exerciseActivity: ExerciseActivityType.cycling), isTrue);

      // 3. Motorized highway vehicle fix (~80 km/h, 22.2 m/s -> ~44.4m in 2s ~ 0.00040 deg lat)
      final carPos = Position(
        latitude: 37.77530,
        longitude: -122.4194,
        timestamp: now.add(const Duration(seconds: 2)),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 22.5, // ~81 km/h
        speedAccuracy: 1.0,
      );
      expect(locationService.isValidFix(carPos, lastPos, exerciseActivity: ExerciseActivityType.cycling), isFalse);
    });

    test('QueuedRun serializes and deserializes activityType with backward compatibility', () {
      final now = DateTime.now();

      // 1. Explicit activityType
      final cyclingRun = QueuedRun(
        idempotencyKey: 'run_cyc_001',
        activityType: 'cycling',
        points: const [LatLng(51.5, -0.12), LatLng(51.501, -0.12)],
        durationSeconds: 120,
        distanceMeters: 800.0,
        clientPreviewArea: 2000.0,
        clientPreviewXp: 100,
        createdAt: now,
      );

      final jsonMap = cyclingRun.toJson();
      expect(jsonMap['activityType'], equals('cycling'));

      final reconstructed = QueuedRun.fromJson(jsonMap);
      expect(reconstructed.idempotencyKey, equals('run_cyc_001'));
      expect(reconstructed.activityType, equals('cycling'));

      // 2. Backward compatibility: JSON missing activityType defaults to 'running'
      final legacyJson = {
        'idempotencyKey': 'legacy_run_999',
        'points': [
          {'lat': 51.5, 'lng': -0.12}
        ],
        'durationSeconds': 60,
        'distanceMeters': 100.0,
        'clientPreviewArea': 500.0,
        'clientPreviewXp': 25,
        'createdAt': now.toIso8601String(),
      };

      final legacyRun = QueuedRun.fromJson(legacyJson);
      expect(legacyRun.activityType, equals('running'));
    });
  });
}
