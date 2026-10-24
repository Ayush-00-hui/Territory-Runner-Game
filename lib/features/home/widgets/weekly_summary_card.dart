import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../ui/ui.dart';

/// Athlete Weekly Performance Summary Card
/// Displays real distance, territory area, and run count from the past 7 days.
/// Zero synthetic preview data.
class WeeklySummaryCard extends StatelessWidget {
  final RunnerProfile profile;
  final List<Territory> territories;

  const WeeklySummaryCard({
    super.key,
    required this.profile,
    required this.territories,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const distance = Distance();

    // 1. Filter territories captured in the last 7 days
    final List<Territory> weekTerritories = [];
    final List<double> dayVolumes = List.filled(7, 0.0);
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    double weeklyDistanceKm = 0.0;
    double weeklyAreaM2 = 0.0;

    for (final t in territories) {
      final diff = now.difference(t.capturedAt).inDays;
      if (diff >= 0 && diff < 7) {
        weekTerritories.add(t);
        weeklyAreaM2 += t.areaSqMeters;
        final dayIndex = (t.capturedAt.weekday - 1) % 7;
        dayVolumes[dayIndex] += t.areaSqMeters;

        if (t.polygon.length >= 2) {
          double meters = 0.0;
          for (int i = 0; i < t.polygon.length - 1; i++) {
            meters += distance(t.polygon[i], t.polygon[i + 1]);
          }
          meters += distance(t.polygon.last, t.polygon.first);
          weeklyDistanceKm += meters / 1000.0;
        }
      }
    }

    final int weeklyRunsCount = weekTerritories.length;

    final String territoryDisplay = weeklyAreaM2 >= 10000
        ? '${(weeklyAreaM2 / 1000000.0).toStringAsFixed(2)} km²'
        : (weeklyAreaM2 > 0 ? '${weeklyAreaM2.toStringAsFixed(0)} m²' : '0 m²');

    final double maxVolume = dayVolumes.fold(1.0, math.max);
    final bool hasWeeklyData = weeklyRunsCount > 0 || weeklyAreaM2 > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 Big Real Athletic Numbers
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Distance',
                  value: weeklyDistanceKm > 0
                      ? weeklyDistanceKm.toStringAsFixed(1)
                      : '0.0',
                  unit: 'km',
                ),
              ),
              Container(width: 1, height: 38, color: AppColors.borderSubtle),
              Expanded(
                child: _buildMetricItem(
                  label: 'Territory',
                  value: territoryDisplay.split(' ').first,
                  unit: territoryDisplay.split(' ').length > 1
                      ? territoryDisplay.split(' ').last.toLowerCase()
                      : 'm²',
                ),
              ),
              Container(width: 1, height: 38, color: AppColors.borderSubtle),
              Expanded(
                child: _buildMetricItem(
                  label: 'Runs',
                  value: '$weeklyRunsCount',
                  unit: 'total',
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s20),

          // 7-Day Clean Bar Chart (Real data only)
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _WeeklyBarChartPainter(
                dayVolumes: dayVolumes,
                maxVolume: maxVolume,
                dayNames: dayNames,
                currentDayIndex: (now.weekday - 1) % 7,
              ),
            ),
          ),

          if (!hasWeeklyData) ...[
            const SizedBox(height: AppSpacing.s12),
            Center(
              child: Text(
                'No runs logged this week. Start a run to begin.',
                style: AppText.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppText.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              Text(unit, style: AppText.statUnit),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          label,
          style: AppText.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _WeeklyBarChartPainter extends CustomPainter {
  final List<double> dayVolumes;
  final double maxVolume;
  final List<String> dayNames;
  final int currentDayIndex;

  _WeeklyBarChartPainter({
    required this.dayVolumes,
    required this.maxVolume,
    required this.dayNames,
    required this.currentDayIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double barWidth = 14.0;
    const double labelHeight = 18.0;
    final double chartHeight = size.height - labelHeight;
    final double spacing = (size.width - (7 * barWidth)) / 8;

    final trackPaint = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.fill;

    final activeBarPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;

    final pastBarPaint = Paint()
      ..color = AppColors.accentContainer
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      final double x = spacing + i * (barWidth + spacing);
      final double trackY = 0;
      final double trackHeight = chartHeight;

      // Draw background track
      final trackRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, trackY, barWidth, trackHeight),
        const Radius.circular(7),
      );
      canvas.drawRRect(trackRRect, trackPaint);

      // Draw active fill (crisp, zero blur or glow)
      final double val = dayVolumes[i];
      if (val > 0) {
        final double fillFraction = (val / maxVolume).clamp(0.18, 1.0);
        final double barH = chartHeight * fillFraction;
        final double barY = chartHeight - barH;

        final barRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, barY, barWidth, barH),
          const Radius.circular(7),
        );

        final paint = (i == currentDayIndex) ? activeBarPaint : pastBarPaint;
        canvas.drawRRect(barRRect, paint);
      }

      // Draw day label
      final isToday = i == currentDayIndex;
      final textSpan = TextSpan(
        text: dayNames[i],
        style: TextStyle(
          color: isToday ? AppColors.accent : AppColors.textMuted,
          fontSize: 10,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
          fontFamily: AppText.fontFamily,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth + 8);

      final double textX = x + (barWidth - textPainter.width) / 2;
      final double textY = chartHeight + 4;
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter oldDelegate) {
    return oldDelegate.dayVolumes != dayVolumes ||
        oldDelegate.maxVolume != maxVolume ||
        oldDelegate.currentDayIndex != currentDayIndex;
  }
}
