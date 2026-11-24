import 'package:flutter/material.dart';

import '../../../models/tiered_achievement.dart';
import '../../../services/tiered_achievement_service.dart';
import '../../../ui/ui.dart';

/// Modal sheet presenting tiered athletic achievements, progress bars,
/// next badge hints, and the unlock timeline.
class AchievementsSheet extends StatefulWidget {
  final TieredAchievementService? achievementService;

  const AchievementsSheet({super.key, this.achievementService});

  static Future<void> show({
    required BuildContext context,
    TieredAchievementService? achievementService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AchievementsSheet(achievementService: achievementService),
    );
  }

  @override
  State<AchievementsSheet> createState() => _AchievementsSheetState();
}

class _AchievementsSheetState extends State<AchievementsSheet> {
  late final TieredAchievementService _service;
  List<TieredProgress>? _progressList;
  List<AchievementTimelineEntry>? _timeline;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.achievementService ?? TieredAchievementService();
    _loadData();
  }

  Future<void> _loadData() async {
    final progress = await _service.evaluateAllAchievements();
    final timeline = await _service.getTimeline();
    if (mounted) {
      setState(() {
        _progressList = progress;
        _timeline = timeline;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Milestones & Badges',
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
                  'Earn tiered athletic badges through distance, territory claims, consistency, and exploration.',
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s16),
                ...(_progressList ?? []).map(
                  (prog) => _buildAchievementCard(prog),
                ),
                if (_timeline != null && _timeline!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'EARNED TIMELINE',
                    style: AppText.micro.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  ..._timeline!
                      .take(5)
                      .map((entry) => _buildTimelineTile(entry)),
                ],
              ],
            ),
    );
  }

  Widget _buildAchievementCard(TieredProgress prog) {
    final ach = prog.achievement;
    final tierColor = _colorForTier(prog.currentTier);

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
                    ach.title,
                    style: AppText.heading4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (prog.currentTier != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s2,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.16),
                      borderRadius: AppSpacing.br4,
                    ),
                    child: Text(
                      prog.currentTier!.label.toUpperCase(),
                      style: AppText.micro.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              ach.description,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s12),
            ClipRRect(
              borderRadius: AppSpacing.br4,
              child: LinearProgressIndicator(
                value: prog.progressFraction,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatMetric(prog.currentValue)} ${ach.metricUnit}',
                  style: AppText.label.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  prog.nextBadgeHint,
                  style: AppText.micro.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineTile(AchievementTimelineEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: _colorForTier(entry.tier),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              '${entry.title} (${entry.tier.label})',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${entry.unlockedAt.day}/${entry.unlockedAt.month}/${entry.unlockedAt.year}',
            style: AppText.micro.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Color _colorForTier(AchievementTier? tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return AppColors.gold;
      case AchievementTier.silver:
        return AppColors.textSecondary;
      case AchievementTier.gold:
        return AppColors.gold;
      case AchievementTier.platinum:
        return AppColors.accent;
      case null:
        return AppColors.textMuted;
    }
  }

  String _formatMetric(double val) {
    if (val >= 1000.0) return val.toStringAsFixed(0);
    return val.toStringAsFixed(1);
  }
}
