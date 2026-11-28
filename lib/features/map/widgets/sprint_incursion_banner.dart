import 'package:flutter/material.dart';

import '../../../models/sprint_incursion.dart';
import '../../../ui/ui.dart';
import '../../gameplay/incursion_service.dart';

/// Electric HUD banner displayed during an active dynamic sprint incursion challenge.
class SprintIncursionBanner extends StatefulWidget {
  const SprintIncursionBanner({super.key});

  @override
  State<SprintIncursionBanner> createState() => _SprintIncursionBannerState();
}

class _SprintIncursionBannerState extends State<SprintIncursionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _strobeController;
  final IncursionService _incursionService = IncursionService();

  @override
  void initState() {
    super.initState();
    _strobeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _incursionService.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _incursionService.removeListener(_onStateChanged);
    _strobeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inc = _incursionService.currentIncursion;
    if (inc == null) return const SizedBox.shrink();

    final isRepelled = inc.status == IncursionStatus.repelled;
    final isFailed = inc.status == IncursionStatus.failed;

    Color primaryColor = AppColors.error;
    if (isRepelled) primaryColor = AppColors.success;
    if (isFailed) primaryColor = AppColors.disabled;

    return AnimatedBuilder(
      animation: _strobeController,
      builder: (context, child) {
        final glowAlpha = isRepelled
            ? 0.3
            : (0.2 + 0.3 * _strobeController.value);

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: AppSpacing.br16,
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.85),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: glowAlpha),
                blurRadius: 18.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRepelled
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: primaryColor,
                      size: 22.0,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRepelled
                              ? 'INCURSION REPELLED! (+${inc.rewardXp} XP)'
                              : isFailed
                              ? 'PERIMETER DEFENSE DROPPED'
                              : 'BORDER ALERT: ${inc.rivalFactionName.toUpperCase()}',
                          style: AppText.labelSmall.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          isRepelled
                              ? 'Territory perimeter secured successfully.'
                              : 'Hold pace under ${inc.targetPaceString} to repel!',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (inc.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s10,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: AppSpacing.br8,
                      ),
                      child: Text(
                        '${inc.remainingSeconds}s',
                        style: AppText.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
              if (inc.isActive) ...[
                const SizedBox(height: AppSpacing.s10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: inc.progressFraction,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 6.0,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
