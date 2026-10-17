import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../services/export_service.dart';
import '../../coach/llm_coach_service.dart';
import '../../../ui/ui.dart';
import '../../history/widgets/run_share_card_modal.dart';

/// Modal bottom sheet presented upon completing a run session.
/// Redesigned as a high-impact post-run victory card with athletic stat grid,
/// AI Coach debrief card, territory map vector thumbnail, and share card export.
class SummarySheet extends StatelessWidget {
  final double distanceKm;
  final int durationSeconds;
  final int territoriesClaimed;
  final RunnerProfile profile;
  final LLMCoachService coachService;
  final List<LatLng>? routePoints;
  final double? areaSqMeters;
  final String? rejectionReason;

  const SummarySheet({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.territoriesClaimed,
    required this.profile,
    required this.coachService,
    this.routePoints,
    this.areaSqMeters,
    this.rejectionReason,
  });

  static Future<void> show({
    required BuildContext context,
    required double distanceKm,
    required int durationSeconds,
    required int territoriesClaimed,
    required RunnerProfile profile,
    required LLMCoachService coachService,
    List<LatLng>? routePoints,
    double? areaSqMeters,
    String? rejectionReason,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SummarySheet(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        territoriesClaimed: territoriesClaimed,
        profile: profile,
        coachService: coachService,
        routePoints: routePoints,
        areaSqMeters: areaSqMeters,
        rejectionReason: rejectionReason,
      ),
    );
  }

  String _formatPace() {
    if (distanceKm <= 0) return "--'--\"";
    final double pace = (durationSeconds / 60.0) / distanceKm;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();
    return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"";
  }

  String _formatDuration() {
    final int minutes = durationSeconds ~/ 60;
    final int seconds = durationSeconds % 60;
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int remainingMins = minutes % 60;
      return '${hours}h ${remainingMins.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatArea() {
    final double effectiveArea = areaSqMeters ?? (territoriesClaimed * 15000.0);
    if (effectiveArea >= 10000) {
      return '${(effectiveArea / 1000000.0).toStringAsFixed(2)} km²';
    }
    return '${effectiveArea.toStringAsFixed(0)} m²';
  }

  int _estimateCalories() {
    // Athletic benchmark: ~62 kcal per km for average runner
    return (distanceKm * 62).round();
  }

