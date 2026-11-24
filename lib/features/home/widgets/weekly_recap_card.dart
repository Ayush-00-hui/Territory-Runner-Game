import 'package:flutter/material.dart';

import '../../../models/weekly_recap.dart';
import '../../../services/weekly_recap_service.dart';
import '../../../ui/ui.dart';

/// Card displayed on the Home screen (especially prominent on Sundays)
/// summarizing the runner's weekly distance, area, pace, and territory strength.
class WeeklyRecapCard extends StatefulWidget {
  final WeeklyRecapService? recapService;
  final VoidCallback? onShareRecap;

  const WeeklyRecapCard({super.key, this.recapService, this.onShareRecap});

  @override
  State<WeeklyRecapCard> createState() => _WeeklyRecapCardState();
}

class _WeeklyRecapCardState extends State<WeeklyRecapCard> {
  late final WeeklyRecapService _service;
  WeeklyRecap? _recap;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.recapService ?? WeeklyRecapService();
    _loadRecap();
  }

  Future<void> _loadRecap() async {
    final recap = await _service.computeRecap();
    if (mounted) {
      setState(() {
        _recap = recap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _recap == null) {
      return const SizedBox.shrink();
    }

    final recap = _recap!;
    // Only display if the runner has logged distance or today is Sunday
    final isSunday = DateTime.now().weekday == DateTime.sunday;
    if (recap.totalDistanceKm <= 0 && !isSunday) {
      return const SizedBox.shrink();
    }

    final distStr = recap.totalDistanceKm.toStringAsFixed(1);
    final areaStr = recap.areaGainedSqm.toStringAsFixed(0);
    final delta = recap.distanceDeltaPercent;

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
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'WEEKLY RECAP',
                    style: AppText.micro.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (delta != null && delta.abs() > 0.1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: delta >= 0
                        ? AppColors.mine.withValues(alpha: 0.16)
                        : AppColors.surface2,
                    borderRadius: AppSpacing.br4,
                  ),
                  child: Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% vs last week',
                    style: AppText.micro.copyWith(
                      color: delta >= 0
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          // Main metric
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distStr,
                style: AppText.statLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Text(
                'km total',
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          // Metric grid
          Row(
            children: [
              _metricTile('Runs', '${recap.totalRuns}'),
              _metricTile('Claimed', '$areaStr m²'),
              _metricTile('Best Pace', recap.formattedBestPace),
              _metricTile(
                'Land Strength',
                '${recap.averageTerritoryStrength.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.micro.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            value,
            style: AppText.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
