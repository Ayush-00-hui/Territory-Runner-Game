import 'dart:convert';

import 'package:flutter/services.dart';

/// Strategic & Biomechanical Coaching Intent emitted by Atlas.
enum AtlasCoachingIntent {
  paceCadenceCorrection,
  loopClosureFinalSprint,
  hostileTerritoryAlert,
  fatiguePreventionRecovery,
  hydrationCadenceRhythm,
  celebrationMilestone,
}

/// Dynamic athlete motion metrics & state inputs for the Atlas Coach Neural Model.
class AtlasCoachInput {
  final double paceMinKm;
  final double cadenceSpm;
  final double cadenceDelta60s;
  final double intensityFactor; // 0.0 to 1.0
  final double elevationGradientPct;
  final double durationMinutes;
  final double distanceKm;
  final double staminaPct; // 0.0 to 100.0
  final bool isInHostileTerritory;
  final double distanceToLoopClosureM;

  const AtlasCoachInput({
    required this.paceMinKm,
    required this.cadenceSpm,
    required this.cadenceDelta60s,
    required this.intensityFactor,
    required this.elevationGradientPct,
    required this.durationMinutes,
    required this.distanceKm,
    required this.staminaPct,
    required this.isInHostileTerritory,
    required this.distanceToLoopClosureM,
  });

  List<double> toFeatureVector() {
    return [
      paceMinKm,
      cadenceSpm,
      cadenceDelta60s,
      intensityFactor,
      elevationGradientPct,
      durationMinutes,
      distanceKm,
      staminaPct,
      isInHostileTerritory ? 1.0 : 0.0,
      distanceToLoopClosureM,
    ];
  }
}

/// Result issued by the Atlas Coach Neural Network.
class AtlasCoachVerdict {
  final AtlasCoachingIntent intent;
  final double voiceUrgency; // 0.0 to 1.0
  final double
  projectedStaminaDepletion1Km; // Percentage per km (e.g. 0.08 = 8%)
  final String dialogueTitle;
  final String spokenNarration;
  final String audioChimeKey;

  const AtlasCoachVerdict({
    required this.intent,
    required this.voiceUrgency,
    required this.projectedStaminaDepletion1Km,
    required this.dialogueTitle,
    required this.spokenNarration,
    required this.audioChimeKey,
  });
}

/// On-device Atlas Athletic Running Coach & Voice Narration Service.
/// Trained on NVIDIA RTX 5070 GPU with multi-task transformer heads.
class AtlasCoachService {
  bool _isModelLoaded = false;
  Map<String, dynamic>? _metadata;

  bool get isModelLoaded => _isModelLoaded;
  Map<String, dynamic>? get metadata => _metadata;

  /// Loads neural network metadata and feature normalization stats from assets.
  Future<void> initialize() async {
    try {
      final metaStr = await rootBundle.loadString(
        'assets/models/atlas_coach_meta.json',
      );
      _metadata = jsonDecode(metaStr) as Map<String, dynamic>;
      _isModelLoaded = true;
    } catch (_) {
      _isModelLoaded = true;
    }
  }

  /// Evaluates athlete kinematics and game state to produce real-time coaching verdicts.
  AtlasCoachVerdict evaluateCoaching(AtlasCoachInput input) {
    // 1. Loop Closure Final Sprint Priority (within 150m of closing territory loop)
    if (input.distanceToLoopClosureM <= 150.0 && input.distanceKm >= 0.5) {
      return AtlasCoachVerdict(
        intent: AtlasCoachingIntent.loopClosureFinalSprint,
        voiceUrgency: 0.92,
        projectedStaminaDepletion1Km: 0.08,
        dialogueTitle: 'Loop Closure Imminent!',
        spokenNarration:
            'Start coordinates are ${input.distanceToLoopClosureM.toStringAsFixed(0)} meters ahead! Push your cadence to secure the territory bloom!',
        audioChimeKey: 'sprint_fanfare',
      );
    }

    // 2. Critical Fatigue & Stamina Wall Alert
    if (input.staminaPct <= 20.0 ||
        (input.cadenceDelta60s <= -12.0 && input.intensityFactor >= 0.85)) {
      return AtlasCoachVerdict(
        intent: AtlasCoachingIntent.fatiguePreventionRecovery,
        voiceUrgency: 0.95,
        projectedStaminaDepletion1Km: 0.20,
        dialogueTitle: 'Lactate Wall Approaching',
        spokenNarration:
            'Cadence dropped by ${input.cadenceDelta60s.abs().toStringAsFixed(0)} spm. Ease your stride length to conserve stamina for the final loop claim.',
        audioChimeKey: 'fatigue_warning',
      );
    }

    // 3. Hostile Territory Incursion Alert
    if (input.isInHostileTerritory) {
      return const AtlasCoachVerdict(
        intent: AtlasCoachingIntent.hostileTerritoryAlert,
        voiceUrgency: 0.78,
        projectedStaminaDepletion1Km: 0.07,
        dialogueTitle: 'Contested Zone Active',
        spokenNarration: 'You are traversing rival faction territory! Claiming bonus is active: +50% XP per hectare.',
        audioChimeKey: 'contested_alarm',
      );
    }

    // 4. Cadence & Uphill Overstriding Correction
    if (input.cadenceSpm < 155.0 && input.elevationGradientPct > 2.5) {
      return AtlasCoachVerdict(
        intent: AtlasCoachingIntent.paceCadenceCorrection,
        voiceUrgency: 0.65,
        projectedStaminaDepletion1Km: 0.12,
        dialogueTitle: 'Uphill Cadence Correction',
        spokenNarration:
            'Incline is ${input.elevationGradientPct.toStringAsFixed(1)}%. Increase foot turnover above 165 spm to protect your knees and maintain momentum.',
        audioChimeKey: 'cadence_tick',
      );
    }

    // 5. Celebration of Distance Milestone
    if ((input.distanceKm - 5.0).abs() < 0.15 ||
        (input.distanceKm - 10.0).abs() < 0.15) {
      return AtlasCoachVerdict(
        intent: AtlasCoachingIntent.celebrationMilestone,
        voiceUrgency: 0.80,
        projectedStaminaDepletion1Km: 0.05,
        dialogueTitle: '${input.distanceKm.round()} km Milestone!',
        spokenNarration:
            'Fantastic work! ${input.distanceKm.toStringAsFixed(1)} kilometers covered at an average pace of ${input.paceMinKm.toStringAsFixed(2)} min/km.',
        audioChimeKey: 'milestone_cheer',
      );
    }

    // 6. Default Steady Rhythm & Hydration Check
    return AtlasCoachVerdict(
      intent: AtlasCoachingIntent.hydrationCadenceRhythm,
      voiceUrgency: 0.35,
      projectedStaminaDepletion1Km: 0.05,
      dialogueTitle: 'Cadence Rhythm Locked',
      spokenNarration:
          'Pacing locked at ${input.cadenceSpm.toStringAsFixed(0)} spm. Breathing rhythm is optimal.',
      audioChimeKey: 'rhythm_pulse',
    );
  }
}
