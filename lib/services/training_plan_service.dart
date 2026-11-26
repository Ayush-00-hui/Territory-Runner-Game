import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/logging/app_logger.dart';
import '../models/training_plan.dart';

/// Local-first service managing training plan enrollments, calendar progressions,
/// and shame-free workout scheduling.
class TrainingPlanService {
  static final ValueNotifier<int> revisionNotifier = ValueNotifier<int>(0);
  static const String boxName = 'training_plans_v1';
  static const String activeEnrollmentKey = 'active_enrollment';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  /// Returns catalog of available training plans.
  List<TrainingPlan> getAvailablePlans() {
    return [TrainingPlan.couchTo5k, TrainingPlan.paceBuilder4Week];
  }

  /// Retrieves a specific plan by its unique ID.
  TrainingPlan? getPlanById(String id) {
    for (final plan in getAvailablePlans()) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  /// Gets the currently active plan enrollment (or null if free-running).
  Future<UserPlanEnrollment?> getActiveEnrollment() async {
    try {
      final box = await _getBox();
      final raw = box.get(activeEnrollmentKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserPlanEnrollment.fromJson(json);
    } catch (e) {
      AppLogger.error(
        'Error reading training plan enrollment: $e',
        tag: 'TrainingPlanService',
      );
      return null;
    }
  }

  /// Enrolls runner into a chosen training plan.
  Future<UserPlanEnrollment> enrollInPlan(String planId) async {
    final box = await _getBox();
    final enrollment = UserPlanEnrollment(
      planId: planId,
      enrolledAt: DateTime.now(),
      completedWorkoutIds: {},
    );
    await box.put(activeEnrollmentKey, jsonEncode(enrollment.toJson()));
    revisionNotifier.value++;
    AppLogger.info(
      'Enrolled in training plan: $planId',
      tag: 'TrainingPlanService',
    );
    return enrollment;
  }

  /// Leaves the current training plan.
  Future<void> unenroll() async {
    final box = await _getBox();
    await box.delete(activeEnrollmentKey);
    revisionNotifier.value++;
    AppLogger.info('Unenrolled from training plan', tag: 'TrainingPlanService');
  }

  /// Marks a specific workout as completed.
  Future<void> completeWorkout(String workoutId) async {
    final enrollment = await getActiveEnrollment();
    if (enrollment == null) return;

    final updatedSet = Set<String>.from(enrollment.completedWorkoutIds)
      ..add(workoutId);
    final updated = enrollment.copyWith(
      completedWorkoutIds: updatedSet,
      lastCompletedAt: DateTime.now(),
    );

    final box = await _getBox();
    await box.put(activeEnrollmentKey, jsonEncode(updated.toJson()));
    revisionNotifier.value++;
    AppLogger.info(
      'Completed plan workout: $workoutId (total: ${updatedSet.length})',
      tag: 'TrainingPlanService',
    );
  }

  /// Shame-free next workout resolver:
  /// Simply locates the first uncompleted non-rest workout in the enrolled plan sequence.
  /// If today was a missed day, there are no penalties—the runner just continues where they left off.
  Future<PlanWorkoutDay?> getNextWorkout() async {
    final enrollment = await getActiveEnrollment();
    if (enrollment == null) return null;

    final plan = getPlanById(enrollment.planId);
    if (plan == null) return null;

    for (final day in plan.schedule) {
      if (!day.isRestDay && !enrollment.completedWorkoutIds.contains(day.id)) {
        return day;
      }
    }
    return null; // Plan fully completed!
  }
}
