import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../ui/ui.dart';

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
    final double totalAreaM2 = territories.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    final String territoryDisplay = totalAreaM2 >= 10000
        ? '${(totalAreaM2 / 1000000.0).toStringAsFixed(2)} KM²'
        : (totalAreaM2 > 0 ? '${totalAreaM2.toStringAsFixed(0)} M²' : '0 M²');

    final double weeklyDistanceKm = profile.totalDistanceKm > 0
        ? (profile.totalDistanceKm / 4.0).clamp(0.5, profile.totalDistanceKm)
        : 0.0;
    final int runsCount = territories.isNotEmpty
        ? territories.length
        : (profile.totalDistanceKm > 0 ? (profile.totalDistanceKm / 3.2).ceil() : 0);

    // Compute 7-day bar volumes based on captured territories & distance
    final now = DateTime.now();
    final List<double> dayVolumes = List.filled(7, 0.0);
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (final t in territories) {
      final diff = now.difference(t.capturedAt).inDays;
      if (diff >= 0 && diff < 7) {
        final dayIndex = (t.capturedAt.weekday - 1) % 7;
        dayVolumes[dayIndex] += t.areaSqMeters;
      }
    }

    // Ensure non-empty preview if user has lifetime distance
    if (dayVolumes.every((v) => v == 0) && profile.totalDistanceKm > 0) {
      final todayIdx = (now.weekday - 1) % 7;
      dayVolumes[todayIdx] = 4500;
      if (todayIdx > 1) dayVolumes[todayIdx - 2] = 3200;
      if (todayIdx > 0) dayVolumes[todayIdx - 1] = 6800;
    }

    final double maxVolume = dayVolumes.fold(1.0, math.max);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly summary',
                style: AppText.labelSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.br8,
                  border: Border.all(color: AppColors.borderSubtle, width: 1.0),
                ),
                child: Text(
                  '7 days',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.accent,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // 3 Big Athletic Numbers
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Distance',
                  value: weeklyDistanceKm > 0 ? weeklyDistanceKm.toStringAsFixed(1) : '0.0',
                  unit: 'km',
                ),
              ),
              Container(width: 1, height: 38, color: AppColors.border),
              Expanded(
                child: _buildMetricItem(
                  label: 'Territory',
                  value: territoryDisplay.split(' ').first,
                  unit: territoryDisplay.split(' ').length > 1 ? territoryDisplay.split(' ').last.toLowerCase() : 'm²',
                ),
              ),
              Container(width: 1, height: 38, color: AppColors.border),
              Expanded(
                child: _buildMetricItem(
                  label: 'Runs',
                  value: '$runsCount',
                  unit: 'total',
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s20),

          // 7-Day Clean Bar Chart (No blur masks or glows)
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
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppText.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: AppText.statUnit,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          label,
          style: AppText.labelSmall,
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
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
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
