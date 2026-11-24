import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../models/interval_workout.dart';
import '../../../models/lap_split.dart';
import '../../../models/run_log_entry.dart';
import '../../../models/saved_loop.dart';
import '../../../services/app_preferences.dart';
import '../../../services/calorie_model_engine.dart';
import '../../../services/exploration_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/motion_sensor_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/run_log_service.dart';
import '../../../services/saved_loop_service.dart';
import '../../../services/sync_queue.dart';
import '../../../services/tiered_achievement_service.dart';
import '../../coach/llm_coach_service.dart';
import '../../gameplay/territory_service.dart';
import '../controllers/map_run_controller.dart';
import 'summary_sheet.dart';

/// Handles finishing an active run: enqueuing to encrypted sync queue and presenting SummarySheet.
void handleFinishRun({
  required BuildContext context,
  required MapRunController controller,
  required VoidCallback onTerritoriesUpdated,
}) {
  if (!controller.isRunActive) return;
  MotionSensorService().stop();
  final motionWindows = List<MotionWindow>.from(MotionSensorService().windows);

  final summary = controller.stopRun();
  final isSimulated =
      (summary['isSimulated'] as bool?) ?? controller.isSimulated;
  final finalSeconds = summary['durationSeconds'] as int;
  final finalDistance = summary['distanceKm'] as double;
  final finalTerritories = summary['territories'] as int;
  final finalArea = summary['areaSqm'] as double;
  final finalXp = summary['xp'] as int;
  final finalStepCount = summary['stepCount'] as int?;
  final elevationGain =
      (summary['elevationGainMeters'] as num?)?.toDouble() ?? 0.0;
  final points = summary['points'] as List<LatLng>;
  final laps = summary['laps'] as List<LapSplit>?;
  final savedLoop = summary['savedLoop'] as SavedLoop?;

  if (!isSimulated) {
    TerritoryService().defendTerritory(FirebaseService().currentUserId);
    TerritoryService().addRunDistance(finalDistance);
    AppPreferences().recordCompletedRunForBodyProfile();
    ExplorationService().recordVisitedPoints(points);
    TieredAchievementService().evaluateAllAchievements();
    if (savedLoop != null) {
      SavedLoopService().recordLoopRun(savedLoop.id, finalSeconds);
    }
    onTerritoriesUpdated();
  }

  final calories = AppPreferences().estimateCalories(
    distanceKm: finalDistance,
    durationMinutes: finalSeconds > 0 ? finalSeconds / 60.0 : null,
    activityType: controller.selectedActivity.id,
    elevationGainMeters: elevationGain,
  );
  final modelVersion = CalorieModelEngine().modelVersion;

  final runId = const Uuid().v4();
  final positions = (summary['positions'] as List<Position>?) ?? [];
  final startTime =
      (summary['startTime'] as DateTime?) ??
      DateTime.now().subtract(Duration(seconds: finalSeconds));
  final endTime = (summary['endTime'] as DateTime?) ?? DateTime.now();
  final totalSeconds =
      (summary['totalDurationSeconds'] as int?) ?? finalSeconds;
  final avgCadence = (summary['averageCadenceSpm'] as num?)?.toDouble() ?? 0.0;
  final cadenceConf = (summary['cadenceConfidence'] as num?)?.toDouble() ?? 0.0;

  final List<RunSample> samples = [];
  if (positions.isNotEmpty) {
    for (final p in positions) {
      final offset = p.timestamp.difference(startTime).inMilliseconds;
      samples.add(
        RunSample(
          timeOffsetMs: math.max(0, offset),
          lat: p.latitude,
          lng: p.longitude,
          altitude: p.altitude,
          accuracy: p.accuracy,
        ),
      );
    }
  } else {
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final offset = points.length > 1
          ? ((finalSeconds * 1000) * (i / (points.length - 1))).round()
          : 0;
      samples.add(
        RunSample(timeOffsetMs: offset, lat: pt.latitude, lng: pt.longitude),
      );
    }
  }

  RunLogService().recordRun(
    id: runId,
    startedAt: startTime,
    endedAt: endTime,
    activityType: controller.selectedActivity.id,
    movingSeconds: finalSeconds,
    totalSeconds: totalSeconds,
    distanceM: finalDistance * 1000.0,
    samples: samples,
    stepCount: finalStepCount,
    cadenceStats: CadenceStats(
      averageSpm: avgCadence,
      maxSpm: avgCadence,
      confidence: cadenceConf,
    ),
    calories: calories,
    calorieModelVersion: modelVersion,
    elevationGainM: elevationGain,
    claimedAreaSqM: isSimulated ? 0.0 : finalArea,
    xp: isSimulated ? 0 : finalXp,
    simulated: isSimulated,
    syncStatus: isSimulated
        ? 'demo_only'
        : (points.length >= 3 ? 'pending' : 'local_only'),
  );

  if (!isSimulated && points.length >= 3) {
    SyncQueueService().enqueueRun(
      idempotencyKey: runId,
      points: points,
      durationSeconds: finalSeconds,
      distanceMeters: finalDistance * 1000.0,
      activityType: controller.selectedActivity.id,
      clientPreviewArea: finalArea,
      clientPreviewXp: finalXp,
      motionWindows: motionWindows,
      stepCount: finalStepCount,
      estimatedCalories: calories,
      calorieModelVersion: modelVersion,
      simulated: false,
    );
  }

  SummarySheet.show(
    context: context,
    distanceKm: finalDistance,
    durationSeconds: finalSeconds,
    territoriesClaimed: isSimulated ? 0 : finalTerritories,
    profile: TerritoryService().getProfile(),
    coachService: LLMCoachService(),
    routePoints: points,
    samples: samples,
    areaSqMeters: (!isSimulated && finalArea > 0) ? finalArea : null,
    elevationGainMeters: elevationGain,
    ghostResult: summary['ghostResult'] as String?,
    workoutPlan: summary['workoutPlan'] as IntervalWorkoutPlan?,
    workoutExecutions:
        summary['workoutExecutions'] as List<WorkoutPhaseExecution>?,
    laps: laps,
    isSimulated: isSimulated,
  );

  // Opt-in flow: prompt for notification permissions only after capturing territory
  if (finalTerritories > 0) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().showPermissionPrimerIfNeeded(context);
    });
  }
}
