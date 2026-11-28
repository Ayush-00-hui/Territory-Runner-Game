import 'package:flutter/material.dart';

import '../../../models/sprint_incursion.dart';
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

    Color primaryColor = const Color(0xFFEF4444); // Electric crimson
    if (isRepelled) primaryColor = const Color(0xFF10B981); // Emerald
    if (isFailed) primaryColor = const Color(0xFF6B7280);

    return AnimatedBuilder(
      animation: _strobeController,
      builder: (context, child) {
        final glowAlpha = isRepelled
            ? 0.3
            : (0.2 + 0.3 * _strobeController.value);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1115).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16.0),
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
                    padding: const EdgeInsets.all(8.0),
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
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRepelled
                              ? 'INCURSION REPELLED! (+${inc.rewardXp} XP)'
                              : isFailed
                              ? 'PERIMETER COMPROMISED'
                              : 'BORDER BREACH: ${inc.rivalFactionName.toUpperCase()}',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.0,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          isRepelled
                              ? 'Perimeter territory secured successfully.'
                              : 'Hold pace under ${inc.targetPaceString} to repel!',
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (inc.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E242C),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        '${inc.remainingSeconds}s',
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
              if (inc.isActive) ...[
                const SizedBox(height: 10.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: inc.progressFraction,
                    backgroundColor: const Color(0xFF1E242C),
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
