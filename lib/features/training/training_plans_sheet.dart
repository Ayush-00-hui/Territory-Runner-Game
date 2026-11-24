import 'package:flutter/material.dart';

import '../../models/training_plan.dart';
import '../../services/training_plan_service.dart';
import '../../ui/ui.dart';

/// Modal sheet for discovering, previewing, and enrolling in training plans.
class TrainingPlansSheet extends StatefulWidget {
  final TrainingPlanService? trainingService;
  final VoidCallback? onPlanChanged;

  const TrainingPlansSheet({
    super.key,
    this.trainingService,
    this.onPlanChanged,
  });

  static Future<void> show({
    required BuildContext context,
    TrainingPlanService? trainingService,
    VoidCallback? onPlanChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TrainingPlansSheet(
        trainingService: trainingService,
        onPlanChanged: onPlanChanged,
      ),
    );
  }

  @override
  State<TrainingPlansSheet> createState() => _TrainingPlansSheetState();
}

class _TrainingPlansSheetState extends State<TrainingPlansSheet> {
  late final TrainingPlanService _service;
  UserPlanEnrollment? _enrollment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.trainingService ?? TrainingPlanService();
    _loadEnrollment();
  }

  Future<void> _loadEnrollment() async {
    final enrollment = await _service.getActiveEnrollment();
    if (mounted) {
      setState(() {
        _enrollment = enrollment;
        _isLoading = false;
      });
    }
  }

  Future<void> _enroll(String planId) async {
    await _service.enrollInPlan(planId);
    widget.onPlanChanged?.call();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _unenroll() async {
    await _service.unenroll();
    widget.onPlanChanged?.call();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _service.getAvailablePlans();

    return AppSheet(
      title: 'Training Plans',
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.s32),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Structured progressions with shame-free scheduling. Missed sessions simply move forward whenever you are ready.',
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s16),
                ...plans.map((plan) => _buildPlanCard(plan)),
                if (_enrollment != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Center(
                    child: TextButton(
                      onPressed: _unenroll,
                      child: Text(
                        'Leave active plan',
                        style: AppText.label.copyWith(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildPlanCard(TrainingPlan plan) {
    final isCurrent = _enrollment?.planId == plan.id;
    final completedCount = isCurrent
        ? _enrollment!.completedWorkoutIds.length
        : 0;
    final total = plan.totalWorkouts;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: AppText.heading4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: AppSpacing.br4,
                    ),
                    child: Text(
                      'ACTIVE',
                      style: AppText.micro.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              plan.subtitle,
              style: AppText.label.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              plan.description,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    plan.targetAudience,
                    style: AppText.micro.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            if (isCurrent) ...[
              Text(
                'Progress: $completedCount of $total sessions',
                style: AppText.label.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s6),
              LinearProgressIndicator(
                value: total > 0 ? completedCount / total : 0.0,
                backgroundColor: AppColors.surface2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.accent,
                ),
                minHeight: 4,
              ),
            ] else ...[
              PrimaryButton(
                label: 'Enroll in ${plan.title}',
                onPressed: () => _enroll(plan.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
