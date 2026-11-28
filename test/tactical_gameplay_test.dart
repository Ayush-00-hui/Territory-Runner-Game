import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/loot_crate.dart';
import 'package:territory_runner/models/tactical_perk.dart';
import 'package:territory_runner/features/gameplay/loot_crate_service.dart';
import 'package:territory_runner/features/gameplay/incursion_service.dart';
import 'package:territory_runner/services/citadel_service.dart';
import 'package:territory_runner/services/fog_of_war_service.dart';
import 'package:territory_runner/services/tactical_ai_engine.dart';
import 'package:territory_runner/services/tactical_loadout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tactical AI Neural Engine Tests', () {
    test('Analytical fallback generates physiologically valid outputs', () {
      final engine = TacticalAiEngine();
      const input = TacticalTelemetryInput(
        speedMps: 3.5, // ~4:45/km
        gradePct: 0.04, // 4% incline
        cumulativeFatigue: 0.35,
        athleteExperience: 1.0,
      );

      final pred = engine.predict(input);
      expect(pred.sprintVelocityTargetMps, greaterThan(3.5));
      expect(pred.incursionMaxDurationSeconds, inInclusiveRange(30, 90));
      expect(pred.optimalCrateDetourMeters, inInclusiveRange(120.0, 450.0));
      expect(
        pred.guardianP10Multiplier,
        lessThanOrEqualTo(pred.guardianP50Multiplier),
      );
      expect(
        pred.guardianP50Multiplier,
        lessThanOrEqualTo(pred.guardianP90Multiplier),
      );
    });
  });

  group('Loot Crate Service Tests', () {
    late LootCrateService service;

    setUp(() {
      service = LootCrateService();
      service.reset();
    });

    test('Spawns crate and detects collection within radius', () {
      const runnerPos = LatLng(28.8500, 77.1000);
      service.spawnProceduralCrate(
        runnerPos: runnerPos,
        headingDeg: 90.0,
        distanceMeters: 50.0,
        specificType: LootCrateType.overchargeBeacon,
      );

      expect(service.activeCrates.length, 1);
      final cratePos = service.activeCrates.first.position;

      // Move runner right to crate
      service.updateRunnerLocation(cratePos, 3.5, 50.0);

      expect(service.activeCrates.isEmpty, true);
      expect(service.collectedHistory.length, 1);
      expect(service.isOverchargeActive, true);
      expect(service.overchargeRemainingMeters, 500.0);
    });
  });

  group('Sprint Incursion Service Tests', () {
    late IncursionService service;

    setUp(() {
      service = IncursionService();
      service.reset();
    });

    test('Triggers incursion with target pace and evaluates speed', () {
      service.triggerIncursion(
        rivalFaction: 'Obsidian Syndicate',
        customTargetSpeedMps: 3.6,
        durationSeconds: 45,
      );

      expect(service.hasActiveIncursion, true);
      expect(service.currentIncursion!.rivalFactionName, 'Obsidian Syndicate');
      expect(service.currentIncursion!.remainingSeconds, 45);

      service.updateRunnerSpeed(3.8); // Above target pace
    });
  });

  group('Citadel Service Tests', () {
    late CitadelService service;

    setUp(() {
      service = CitadelService();
    });

    test('Polygon enclosure captures enclosed Citadel', () {
      const center = LatLng(28.8500, 77.1000);
      service.seedCitadelsNear(center);
      expect(service.citadels.isNotEmpty, true);

      final targetCitadel = service.citadels.first;
      final cLat = targetCitadel.position.latitude;
      final cLng = targetCitadel.position.longitude;

      // Create bounding polygon around citadel
      final polygon = [
        LatLng(cLat - 0.005, cLng - 0.005),
        LatLng(cLat + 0.005, cLng - 0.005),
        LatLng(cLat + 0.005, cLng + 0.005),
        LatLng(cLat - 0.005, cLng + 0.005),
      ];

      final captured = service.checkPolygonEnclosure(
        polygon,
        'SpeedDemon',
        'Apex Vanguard',
      );
      expect(captured, isNotNull);
      expect(captured!.controllingFaction, 'Apex Vanguard');
      expect(captured.rulerAthleteName, 'SpeedDemon');
    });
  });

  group('Tactical Loadout Service Tests', () {
    late TacticalLoadoutService service;

    setUp(() {
      service = TacticalLoadoutService();
      for (final p in service.availablePerks) {
        p.isEquipped = false;
      }
    });

    test('Enforces maximum 2 equipped perks simultaneously', () {
      expect(service.toggleEquip(TacticalPerkType.sonarPulse), true);
      expect(service.toggleEquip(TacticalPerkType.aegisShield), true);
      expect(service.equippedPerks.length, 2);

      // Third equip attempt should be rejected
      expect(service.toggleEquip(TacticalPerkType.overdrive), false);
      expect(service.equippedPerks.length, 2);
    });
  });

  group('Fog of War Service Tests', () {
    test('Reveals grid cells and updates exploration coverage', () {
      final service = FogOfWarService();
      const pos = LatLng(28.8500, 77.1000);
      service.revealFogAt(pos);

      expect(service.visitedCells.isNotEmpty, true);
      expect(service.totalExploredAreaSqKm, greaterThan(0.0));
      expect(service.urbanExplorationPercentage, greaterThan(0.0));
    });
  });
}