  @override
  Widget build(BuildContext context) {
    final effectivePoints = routePoints ?? [];
    final effectiveArea = areaSqMeters ?? (territoriesClaimed * 15000.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        MediaQuery.paddingOf(context).bottom + AppSpacing.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header row with Victory or Rejection Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (rejectionReason != null ? AppColors.rival : AppColors.accent).withValues(alpha: 0.15),
                      borderRadius: AppSpacing.br12,
                      border: Border.all(color: (rejectionReason != null ? AppColors.rival : AppColors.accent).withValues(alpha: 0.35)),
                    ),
                    child: Icon(
                      rejectionReason != null ? Icons.cancel_outlined : Icons.emoji_events_rounded,
                      color: rejectionReason != null ? AppColors.rival : AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rejectionReason != null ? 'RUN REJECTED' : 'CONQUEST COMPLETE',
                        style: AppText.headingSmall.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: rejectionReason != null ? AppColors.rival : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.username.toUpperCase()} • ${profile.faction.toUpperCase()}',
                        style: AppText.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          if (rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.rival.withValues(alpha: 0.12),
                borderRadius: AppSpacing.br12,
                border: Border.all(color: AppColors.rival.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.rival, size: 20),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SERVER REJECTION REASON',
                          style: AppText.label.copyWith(
                            color: AppColors.rival,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rejectionReason!,
                          style: AppText.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.s16),

          // High Impact 4-Metric Athletic Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br20,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('DISTANCE', '${distanceKm.toStringAsFixed(2)} km', AppColors.accent),
                Container(width: 1, height: 36, color: AppColors.border),
                _buildMetricColumn('TIME', _formatDuration(), Colors.white),
                Container(width: 1, height: 36, color: AppColors.border),
                _buildMetricColumn('AVG PACE', '${_formatPace()}/km', Colors.white),
                Container(width: 1, height: 36, color: AppColors.border),
                _buildMetricColumn('TERRITORY', '+$territoriesClaimed', AppColors.accent),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s14),

          // Territory Map Thumbnail
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: AppSpacing.br16,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _VictoryMapPainter(points: effectivePoints),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: AppSpacing.br8,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'CLAIMED: ${_formatArea()} • ${_estimateCalories()} KCAL',
                        style: AppText.label.copyWith(
                          color: AppColors.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.s14),

          // AI Coach Insight Card
          FutureBuilder<CoachInsight>(
            future: coachService.generateRunInsight(
              distanceKm: distanceKm,
              durationSeconds: durationSeconds,
              hexesClaimed: territoriesClaimed,
              profile: profile,
            ),
            builder: (context, snapshot) {
              final insight = snapshot.data;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br16,
                  border: Border.all(color: AppColors.border),
                ),
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              ),
                              SizedBox(width: AppSpacing.s12),
                              Text('AI Coach analyzing telemetry...', style: AppText.bodySmall),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                'AI COACH DEBRIEF • ${insight?.moodTag.name.toUpperCase() ?? 'COACH'}',
                                style: AppText.label.copyWith(
                                  color: AppColors.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Text(
                            insight?.summary ?? 'Conquest complete! Every closed loop expands your territorial perimeter.',
                            style: AppText.body.copyWith(fontSize: 12.5),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.bgDeep,
                              borderRadius: AppSpacing.br10,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡 ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    insight?.tip ?? 'Keep up the rhythm! Regular runs compound territory sovereignty.',
                                    style: AppText.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.s16),

          // Actions: Share Card Button + Claim & Close Button
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'SHARE CARD',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 0.8),
                  ),
                  onPressed: () {
                    AppMotion.lightTick();
                    RunShareCardModal.show(
                      context: context,
                      distanceKm: distanceKm,
                      durationSeconds: durationSeconds,
                      areaSqMeters: effectiveArea,
                      points: effectivePoints,
                      callsign: profile.username,
                      faction: profile.faction,
                      capturedAt: DateTime.now(),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: PrimaryButton(
                  label: 'CLAIM REWARDS',
                  onPressed: () {
                    AppMotion.heavyBurst();
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          // Secondary Data Export Row (GPX for Strava/Garmin, GeoJSON)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 16, color: AppColors.accent),
                  label: const Text('EXPORT GPX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () async {
                    AppMotion.lightTick();
                    await ExportService().exportAndShareGpx(
                      runTitle: 'Territory Run - ${profile.username}',
                      coordinates: effectivePoints,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                  ),
                  icon: const Icon(Icons.polyline_rounded, size: 16, color: Color(0xFF00E5FF)),
                  label: const Text('EXPORT GEOJSON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () async {
                    AppMotion.lightTick();
                    await ExportService().exportAndShareGeoJson(
                      territories: [
                        Territory(
                          id: 'run_${DateTime.now().millisecondsSinceEpoch}',
                          ownerId: profile.id,
                          polygon: effectivePoints,
                          capturedAt: DateTime.now(),
                          color: AppColors.accent,
                          areaSqMeters: effectiveArea,
                        ),
                      ],
                      runTrack: effectivePoints,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 9.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppText.statSmall.copyWith(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _VictoryMapPainter extends CustomPainter {
  final List<LatLng> points;

  _VictoryMapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawFallbackConquest(canvas, size);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final double latSpan = math.max(maxLat - minLat, 0.0001);
    final double lngSpan = math.max(maxLng - minLng, 0.0001);

    const double padding = 10.0;
    final double usableW = size.width - 2 * padding;
    final double usableH = size.height - 2 * padding;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final double x = padding + ((p.longitude - minLng) / lngSpan) * usableW;
      final double y = padding + (1.0 - ((p.latitude - minLat) / latSpan)) * usableH;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawFallbackConquest(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.32;

    final path = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _VictoryMapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
