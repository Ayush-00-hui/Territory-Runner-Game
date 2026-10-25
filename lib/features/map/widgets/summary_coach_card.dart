import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/runner_profile.dart';
import '../../../services/export_service.dart';
import '../../../ui/ui.dart';
import '../../coach/llm_coach_service.dart';
import '../../history/widgets/run_share_card_modal.dart';

/// Coach insight card and action buttons (Share run, Export GPX, Done).
class SummaryCoachCard extends StatelessWidget {
  final double distanceKm;
  final int durationSeconds;
  final int territoriesClaimed;
  final double effectiveArea;
  final List<LatLng> routePoints;
  final RunnerProfile profile;
  final LLMCoachService coachService;
  final VoidCallback onDone;

  const SummaryCoachCard({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.territoriesClaimed,
    required this.effectiveArea,
    required this.routePoints,
    required this.profile,
    required this.coachService,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI Coach Insight Card
        FutureBuilder<CoachInsight>(
          future: coachService.generateRunInsight(
            distanceKm: distanceKm,
            durationSeconds: durationSeconds,
            territoriesClaimed: territoriesClaimed,
            profile: profile,
          ),
          builder: (context, snapshot) {
            final insight = snapshot.data;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.br16,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            SizedBox(width: AppSpacing.s10),
                            Flexible(
                              child: Text(
                                'Coach analyzing run stats...',
                                style: AppText.bodySmall,
                              ),
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
                            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 15),
                            const SizedBox(width: AppSpacing.s6),
                            Expanded(
                              child: Text(
                                'Coach debrief • ${insight?.moodTag.name.toLowerCase() ?? 'coach'}',
                                style: AppText.label.copyWith(
                                  color: AppColors.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        Text(
                          insight?.summary ?? 'Run complete. Every closed loop expands your territory.',
                          style: AppText.body.copyWith(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: AppSpacing.br8,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.tips_and_updates_outlined, size: 13, color: AppColors.accent),
                              const SizedBox(width: AppSpacing.s6),
                              Expanded(
                                child: Text(
                                  insight?.tip ?? 'Keep up the rhythm! Regular runs compound your territory.',
                                  style: AppText.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.s16),

        // Secondary Actions (Share run + Export GPX)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text(
                  'Share run',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: () {
                  AppMotion.lightTick();
                  RunShareCardModal.show(
                    context: context,
                    distanceKm: distanceKm,
                    durationSeconds: durationSeconds,
                    areaSqMeters: effectiveArea,
                    points: routePoints,
                    callsign: profile.username.isNotEmpty ? profile.username : 'RUNNER',
                    faction: profile.faction.isNotEmpty ? profile.faction : 'SOLO',
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text(
                  'Export GPX',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                onPressed: () async {
                  AppMotion.lightTick();
                  final file = await ExportService().exportAndShareGpx(
                    runTitle: 'Territory Run - ${profile.username}',
                    coordinates: routePoints,
                  );
                  if (context.mounted) {
                    AppToast.show(
                      context,
                      'Exported to ${file.path}',
                      icon: Icons.check_circle_rounded,
                      type: AppToastType.success,
                    );
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s10),

        // Primary "Done" Button
        PrimaryButton(
          label: 'Done',
          onPressed: onDone,
        ),
      ],
    );
  }
}
