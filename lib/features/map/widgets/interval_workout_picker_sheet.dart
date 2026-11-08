import 'package:flutter/material.dart';

import '../../../models/interval_workout.dart';
import '../../../services/interval_workout_service.dart';
import '../../../ui/ui.dart';

/// Bottom sheet allowing selection of "Free run" or an interval workout plan.
class IntervalWorkoutPickerSheet extends StatefulWidget {
  final IntervalWorkoutPlan? currentPlan;
  final ValueChanged<IntervalWorkoutPlan?> onPlanSelected;
  final IntervalWorkoutService? workoutService;

  const IntervalWorkoutPickerSheet({
    super.key,
    required this.currentPlan,
    required this.onPlanSelected,
    this.workoutService,
  });

  static Future<void> show({
    required BuildContext context,
    IntervalWorkoutPlan? currentPlan,
    required ValueChanged<IntervalWorkoutPlan?> onPlanSelected,
    IntervalWorkoutService? workoutService,
  }) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => IntervalWorkoutPickerSheet(
        currentPlan: currentPlan,
        onPlanSelected: onPlanSelected,
        workoutService: workoutService,
      ),
    );
  }

  @override
  State<IntervalWorkoutPickerSheet> createState() =>
      _IntervalWorkoutPickerSheetState();
}

class _IntervalWorkoutPickerSheetState
    extends State<IntervalWorkoutPickerSheet> {
  late final IntervalWorkoutService _service;
  IntervalWorkoutPlan? _selectedPlan;
  bool _isCustomBuilderOpen = false;

  // Custom builder state
  int _customWarmupMin = 3;
  int _customRepeats = 6;
  int _customRunSec = 60;
  int _customWalkSec = 90;
  int _customCooldownMin = 2;

  @override
  void initState() {
    super.initState();
    _service = widget.workoutService ?? IntervalWorkoutService();
    _selectedPlan = widget.currentPlan;
  }

  void _applySelection(IntervalWorkoutPlan? plan) {
    widget.onPlanSelected(plan);
    Navigator.of(context).pop();
  }

  void _buildAndApplyCustom() {
    final customPlan = IntervalWorkoutPlan.custom(
      warmupSeconds: _customWarmupMin * 60,
      repeats: _customRepeats,
      runSeconds: _customRunSec,
      walkSeconds: _customWalkSec,
      cooldownSeconds: _customCooldownMin * 60,
    );
    _service.saveCustomPlan(customPlan);
    _applySelection(customPlan);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.80;

    return AppSheet(
      title: 'Workout plan',
      subtitle: 'Structured interval routines with audio and haptic cues',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isCustomBuilderOpen) ...[
                // Option 1: Free Run (Default)
                _PlanTile(
                  title: 'Free run',
                  subtitle: 'Open run without structured interval pacing',
                  badge: 'Standard',
                  isSelected: _selectedPlan == null,
                  onTap: () => setState(() => _selectedPlan = null),
                ),
                const SizedBox(height: AppSpacing.s8),

                // Option 2: Beginner Run-Walk
                _PlanTile(
                  title: 'Beginner run-walk',
                  subtitle: '8 x (1 min run / 2 min walk) with warm-up',
                  badge: '29 min',
                  isSelected:
                      _selectedPlan?.id ==
                      IntervalWorkoutPlan.beginnerRunWalk.id,
                  onTap: () => setState(
                    () => _selectedPlan = IntervalWorkoutPlan.beginnerRunWalk,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),

                // Option 3: 5x (2 min fast + 1 min easy)
                _PlanTile(
                  title: '5x (2 min fast + 1 min easy)',
                  subtitle: 'High-intensity intervals for speed endurance',
                  badge: '23 min',
                  isSelected:
                      _selectedPlan?.id ==
                      IntervalWorkoutPlan.fiveByTwoFastOneEasy.id,
                  onTap: () => setState(
                    () => _selectedPlan =
                        IntervalWorkoutPlan.fiveByTwoFastOneEasy,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),

                // Option 4: Custom Builder Trigger
                _PlanTile(
                  title: 'Custom interval builder',
                  subtitle: 'Configure your own repeats and phase targets',
                  badge: 'Custom',
                  isSelected: _selectedPlan?.id == 'custom_workout',
                  onTap: () => setState(() => _isCustomBuilderOpen = true),
                ),
                const SizedBox(height: AppSpacing.s16),

                PrimaryButton(
                  label: _selectedPlan == null
                      ? 'Confirm Free run'
                      : 'Set ${_selectedPlan!.name}',
                  onPressed: () => _applySelection(_selectedPlan),
                ),
              ] else ...[
                // Custom Workout Builder View
                _CustomBuilderHeader(
                  onBack: () => setState(() => _isCustomBuilderOpen = false),
                ),
                const SizedBox(height: AppSpacing.s12),

                _NumberStepperRow(
                  label: 'Warm up duration',
                  valueDisplay: '$_customWarmupMin min',
                  onDecrement: _customWarmupMin > 0
                      ? () => setState(() => _customWarmupMin--)
                      : null,
                  onIncrement: () => setState(() => _customWarmupMin++),
                ),
                const SizedBox(height: AppSpacing.s8),

                _NumberStepperRow(
                  label: 'Number of repeats',
                  valueDisplay: '$_customRepeats cycles',
                  onDecrement: _customRepeats > 1
                      ? () => setState(() => _customRepeats--)
                      : null,
                  onIncrement: () => setState(() => _customRepeats++),
                ),
                const SizedBox(height: AppSpacing.s8),

                _NumberStepperRow(
                  label: 'Run / Work interval',
                  valueDisplay: '$_customRunSec sec',
                  onDecrement: _customRunSec > 15
                      ? () => setState(() => _customRunSec -= 15)
                      : null,
                  onIncrement: () => setState(() => _customRunSec += 15),
                ),
                const SizedBox(height: AppSpacing.s8),

                _NumberStepperRow(
                  label: 'Walk / Rest recovery',
                  valueDisplay: '$_customWalkSec sec',
                  onDecrement: _customWalkSec > 15
                      ? () => setState(() => _customWalkSec -= 15)
                      : null,
                  onIncrement: () => setState(() => _customWalkSec += 15),
                ),
                const SizedBox(height: AppSpacing.s8),

                _NumberStepperRow(
                  label: 'Cool down duration',
                  valueDisplay: '$_customCooldownMin min',
                  onDecrement: _customCooldownMin > 0
                      ? () => setState(() => _customCooldownMin--)
                      : null,
                  onIncrement: () => setState(() => _customCooldownMin++),
                ),
                const SizedBox(height: AppSpacing.s16),

                PrimaryButton(
                  label: 'Save & Start Workout',
                  onPressed: _buildAndApplyCustom,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle. Duration $badge.',
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
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br8,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomBuilderHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _CustomBuilderHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          color: AppColors.textSecondary,
          tooltip: 'Back to workout plans',
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(
          'Custom interval builder',
          style: AppText.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NumberStepperRow extends StatelessWidget {
  final String label;
  final String valueDisplay;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _NumberStepperRow({
    required this.label,
    required this.valueDisplay,
    this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                color: onDecrement != null
                    ? AppColors.textSecondary
                    : AppColors.disabled,
                tooltip: 'Decrease',
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 64),
                alignment: Alignment.center,
                child: Text(
                  valueDisplay,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                color: AppColors.accent,
                tooltip: 'Increase',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
