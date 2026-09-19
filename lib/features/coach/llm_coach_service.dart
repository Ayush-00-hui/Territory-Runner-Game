import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/runner_profile.dart';

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
    final double pace = (distanceKm > 0) ? (durationSeconds / 60.0) / distanceKm : 0.0;
    final int paceMin = pace.floor();
    final int paceSec = ((pace - paceMin) * 60).round();

    return CoachInsight(
      summary: "Outstanding run! You logged ${distanceKm.toStringAsFixed(2)} km in ${(durationSeconds / 60).toStringAsFixed(1)} min and conquered $hexesClaimed new territory sectors.",
      tip: "Pace recorded at $paceMin'${paceSec.toString().padLeft(2, '0')}\"/km. Keep your cadence consistent around 170 SPM for optimal energy conservation during multi-hex loops.",
      moodTag: hexesClaimed > 5 ? CoachMood.celebratory : CoachMood.encouraging,
    );
  }
}

/// LLM Post-Run Coach powered by Gemini
class LLMCoachService {
  static final LLMCoachService _instance = LLMCoachService._internal();
  factory LLMCoachService() => _instance;

  // Retrieve API key from environment / dart-define
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  GenerativeModel? _model;

  LLMCoachService._internal() {
    if (_geminiApiKey.isNotEmpty) {
      try {
        _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _geminiApiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.4,
          ),
        );
      } catch (e) {
        debugPrint('[LLMCoachService] Error initializing GenerativeModel: $e');
      }
    }
  }

  /// Evaluates a completed run session and produces tailored coaching insights
  Future<CoachInsight> generateRunInsight({
    required double distanceKm,
    required int durationSeconds,
    required int hexesClaimed,
    required RunnerProfile profile,
    String? currentPaceFormatted,
  }) async {
    final Map<String, dynamic> runContext = {
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'durationFormatted': "${(durationSeconds ~/ 60)}m ${durationSeconds % 60}s",
      'averagePace': currentPaceFormatted ?? "6'15\"/km",
      'hexesClaimedThisRun': hexesClaimed,
      'totalHexesClaimedLifetime': profile.totalHexesClaimed,
      'runnerLevel': profile.level,
      'currentStreakDays': profile.currentStreak,
      'totalDistanceLifetimeKm': profile.totalDistanceKm,
    };

    if (_model == null) {
      debugPrint('[LLMCoachService] Gemini API key not set; using smart on-device coaching heuristic.');
      return CoachInsight.fallback(
        distanceKm: distanceKm,
        hexesClaimed: hexesClaimed,
        durationSeconds: durationSeconds,
      );
    }

    final String prompt = '''
You are the AI Running & Territory Conquest Coach in "Territory Runner".
Analyze this completed run session data:
${jsonEncode(runContext)}

Provide a motivational coaching response in STRICT JSON matching this schema:
{
  "summary": "1-2 sentences highlighting performance, distance, and territory expansion achievements.",
  "tip": "1 tactical, athletic advice for recovery or pacing on their next hexagonal route.",
  "moodTag": "celebratory" | "encouraging" | "analytical"
}
Do NOT include markdown wrapping or extra text. Output raw JSON only.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final rawText = response.text?.trim() ?? '';
      return _parseCoachJson(rawText, distanceKm, hexesClaimed, durationSeconds);
    } catch (e) {
      debugPrint('[LLMCoachService] Gemini generation failed: $e. Retrying once...');
      try {
        final retryResponse = await _model!.generateContent([
          Content.text('Return strictly JSON matching: {"summary":"...","tip":"...","moodTag":"celebratory"} for a ${distanceKm.toStringAsFixed(1)}km run capturing $hexesClaimed hexes.')
        ]);
        final retryText = retryResponse.text?.trim() ?? '';
        return _parseCoachJson(retryText, distanceKm, hexesClaimed, durationSeconds);
      } catch (retryError) {
        debugPrint('[LLMCoachService] Gemini retry failed: $retryError');
        return CoachInsight.fallback(
          distanceKm: distanceKm,
          hexesClaimed: hexesClaimed,
          durationSeconds: durationSeconds,
        );
      }
    }
  }

  CoachInsight _parseCoachJson(
    String rawJson,
    double distanceKm,
    int hexesClaimed,
    int durationSeconds,
  ) {
    try {
      // Clean potential markdown blocks
      String clean = rawJson;
      if (clean.startsWith('```json')) clean = clean.substring(7);
      if (clean.startsWith('```')) clean = clean.substring(3);
      if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
      clean = clean.trim();

      final data = jsonDecode(clean) as Map<String, dynamic>;
      final summary = data['summary'] as String? ?? '';
      final tip = data['tip'] as String? ?? '';
      final moodStr = (data['moodTag'] as String?)?.toLowerCase() ?? 'encouraging';

      CoachMood mood = CoachMood.encouraging;
      if (moodStr == 'celebratory') mood = CoachMood.celebratory;
      if (moodStr == 'analytical') mood = CoachMood.analytical;

      if (summary.isNotEmpty && tip.isNotEmpty) {
        return CoachInsight(summary: summary, tip: tip, moodTag: mood);
      }
    } catch (e) {
      debugPrint('[LLMCoachService] JSON parsing error: $e. Raw text: $rawJson');
    }

    return CoachInsight.fallback(
      distanceKm: distanceKm,
      hexesClaimed: hexesClaimed,
      durationSeconds: durationSeconds,
    );
  }
}
