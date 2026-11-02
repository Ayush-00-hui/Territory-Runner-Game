import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/activity_type.dart';
import 'package:territory_runner/features/map/map_screen.dart';
import 'package:territory_runner/services/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C1 Steps Estimation & Backward Compatibility', () {
    test('estimateSteps calculates distance/0.75 for walking and distance/1.05 for running', () {
      // 1.0 km = 1000 m
      // Walking: 1000 / 0.75 = 1333.33 -> 1333
      expect(estimateSteps(1.0, ExerciseActivityType.walking), 1333);

      // Running: 1000 / 1.05 = 952.38 -> 952
      expect(estimateSteps(1.0, ExerciseActivityType.running), 952);

      // Cycling: null (steps hidden for cycling)
      expect(estimateSteps(1.0, ExerciseActivityType.cycling), isNull);
    });

    test('MapRunController returns null stepCount for cycling and estimates for running/walking', () {
      final controller = MapRunController();
      controller.setActivity(ExerciseActivityType.cycling);
      expect(controller.stepCount, isNull);

      controller.setActivity(ExerciseActivityType.running);
      expect(controller.stepCount, isNotNull);
      expect(controller.stepCount, 0);

      controller.setActivity(ExerciseActivityType.walking);
      expect(controller.stepCount, isNotNull);
      expect(controller.stepCount, 0);
    });

    test('QueuedRun JSON serialization and backward compatibility', () {
      final now = DateTime.now();
      final points = [
        const LatLng(51.5, -0.12),
        const LatLng(51.51, -0.12),
        const LatLng(51.5, -0.12),
      ];

      // 1. Run with stepCount serialized
      final runWithSteps = QueuedRun(
        idempotencyKey: 'key_steps_1',
        activityType: 'walking',
        points: points,
        durationSeconds: 600,
        distanceMeters: 800.0,
        clientPreviewArea: 500.0,
        clientPreviewXp: 100,
        createdAt: now,
        stepCount: 1067,
      );

      final jsonWithSteps = runWithSteps.toJson();
      expect(jsonWithSteps['stepCount'], 1067);

      final restoredWithSteps = QueuedRun.fromJson(jsonWithSteps);
      expect(restoredWithSteps.stepCount, 1067);

      // 2. Run without stepCount (legacy sync payload)
      final legacyJson = {
        'idempotencyKey': 'legacy_key_2',
        'activityType': 'cycling',
        'points': [
          {'lat': 51.5, 'lng': -0.12},
          {'lat': 51.51, 'lng': -0.12},
        ],
        'durationSeconds': 1200,
        'distanceMeters': 5000.0,
        'clientPreviewArea': 0.0,
        'clientPreviewXp': 0,
        'createdAt': now.toIso8601String(),
        'retryCount': 0,
      };

      final restoredLegacy = QueuedRun.fromJson(legacyJson);
      expect(restoredLegacy.stepCount, isNull);
      expect(restoredLegacy.toJson().containsKey('stepCount'), isFalse);

      // 3. copyWith stepCount
      final copied = restoredLegacy.copyWith(stepCount: 500);
      expect(copied.stepCount, 500);
    });
  });
}
