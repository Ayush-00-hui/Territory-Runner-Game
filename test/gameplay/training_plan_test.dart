import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:territory_runner/models/training_plan.dart';
import 'package:territory_runner/services/training_plan_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('training_plan_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Training Plan Model & Service Tests', () {
    test('Default built-in plans are valid and complete', () {
      final service = TrainingPlanService();
      final plans = service.getAvailablePlans();
      expect(plans.length, greaterThanOrEqualTo(2));

      final c25k = plans.firstWhere((p) => p.id == 'plan_couch_to_5k');
      expect(c25k.durationWeeks, 8);
      expect(c25k.totalWorkouts, greaterThan(0));

      final pace = plans.firstWhere((p) => p.id == 'plan_pace_builder_4w');
      expect(pace.durationWeeks, 4);
    });

    test('UserPlanEnrollment progress fraction and completion set', () {
      final enrollment = UserPlanEnrollment(
        planId: 'plan_couch_to_5k',
        enrolledAt: DateTime(2026, 1, 1),
        completedWorkoutIds: {'c25k_w1_d1', 'c25k_w1_d3'},
      );

      expect(enrollment.completedWorkoutIds.contains('c25k_w1_d1'), isTrue);
      expect(enrollment.completedWorkoutIds.contains('c25k_w1_d5'), isFalse);
      expect(enrollment.completedWorkoutIds.length, 2);
    });

    test('TrainingPlanService enrolls, retrieves, and completes workouts shame-free', () async {
      final service = TrainingPlanService();

      // Initially no active enrollment
      var active = await service.getActiveEnrollment();
      expect(active, isNull);

      // Enroll in 5K plan
      await service.enrollInPlan('plan_couch_to_5k');
      active = await service.getActiveEnrollment();
      expect(active, isNotNull);
      expect(active?.planId, 'plan_couch_to_5k');

      // First workout should be first non-rest day
      var nextWorkout = await service.getNextWorkout();
      expect(nextWorkout, isNotNull);
      expect(nextWorkout?.isRestDay, isFalse);

      final firstId = nextWorkout!.id;

      // Mark first workout as complete
      await service.completeWorkout(firstId);

      // Next workout gracefully moves forward (no shame or penalty)
      nextWorkout = await service.getNextWorkout();
      expect(nextWorkout, isNotNull);
      expect(nextWorkout?.id, isNot(equals(firstId)));

      final enrollment = await service.getActiveEnrollment();
      expect(enrollment?.completedWorkoutIds.contains(firstId), isTrue);
    });

    test('Switching plans replaces active enrollment cleanly', () async {
      final service = TrainingPlanService();
      await service.enrollInPlan('plan_couch_to_5k');

      // Switch to pace builder
      await service.enrollInPlan('plan_pace_builder_4w');
      final enrollment = await service.getActiveEnrollment();
      expect(enrollment?.planId, 'plan_pace_builder_4w');
      expect(enrollment?.completedWorkoutIds.isEmpty, isTrue);
    });
  });
}
