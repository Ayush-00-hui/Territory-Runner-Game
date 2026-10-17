import 'package:flutter/material.dart';
import '../../../models/runner_profile.dart';
import '../../../ui/ui.dart';

class HomeHeader extends StatefulWidget {
  final RunnerProfile profile;

  const HomeHeader({
    super.key,
    required this.profile,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _factionColor(String faction) {
    if (faction.contains('Solar')) return const Color(0xFFFF9100);
    if (faction.contains('Quantum')) return const Color(0xFF7058D4);
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final factionColor = _factionColor(widget.profile.faction);
    final callsign = widget.profile.username.isNotEmpty
        ? widget.profile.username.toUpperCase()
        : 'RUNNER';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle with athletic initial
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 1.8),
            boxShadow: AppSpacing.subtleElevation,
          ),
          child: Center(
            child: Text(
              callsign.isNotEmpty ? callsign[0] : 'R',
              style: AppText.headingMedium.copyWith(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),

        // Callsign and Faction / Level badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                callsign,
                style: AppText.headingMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  // Level capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppSpacing.br8,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'LVL ${widget.profile.level}',
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  // Faction tag
                  if (widget.profile.faction.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: factionColor.withValues(alpha: 0.15),
                          borderRadius: AppSpacing.br8,
                          border: Border.all(color: factionColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          widget.profile.faction.toUpperCase(),
                          style: AppText.label.copyWith(
                            color: factionColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Streak badge with pulsing fire
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.rival.withValues(alpha: 0.15),
              borderRadius: AppSpacing.br14,
              border: Border.all(color: AppColors.rival.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.rival,
                  size: 18,
                ),
                const SizedBox(width: 3),
                Text(
                  '${widget.profile.currentStreak}',
                  style: AppText.statMedium.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Live Sync status chip
        const SyncChip(),
      ],
    );
  }
}
