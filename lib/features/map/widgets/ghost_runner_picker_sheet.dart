import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/run_log_entry.dart';
import '../../../services/ghost_runner_service.dart';
import '../../../ui/ui.dart';

/// Modal bottom sheet for configuring the Ghost Runner mode before starting a run.
class GhostRunnerPickerSheet extends StatefulWidget {
  final GhostMode initialMode;
  final LatLng? currentLocation;
  final String activityType;
  final ValueChanged<GhostSelectionResult> onGhostSelected;
  final GhostRunnerService? ghostService;

  const GhostRunnerPickerSheet({
    super.key,
    required this.initialMode,
    this.currentLocation,
    this.activityType = 'running',
    required this.onGhostSelected,
    this.ghostService,
  });

  static Future<void> show({
    required BuildContext context,
    required GhostMode initialMode,
    LatLng? currentLocation,
    String activityType = 'running',
    required ValueChanged<GhostSelectionResult> onGhostSelected,
    GhostRunnerService? ghostService,
  }) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => GhostRunnerPickerSheet(
        initialMode: initialMode,
        currentLocation: currentLocation,
        activityType: activityType,
        onGhostSelected: onGhostSelected,
        ghostService: ghostService,
      ),
    );
  }

  @override
  State<GhostRunnerPickerSheet> createState() => _GhostRunnerPickerSheetState();
}

class _GhostRunnerPickerSheetState extends State<GhostRunnerPickerSheet> {
  late GhostMode _selectedMode;
  late final GhostRunnerService _ghostService;
  GhostSelectionResult? _previewResult;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _ghostService = widget.ghostService ?? GhostRunnerService();
    _evaluateSelection(_selectedMode);
  }

  void _evaluateSelection(GhostMode mode) {
    setState(() {
      _selectedMode = mode;
      _previewResult = _ghostService.selectGhostRun(
        mode: mode,
        origin: widget.currentLocation,
        activityType: widget.activityType,
      );
    });
  }

  void _applySelection() {
    final result =
        _previewResult ??
        GhostSelectionResult(
          mode: _selectedMode,
          calmExplanation: 'Ghost runner is disabled.',
        );
    widget.onGhostSelected(result);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final match = _previewResult?.matchedRun;
    final explanation = _previewResult?.calmExplanation;

    return AppSheet(
      title: 'Ghost runner',
      subtitle: 'Pace against authentic past performances offline',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Options
          _ModeRadioTile(
            title: 'Off',
            subtitle: 'Run without a pacing ghost',
            isSelected: _selectedMode == GhostMode.off,
            onTap: () => _evaluateSelection(GhostMode.off),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ModeRadioTile(
            title: 'Last run on this loop',
            subtitle: 'Replay your most recent run starting nearby',
            isSelected: _selectedMode == GhostMode.lastOnLoop,
            onTap: () => _evaluateSelection(GhostMode.lastOnLoop),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ModeRadioTile(
            title: 'Best run on this loop',
            subtitle: 'Replay your fastest recorded lap on this course',
            isSelected: _selectedMode == GhostMode.bestOnLoop,
            onTap: () => _evaluateSelection(GhostMode.bestOnLoop),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ModeRadioTile(
            title: 'Personal best for this activity',
            subtitle: 'Pace against your all-time fastest activity effort',
            isSelected: _selectedMode == GhostMode.personalBestActivity,
            onTap: () => _evaluateSelection(GhostMode.personalBestActivity),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Matched Run Preview or Calm Empty State
          if (_selectedMode != GhostMode.off) ...[
            if (match != null)
              _GhostMatchCard(run: match)
            else if (explanation != null)
              _GhostEmptyStateCard(message: explanation),
            const SizedBox(height: AppSpacing.s16),
          ],

          // Confirmation Action Button (min 48dp target)
          PrimaryButton(
            label: _selectedMode == GhostMode.off ? 'Confirm' : 'Set ghost',
            onPressed: _applySelection,
          ),
        ],
      ),
    );
  }
}

class _ModeRadioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeRadioTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.br16,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.surface2,
            borderRadius: AppRadius.br16,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.onAccent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppText.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostMatchCard extends StatelessWidget {
  final RunLogEntry run;

  const _GhostMatchCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final distKm = run.distanceM / 1000.0;
    final paceSec = distKm > 0 ? (run.movingSeconds / distKm).round() : 0;
    final paceMin = paceSec ~/ 60;
    final paceRemSec = paceSec % 60;
    final formattedPace = "$paceMin'${paceRemSec.toString().padLeft(2, '0')}\"";

    final totalMin = run.movingSeconds ~/ 60;
    final totalSec = run.movingSeconds % 60;
    final formattedDuration =
        '${totalMin.toString().padLeft(2, '0')}:${totalSec.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_run_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                'Matched past run',
                style: AppText.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${run.startedAt.day}/${run.startedAt.month}/${run.startedAt.year}',
                style: AppText.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'Distance',
                value: '${distKm.toStringAsFixed(2)} km',
              ),
              _StatItem(label: 'Duration', value: formattedDuration),
              _StatItem(label: 'Avg Pace', value: formattedPace),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppText.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GhostEmptyStateCard extends StatelessWidget {
  final String message;

  const _GhostEmptyStateCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
