import 'package:flutter/material.dart';
import '../../../models/runner_profile.dart';
import '../../coach/llm_coach_service.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/widgets/primary_button.dart';

/// Modal bottom sheet presented upon completing a run session.
class SummarySheet extends StatelessWidget {
  final double distanceKm;
  final int durationSeconds;
  final int territoriesClaimed;
  final RunnerProfile profile;
  final LLMCoachService coachService;

  const SummarySheet({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.territoriesClaimed,
    required this.profile,
    required this.coachService,
  });

  static Future<void> show({
    required BuildContext context,
    required double distanceKm,
    required int durationSeconds,
    required int territoriesClaimed,
    required RunnerProfile profile,
    required LLMCoachService coachService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SummarySheet(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        territoriesClaimed: territoriesClaimed,
        profile: profile,
        coachService: coachService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double pace = (distanceKm > 0) ? (durationSeconds / 60.0) / distanceKm : 0.0;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();
    final String paceFormatted = "$paceMin'${paceSec.toString().padLeft(2, '0')}\"/km";

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONQUEST COMPLETE 🏁',
                style: AppText.headingMedium,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryMetricTile(title: 'DISTANCE', value: '${distanceKm.toStringAsFixed(2)} km'),
              _SummaryMetricTile(title: 'TIME', value: '${durationSeconds ~/ 60}m ${durationSeconds % 60}s'),
              _SummaryMetricTile(title: 'AVG PACE', value: paceFormatted),
              _SummaryMetricTile(title: 'TERRITORY', value: '+$territoriesClaimed'),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          FutureBuilder<CoachInsight>(
            future: coachService.generateRunInsight(
              distanceKm: distanceKm,
              durationSeconds: durationSeconds,
              hexesClaimed: territoriesClaimed,
              profile: profile,
            ),
            builder: (context, snapshot) {
              final insight = snapshot.data;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br20,
                  border: AppSpacing.cardBorder,
                ),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.s12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              ),
                              SizedBox(width: AppSpacing.s12),
                              Text(
                                'AI Coach analyzing telemetry...',
                                style: AppText.body,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                'AI COACH INSIGHT (${insight?.moodTag.name.toUpperCase() ?? 'COACH'})',
                                style: AppText.labelAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            insight?.summary ?? 'Great run session! Every closed loop expands your territory footprint.',
                            style: AppText.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s10),
                            decoration: BoxDecoration(
                              color: AppColors.bgDeep,
                              borderRadius: AppSpacing.br12,
                            ),
                            child: Text(
                              "💡 Tip: ${insight?.tip ?? 'Keep up the momentum!'}",
                              style: AppText.body,
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.s20),
          PrimaryButton(
            label: 'Claim Rewards & Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryMetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: AppText.label),
        const SizedBox(height: AppSpacing.s4),
        Text(value, style: AppText.statSmall),
      ],
    );
  }
}
