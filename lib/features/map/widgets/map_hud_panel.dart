import 'package:flutter/material.dart';

import '../../../services/battery_saver_service.dart';
import '../../../services/run_log_service.dart';
import '../../../ui/ui.dart';
import '../../coach/pace_prediction_service.dart';
import '../../gameplay/territory_service.dart';
import '../controllers/map_run_controller.dart';
import 'run_goal_sheet.dart';
import 'run_hud.dart';

/// Wrapped metrics HUD panel with size measurement and goal/run action triggers.
class MapHudPanel extends StatelessWidget {
  final MapRunController controller;
  final ValueNotifier<double> hudHeightNotifier;
  final VoidCallback onToggleRun;
  final VoidCallback onFinishRun;

  const MapHudPanel({
    super.key,
    required this.controller,
    required this.hudHeightNotifier,
    required this.onToggleRun,
    required this.onFinishRun,
  });

  @override
  Widget build(BuildContext context) {
    return MeasureSize(
      onChange: (size) {
        if (hudHeightNotifier.value != size.height) {
          hudHeightNotifier.value = size.height;
        }
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([
          controller.telemetryNotifier,
          controller,
        ]),
        builder: (context, _) {
          final telemetry = controller.telemetryNotifier.value;
          return RunHud(
            isRunActive: controller.isRunActive,
            isSimulated: controller.isSimulated,
            stepCount: telemetry.stepCount ?? controller.stepCount,
            isStepCountEstimated: telemetry.isStepCountEstimated,
            grade: telemetry.grade,
            elevationGainMeters: telemetry.elevationGainMeters,
            cadenceSpm: telemetry.cadenceSpm,
            strideLengthMeters: telemetry.strideLengthMeters,
            isSearchingGps: controller.currentLocation == null,
            isAutoPaused: telemetry.isAutoPaused || controller.isPaused,
            distanceKm: telemetry.distanceKm,
            elapsedSeconds: telemetry.elapsedSeconds,
            movingSeconds: telemetry.movingSeconds,
            splitPace: telemetry.splitPace,
            currentSpeedKmh: telemetry.currentSpeedKmh,
            satelliteAccuracyMeters: telemetry.satelliteAccuracyMeters,
            territoriesClaimed: telemetry.territoriesClaimed,
            distanceToClosureMeters: telemetry.distanceToClosureMeters,
            proximityToClosure: telemetry.proximityToClosure,
            runGoal: telemetry.activeGoal ?? controller.activeGoal,
            currentAreaSqm: telemetry.currentAreaSqm,
            onOpenGoalSelector: () async {
              final recentRuns = RunLogService().isBoxOpen
                  ? PacePredictionService.pastRunsFromLog(
                      RunLogService().getAllRuns(),
                    )
                  : null;
              final goal = await RunGoalSheet.show(
                context,
                currentGoal: controller.activeGoal,
                profile: TerritoryService().getProfile(),
                recentRuns: recentRuns,
              );
              if (!context.mounted || controller.isDisposed) return;
              if (goal != null) {
                controller.setGoal(goal);
              }
            },
            isBatterySaverActive: BatterySaverService().isBatterySaverEnabled,
            ghostTelemetryNotifier: controller.ghostTelemetryNotifier,
            workoutSnapshotNotifier: controller.workoutSnapshotNotifier,
            onSkipWorkoutPhase: controller.skipWorkoutPhase,
            exerciseActivity: controller.selectedActivity,
            onActivityChanged: controller.setActivity,
            onToggleAmoledSaver: () {
              BatterySaverService().setAmoledHudActive(true);
            },
            onToggleRun: onToggleRun,
            onSealShape: controller.sealCurrentShape,
            onFinishRun: onFinishRun,
          );
        },
      ),
    );
  }
}
