import '../../models/runner_profile.dart';
import '../../services/api_client.dart';
import '../../core/logging/app_logger.dart';

enum CoachMood { celebratory, encouraging, analytical }

class CoachInsight {
  final String summary;
  final String tip;
  final CoachMood moodTag;

  const CoachInsight({
    required this.summary,
    required this.tip,
    required this.moodTag,
  });

  factory CoachInsight.fallback({
    required double distanceKm,
    required int hexesClaimed,
    required int durationSeconds,
  }) {
    final double pace = (distanceKm > 0)
        ? (durationSeconds / 60.0) / distanceKm
        : 0.0;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();

    return CoachInsight(
      summary:
          "Outstanding run! You logged ${distanceKm.toStringAsFixed(2)} km in ${(durationSeconds / 60).toStringAsFixed(1)} min and conquered $hexesClaimed new territory sectors.",
      tip:
          "Pace recorded at $paceMin'${paceSec.toString().padLeft(2, '0')}\"/km. Keep your cadence consistent around 170 SPM for optimal energy conservation during multi-hex loops.",
      moodTag: hexesClaimed > 5 ? CoachMood.celebratory : CoachMood.encouraging,
    );
  }
}

/// LLM Post-Run Coach powered by Go backend Gemini proxy
///
/// Security: The Gemini API key never touches the mobile client. All LLM calls
/// are securely proxied through POST /v1/runs/{id}/coach on the Go server.
/// Resilient: If the server is offline or unreachable, the client seamlessly falls
/// back to the deterministic on-device athletic heuristic without crashing.
class LLMCoachService {
  static final LLMCoachService _instance = LLMCoachService._internal();

  ApiClient _apiClient = ApiClient();

  factory LLMCoachService({ApiClient? apiClient}) {
    if (apiClient != null) {
      _instance._apiClient = apiClient;
    }
    return _instance;
  }

  LLMCoachService._internal();

  /// Evaluates a completed run session and produces tailored coaching insights
  Future<CoachInsight> generateRunInsight({
    String? runId,
    required double distanceKm,
    required int durationSeconds,
    required int hexesClaimed,
    required RunnerProfile profile,
    String? currentPaceFormatted,
  }) async {
    final targetRunId = runId ?? 'run_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final res = await _apiClient.getRunCoachInsight(
        runId: targetRunId,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        hexesClaimed: hexesClaimed,
        currentPace: currentPaceFormatted,
        level: profile.level,
        streakDays: profile.currentStreak,
        totalDistanceKm: profile.totalDistanceKm,
      );

      final summary = res['summary'] as String? ?? '';
      final tip = res['tip'] as String? ?? '';
      final moodStr =
          (res['mood_tag'] as String? ??
                  res['moodTag'] as String? ??
                  'encouraging')
              .toLowerCase();

      CoachMood mood = CoachMood.encouraging;
      if (moodStr == 'celebratory') mood = CoachMood.celebratory;
      if (moodStr == 'analytical') mood = CoachMood.analytical;

      if (summary.isNotEmpty && tip.isNotEmpty) {
        return CoachInsight(summary: summary, tip: tip, moodTag: mood);
      }
    } catch (e) {
      AppLogger.info(
        'Backend coach proxy unavailable ($e); using smart on-device coaching heuristic.',
        tag: 'LLMCoachService',
      );
    }

    return CoachInsight.fallback(
      distanceKm: distanceKm,
      hexesClaimed: hexesClaimed,
      durationSeconds: durationSeconds,
    );
  }
}
