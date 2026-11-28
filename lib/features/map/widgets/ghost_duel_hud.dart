import 'package:flutter/material.dart';

import '../../../services/ghost_runner_service.dart';
import '../../../ui/ui.dart';
import '../controllers/map_run_controller.dart';
import 'ghost_runner_picker_sheet.dart';

/// Real-time athletic Ghost Duel HUD widget showing live delta and ghost pacing.
class GhostDuelHud extends StatelessWidget {
  final MapRunController controller;

  const GhostDuelHud({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GhostTelemetry?>(
      valueListenable: controller.ghostTelemetryNotifier,
      builder: (context, telemetry, _) {
        if (controller.ghostMode == GhostMode.off ||
            controller.activeGhostResult == null ||
            telemetry == null) {
          return const SizedBox.shrink();
        }

        final isAhead = telemetry.isRunnerAhead;
        final isOffRoute = telemetry.isOffRoute;

        final Color deltaColor;
        if (isOffRoute) {
          deltaColor = AppColors.warning;
        } else if (isAhead) {
          deltaColor = AppColors.accent;
        } else {
          deltaColor = AppColors.error;
        }

        final deltaStr = telemetry.statusText;
        final distanceKm = (telemetry.runnerProgressDistanceM / 1000.0)
            .toStringAsFixed(2);
        final ghostRun = controller.activeGhostResult?.matchedRun;
        final ghostDuration = ghostRun != null
            ? _formatDuration(
                ghostRun.movingSeconds > 0
                    ? ghostRun.movingSeconds
                    : ghostRun.totalSeconds,
              )
            : '--:--';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: deltaColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: deltaColor.withValues(alpha: 0.15),
                blurRadius: 12.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s6),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_run_rounded,
                  color: deltaColor,
                  size: 18.0,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GHOST DUEL • ${controller.ghostMode.label.toUpperCase()}',
                          style: AppText.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          deltaStr,
                          style: AppText.labelLarge.copyWith(
                            color: deltaColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Distance: $distanceKm km',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Target: $ghostDuration',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 18.0,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Adjust Ghost Runner',
                onPressed: () {
                  GhostRunnerPickerSheet.show(
                    context: context,
                    initialMode: controller.ghostMode,
                    currentLocation: controller.currentLocation,
                    onGhostSelected: (result) {
                      controller.setGhostSelection(result);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
