import 'package:flutter/material.dart';

import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';

/// Victory Header showing drag handle, completion/rejection badge, headline, and close button.
class SummaryVictoryHeader extends StatelessWidget {
  final String headline;
  final String? rejectionReason;
  final RunnerProfile? profile;
  final VoidCallback onClose;

  const SummaryVictoryHeader({
    super.key,
    required this.headline,
    this.rejectionReason,
    this.profile,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRejected = rejectionReason != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Drag Handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s14),

        // 2. Status Badge & Close Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isRejected ? AppColors.error : AppColors.accent)
                          .withValues(alpha: 0.15),
                      borderRadius: AppSpacing.br8,
                      border: Border.all(
                        color: (isRejected ? AppColors.error : AppColors.accent)
                            .withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRejected
                              ? Icons.warning_rounded
                              : Icons.check_circle_rounded,
                          size: 13,
                          color: isRejected
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isRejected ? 'Run rejected' : 'Run complete',
                          style: TextStyle(
                            color: isRejected
                                ? AppColors.error
                                : AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (profile != null && profile!.username.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Text(
                        profile!.faction.isNotEmpty
                            ? '${profile!.username} • ${profile!.faction}'
                            : profile!.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Close summary',
              child: GestureDetector(
                onTap: () {
                  AppMotion.selectionTick();
                  onClose();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s12),

        // 3. Headline Sentence
        Text(
          headline,
          style: AppText.headingSmall.copyWith(
            color: isRejected ? AppColors.error : AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),

        // Rejection Reason Details
        if (isRejected) ...[
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppSpacing.br12,
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    rejectionReason!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
