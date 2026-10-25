import 'package:flutter/material.dart';

import '../../../services/battery_saver_service.dart';
import '../../../ui/ui.dart';
import '../controllers/map_run_controller.dart';
import '../models/run_telemetry.dart';
import 'run_goal_sheet.dart';
import 'run_hud.dart';

/// Wrapped telemetry HUD panel with size measurement and goal/run action triggers.
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
      child: ValueListenableBuilder<RunTelemetry>(
        valueListenable: controller.telemetryNotifier,
        builder: (context, telemetry, _) {
          return RunHud(
            isRunActive: controller.isRunActive,
            stepCount: controller.stepCount,
            isSearchingGps: controller.currentLocation == null,
            isAutoPaused: telemetry.isAutoPaused,
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
              final goal = await RunGoalSheet.show(
                context,
                currentGoal: controller.activeGoal,
              );
              if (goal != null) {
                controller.setGoal(goal);
              }
            },
            isBatterySaverActive: BatterySaverService().isBatterySaverEnabled,
            onToggleAmoledSaver: () {
              AppMotion.mediumTick();
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
