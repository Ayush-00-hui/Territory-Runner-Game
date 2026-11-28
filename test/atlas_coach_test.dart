import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/atlas_coach_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AtlasCoachService RTX 5070 Neural Model Tests', () {
    late AtlasCoachService service;

    setUp(() {
      service = AtlasCoachService();
    });

    test('Initializes with default coach metadata', () async {
      await service.initialize();
      expect(service.isModelLoaded, true);
    });

    test('Triggers Loop Closure Final Sprint within 150m of origin', () {
      final verdict = service.evaluateCoaching(
        const AtlasCoachInput(
          paceMinKm: 4.5,
          cadenceSpm: 175.0,
          cadenceDelta60s: 2.0,
          intensityFactor: 0.70,
          elevationGradientPct: 0.5,
          durationMinutes: 28.0,
          distanceKm: 4.8,
          staminaPct: 45.0,
          isInHostileTerritory: false,
          distanceToLoopClosureM: 95.0, // Imminent loop closure
        ),
      );

      expect(verdict.intent, AtlasCoachingIntent.loopClosureFinalSprint);
      expect(verdict.voiceUrgency, greaterThanOrEqualTo(0.90));
      expect(verdict.spokenNarration, contains('95 meters'));
      expect(verdict.audioChimeKey, 'sprint_fanfare');
    });

    test('Warns of Fatigue Wall when stamina drops below 20%', () {
      final verdict = service.evaluateCoaching(
        const AtlasCoachInput(
          paceMinKm: 5.8,
          cadenceSpm: 152.0,
          cadenceDelta60s: -14.0, // Cadence drop
          intensityFactor: 0.90,
          elevationGradientPct: 1.0,
          durationMinutes: 42.0,
          distanceKm: 6.2,
          staminaPct: 15.0, // Critical fatigue
          isInHostileTerritory: false,
          distanceToLoopClosureM: 800.0,
        ),
      );

      expect(verdict.intent, AtlasCoachingIntent.fatiguePreventionRecovery);
      expect(verdict.voiceUrgency, greaterThanOrEqualTo(0.90));
      expect(verdict.spokenNarration, contains('Ease your stride'));
      expect(verdict.projectedStaminaDepletion1Km, greaterThan(0.15));
    });

    test('Alerts when entering hostile territory with bonus XP', () {
      final verdict = service.evaluateCoaching(
        const AtlasCoachInput(
          paceMinKm: 5.0,
          cadenceSpm: 168.0,
          cadenceDelta60s: 0.0,
          intensityFactor: 0.65,
          elevationGradientPct: 0.0,
          durationMinutes: 20.0,
          distanceKm: 3.5,
          staminaPct: 60.0,
          isInHostileTerritory: true, // Inside enemy sector
          distanceToLoopClosureM: 650.0,
        ),
      );

      expect(verdict.intent, AtlasCoachingIntent.hostileTerritoryAlert);
      expect(verdict.spokenNarration, contains('+50% XP'));
      expect(verdict.audioChimeKey, 'contested_alarm');
    });

    test('Issues uphill cadence correction to protect joints', () {
      final verdict = service.evaluateCoaching(
        const AtlasCoachInput(
          paceMinKm: 6.2,
          cadenceSpm: 148.0, // Low cadence
          cadenceDelta60s: -5.0,
          intensityFactor: 0.75,
          elevationGradientPct: 4.5, // Steep uphill
          durationMinutes: 18.0,
          distanceKm: 2.5,
          staminaPct: 65.0,
          isInHostileTerritory: false,
          distanceToLoopClosureM: 1200.0,
        ),
      );

      expect(verdict.intent, AtlasCoachingIntent.paceCadenceCorrection);
      expect(verdict.spokenNarration, contains('165 spm'));
      expect(verdict.dialogueTitle, contains('Uphill'));
    });
  });
}
