import 'package:flutter/material.dart';

import '../../../models/lap_split.dart';
import '../../../ui/ui.dart';

/// Clean athletic table presenting completed 1 km/mile lap splits in the run summary.
class LapSplitsTable extends StatelessWidget {
  final List<LapSplit> laps;

  const LapSplitsTable({super.key, required this.laps});

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) return const SizedBox.shrink();

    // Find fastest lap to highlight subtly
    int? fastestLapIndex;
    double minPace = double.infinity;
    for (int i = 0; i < laps.length; i++) {
      if (laps[i].paceSecondsPerKm > 0 && laps[i].paceSecondsPerKm < minPace) {
        minPace = laps[i].paceSecondsPerKm;
        fastestLapIndex = i;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppSpacing.br12,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Lap Splits',
                style: AppText.heading4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${laps.length} laps',
                style: AppText.label.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          // Header Row
          Row(
            children: [
              _headerCell('Lap', flex: 1),
              _headerCell('Split', flex: 2, align: TextAlign.right),
              _headerCell('Pace', flex: 2, align: TextAlign.right),
              _headerCell('Elev', flex: 2, align: TextAlign.right),
            ],
          ),
          const Divider(color: AppColors.borderSubtle, height: AppSpacing.s16),
          // Data Rows
          ...laps.asMap().entries.map((entry) {
            final idx = entry.key;
            final lap = entry.value;
            final isFastest = idx == fastestLapIndex && laps.length > 1;

            return Semantics(
              label:
                  'Lap ${lap.lapNumber}: time ${lap.formattedDuration}, pace ${lap.formattedPace} per kilometer',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          Text(
                            '${lap.lapNumber}',
                            style: AppText.bodySmall.copyWith(
                              color: isFastest
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                              fontWeight: isFastest
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          if (isFastest) ...[
                            const SizedBox(width: AppSpacing.s4),
                            const Icon(
                              Icons.bolt_rounded,
                              size: 12,
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        lap.formattedDuration,
                        textAlign: TextAlign.right,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        lap.formattedPace,
                        textAlign: TextAlign.right,
                        style: AppText.bodySmall.copyWith(
                          color: isFastest
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '+${lap.elevationGainMeters.round()} m',
                        textAlign: TextAlign.right,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(
    String title, {
    required int flex,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        textAlign: align,
        style: AppText.micro.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
