import 'package:flutter/material.dart';
import '../../gameplay/guardian_challenge_service.dart';

/// Floating HUD chip displaying real-time lead or lag distance against the Sector Guardian ghost boss.
class SectorGuardianChip extends StatefulWidget {
  const SectorGuardianChip({super.key});

  @override
  State<SectorGuardianChip> createState() => _SectorGuardianChipState();
}

class _SectorGuardianChipState extends State<SectorGuardianChip> {
  final GuardianChallengeService _service = GuardianChallengeService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isChallengeActive || _service.activeGuardian == null) {
      return const SizedBox.shrink();
    }

    final guardian = _service.activeGuardian!;
    final isLeading = _service.isUserLeading;
    final deltaMeters = _service.userLeadDistanceMeters.abs().round();
    final deltaText = isLeading ? '+$deltaMeters m Lead' : '-$deltaMeters m Trailing';
    final themeColor = isLeading ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: themeColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.35),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLeading ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: themeColor,
            size: 16.0,
          ),
          const SizedBox(width: 6.0),
          Text(
            'VS ${guardian.guardianName}: ',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            deltaText,
            style: TextStyle(
              color: themeColor,
              fontSize: 12.0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
