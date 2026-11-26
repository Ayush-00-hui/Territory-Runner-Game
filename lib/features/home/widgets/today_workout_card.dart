import 'package:flutter/material.dart';

import '../../../models/interval_workout.dart';
import '../../../models/training_plan.dart';
import '../../../services/training_plan_service.dart';
import '../../../ui/ui.dart';
import '../../training/training_plans_sheet.dart';

/// Home screen card displaying today's (or next up) structured workout session.
/// Calibrated for zero-shame scheduling: never displays missed badges or red penalties.
class TodayWorkoutCard extends StatefulWidget {
  final TrainingPlanService? trainingService;
  final ValueChanged<IntervalWorkoutPlan?> onStartWorkout;
  final ValueChanged<PlanWorkoutDay>? onStartWorkoutDay;

  const TodayWorkoutCard({
    super.key,
    this.trainingService,
    required this.onStartWorkout,
    this.onStartWorkoutDay,
  });

  @override
  State<TodayWorkoutCard> createState() => _TodayWorkoutCardState();
}

class _TodayWorkoutCardState extends State<TodayWorkoutCard> {
  late final TrainingPlanService _service;
  UserPlanEnrollment? _enrollment;
  TrainingPlan? _plan;
  PlanWorkoutDay? _nextWorkout;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.trainingService ?? TrainingPlanService();
    TrainingPlanService.revisionNotifier.addListener(_onPlanRevisionChanged);
    _loadPlanData();
  }

  void _onPlanRevisionChanged() {
    if (mounted) {
      _loadPlanData();
    }
  }

  @override
  void dispose() {
    TrainingPlanService.revisionNotifier.removeListener(_onPlanRevisionChanged);
    super.dispose();
  }

  Future<void> _loadPlanData() async {
    final enrollment = await _service.getActiveEnrollment();
    if (!mounted) return;

    if (enrollment != null) {
      final plan = _service.getPlanById(enrollment.planId);
      final next = await _service.getNextWorkout();
      if (mounted) {
        setState(() {
          _enrollment = enrollment;
          _plan = plan;
          _nextWorkout = next;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _enrollment = null;
          _plan = null;
          _nextWorkout = null;
          _isLoading = false;
        });
      }
    }
  }

  void _openPlansSheet() {
    TrainingPlansSheet.show(
      context: context,
      trainingService: _service,
      onPlanChanged: () => _loadPlanData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_enrollment == null || _plan == null) {
      return _buildExploreCard();
    }

    if (_nextWorkout == null) {
      return _buildGraduationCard();
    }

    final completedCount = _enrollment!.completedWorkoutIds.length;
    final totalCount = _plan!.totalWorkouts;
    final progressFraction = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_run_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    _plan!.title,
                    style: AppText.label.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openPlansSheet,
                child: Text(
                  'Week ${_nextWorkout!.weekNumber}',
                  style: AppText.label.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            _nextWorkout!.title,
            style: AppText.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _nextWorkout!.description,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s12),
          // Progress bar
          ClipRRect(
            borderRadius: AppSpacing.br4,
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            '$completedCount of $totalCount sessions completed',
            style: AppText.micro.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.s14),
          PrimaryButton(
            label: 'Start Session',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              if (widget.onStartWorkoutDay != null) {
                widget.onStartWorkoutDay!(_nextWorkout!);
              } else {
                widget.onStartWorkout(_nextWorkout!.intervalPlan);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExploreCard() {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: AppSpacing.br8,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Structured Training Plans',
                  style: AppText.heading4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Couch to 5K or Pace Builder with zero-shame scheduling.',
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.accent,
            ),
            onPressed: _openPlansSheet,
            tooltip: 'View training plans',
          ),
        ],
      ),
    );
  }

  Widget _buildGraduationCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.gold,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Plan Completed!',
                style: AppText.heading4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'You graduated from ${_plan!.title}. Take a rest or explore a new milestone.',
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: 'Choose next plan',
            onPressed: _openPlansSheet,
          ),
        ],
      ),
    );
  }
}
