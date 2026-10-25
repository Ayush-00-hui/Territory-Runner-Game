import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/firebase_service.dart';
import '../../../services/motion_sensor_service.dart';
import '../../../services/sync_queue.dart';
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
  final finalSeconds = summary['durationSeconds'] as int;
  final finalDistance = summary['distanceKm'] as double;
  final finalTerritories = summary['territories'] as int;
  final finalArea = summary['areaSqm'] as double;
  final finalXp = summary['xp'] as int;
  final points = summary['points'] as List<LatLng>;

  TerritoryService().defendTerritory(FirebaseService().currentUserId);
  TerritoryService().addRunDistance(finalDistance);
  onTerritoriesUpdated();

  if (points.length >= 3) {
    SyncQueueService().enqueueRun(
      points: points,
      durationSeconds: finalSeconds,
      distanceMeters: finalDistance * 1000.0,
      activityType: controller.selectedActivity.id,
      clientPreviewArea: finalArea,
      clientPreviewXp: finalXp,
      motionWindows: motionWindows,
    );
  }

  SummarySheet.show(
    context: context,
    distanceKm: finalDistance,
    durationSeconds: finalSeconds,
    territoriesClaimed: finalTerritories,
    profile: TerritoryService().getProfile(),
    coachService: LLMCoachService(),
    routePoints: points,
    areaSqMeters: finalArea > 0 ? finalArea : null,
  );
}
