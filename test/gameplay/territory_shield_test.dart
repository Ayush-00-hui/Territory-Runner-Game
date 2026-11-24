import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('territory_shield_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    if (!Hive.isBoxOpen('territories_v3')) {
      await Hive.openBox<Territory>('territories_v3');
    }
    if (!Hive.isBoxOpen('profile')) {
      await Hive.openBox<RunnerProfile>('profile');
    }
    await Hive.box<Territory>('territories_v3').clear();
  });

  group('Territory Model Defense Shield Mechanics', () {
    test('New territory receives default 2-hour defense shield', () {
      final now = DateTime.now();
      final territory = Territory(
        id: 'poly_test_001',
        ownerId: 'runner_alice',
        polygon: const [
          LatLng(51.500, -0.120),
          LatLng(51.502, -0.120),
          LatLng(51.502, -0.122),
          LatLng(51.500, -0.122),
        ],
        areaSqMeters: 1000.0,
        capturedAt: now,
      );

      expect(territory.cooldownUntil, isNotNull);
      expect(territory.cooldownUntil!.difference(now).inMinutes, equals(120));
      expect(territory.isShielded(now: now), isTrue);
      expect(
        territory.isShielded(now: now.add(const Duration(minutes: 60))),
        isTrue,
      );
      expect(
        territory.isShielded(now: now.add(const Duration(minutes: 121))),
        isFalse,
      );

      final remaining = territory.remainingShieldTime(
        now: now.add(const Duration(minutes: 30)),
      );
      expect(remaining.inMinutes, equals(90));
    });

    test('toJson and fromJson preserve cooldownUntil timestamp', () {
      final now = DateTime.now();
      final cooldown = now.add(const Duration(hours: 2));
      final territory = Territory(
        id: 'poly_json_test',
        ownerId: 'runner_bob',
        polygon: const [
          LatLng(51.500, -0.120),
          LatLng(51.501, -0.120),
          LatLng(51.501, -0.121),
          LatLng(51.500, -0.121),
        ],
        areaSqMeters: 500.0,
        capturedAt: now,
        cooldownUntil: cooldown,
      );

      final json = territory.toJson();
      expect(json['cooldownUntil'], isNotNull);
      expect(DateTime.parse(json['cooldownUntil'] as String), equals(cooldown));

      final restored = Territory.fromJson(json);
      expect(restored.cooldownUntil, equals(cooldown));
      expect(restored.isShielded(now: now), isTrue);
    });

    test(
      'Hive TerritoryAdapter serializes and restores cooldownUntil',
      () async {
        final box = Hive.box<Territory>('territories_v3');
        final now = DateTime.now();
        final territory = Territory(
          id: 'poly_hive_test',
          ownerId: 'runner_charlie',
          polygon: const [
            LatLng(51.500, -0.120),
            LatLng(51.502, -0.120),
            LatLng(51.502, -0.122),
            LatLng(51.500, -0.122),
          ],
          areaSqMeters: 1200.0,
          capturedAt: now,
          cooldownUntil: now.add(const Duration(hours: 2)),
        );

        await box.put(territory.id, territory);
        final readBack = box.get(territory.id);

        expect(readBack, isNotNull);
        expect(readBack!.id, equals(territory.id));
        expect(readBack.cooldownUntil, isNotNull);
        expect(readBack.isShielded(now: now), isTrue);
        expect(
          readBack.isShielded(now: now.add(const Duration(minutes: 121))),
          isFalse,
        );
      },
    );
  });

  group('TerritoryService Shield Defense & Conquest Protection', () {
    test('capturePolygonTerritory activates 2-hour shield', () async {
      final service = TerritoryService();
      final polygon = const [
        LatLng(51.500, -0.120),
        LatLng(51.502, -0.120),
        LatLng(51.502, -0.122),
        LatLng(51.500, -0.122),
        LatLng(51.500, -0.120),
      ];

      final captured = await service.capturePolygonTerritory(
        polygon: polygon,
        areaSqMeters: 1000.0,
        ownerId: 'usr_shield_runner',
      );

      expect(captured.cooldownUntil, isNotNull);
      expect(captured.isShielded(), isTrue);
      expect(
        captured.remainingShieldTime().inMinutes,
        greaterThanOrEqualTo(118),
      );
    });

    test('Shielded rival territory cannot be carved or overtaken', () async {
      final service = TerritoryService();
      final box = Hive.box<Territory>('territories_v3');

      // 1. Defender claims territory with active 30-minute shield
      final defenderPoly = const [
        LatLng(51.500, -0.120),
        LatLng(51.502, -0.120),
        LatLng(51.502, -0.122),
        LatLng(51.500, -0.122),
        LatLng(51.500, -0.120),
      ];
      final defender = await service.capturePolygonTerritory(
        polygon: defenderPoly,
        areaSqMeters: 2000.0,
        ownerId: 'usr_defender_shielded',
      );
      expect(defender.isShielded(), isTrue);
      final initialDefenderArea = defender.areaSqMeters;

      // 2. Attacker runs a loop strictly inside the shielded defender's territory
      final attackerInsidePoly = const [
        LatLng(51.5005, -0.1205),
        LatLng(51.5015, -0.1205),
        LatLng(51.5015, -0.1215),
        LatLng(51.5005, -0.1215),
        LatLng(51.5005, -0.1205),
      ];
      await service.capturePolygonTerritory(
        polygon: attackerInsidePoly,
        areaSqMeters: 500.0,
        ownerId: 'usr_attacker',
      );

      // Defender's territory must NOT be clipped or stolen
      final defenderAfter = box.get('poly_usr_defender_shielded_territory');
      expect(defenderAfter, isNotNull);
      expect(
        defenderAfter!.areaSqMeters,
        closeTo(initialDefenderArea, 1.0),
        reason: 'Shielded territory must remain intact without area loss',
      );
      expect(service.lastCaptureStolenAreaSqM, equals(0.0));
    });

    test('Expired rival shield allows conquest and carving', () async {
      final service = TerritoryService();
      final box = Hive.box<Territory>('territories_v3');

      // 1. Rival territory created with EXPIRED shield (captured 40m ago)
      final rivalPoly = const [
        LatLng(51.500, -0.120),
        LatLng(51.502, -0.120),
        LatLng(51.502, -0.122),
        LatLng(51.500, -0.122),
        LatLng(51.500, -0.120),
      ];
      final pastCapture = DateTime.now().subtract(const Duration(hours: 3));
      final initialRivalArea =
          PolygonEnclosureEngine.computeGeodesicShoelaceArea(rivalPoly);
      final rivalTerritory = Territory(
        id: 'poly_usr_vulnerable_territory',
        ownerId: 'usr_vulnerable',
        polygon: rivalPoly,
        polygons: [rivalPoly],
        areaSqMeters: initialRivalArea,
        capturedAt: pastCapture,
        lastDefendedAt: pastCapture,
        cooldownUntil: pastCapture.add(
          const Duration(hours: 2),
        ), // Expired 1 hour ago
      );
      await box.put(rivalTerritory.id, rivalTerritory);
      expect(rivalTerritory.isShielded(), isFalse);

      // 2. Attacker runs an overlapping loop
      final attackerPoly = const [
        LatLng(51.501, -0.121),
        LatLng(51.503, -0.121),
        LatLng(51.503, -0.123),
        LatLng(51.501, -0.123),
        LatLng(51.501, -0.121),
      ];
      await service.capturePolygonTerritory(
        polygon: attackerPoly,
        areaSqMeters: 1000.0,
        ownerId: 'usr_conqueror',
      );

      // Rival territory was carved
      final rivalAfter = box.get(rivalTerritory.id);
      expect(rivalAfter, isNotNull);
      expect(
        rivalAfter!.areaSqMeters,
        lessThan(initialRivalArea),
        reason: 'Unshielded rival territory must be carved by attacker',
      );
      expect(service.lastCaptureStolenAreaSqM, greaterThan(0.0));
    });

    test(
      'defendTerritory refreshes shield and restores 100% strength',
      () async {
        final service = TerritoryService();
        final box = Hive.box<Territory>('territories_v3');

        // 1. Territory with decayed strength and expired shield
        final pastCapture = DateTime.now().subtract(const Duration(days: 3));
        final decayedTerritory = Territory(
          id: 'poly_usr_fortify_test_territory',
          ownerId: 'usr_fortify_test',
          polygon: const [
            LatLng(51.500, -0.120),
            LatLng(51.502, -0.120),
            LatLng(51.502, -0.122),
            LatLng(51.500, -0.122),
            LatLng(51.500, -0.120),
          ],
          areaSqMeters: 1000.0,
          capturedAt: pastCapture,
          lastDefendedAt: pastCapture,
          strength: 25.0,
          cooldownUntil: pastCapture.add(const Duration(hours: 2)),
        );
        await box.put(decayedTerritory.id, decayedTerritory);
        expect(decayedTerritory.isShielded(), isFalse);
        expect(decayedTerritory.isWeak(), isTrue);

        // 2. Athlete fortifies territory
        final fortified = await service.defendTerritory('usr_fortify_test');

        expect(fortified, isNotNull);
        expect(fortified!.strength, equals(100.0));
        expect(fortified.isShielded(), isTrue);
        expect(
          fortified.remainingShieldTime().inMinutes,
          greaterThanOrEqualTo(118),
        );
      },
    );
  });

  group('Territory Commons Despawn & Grace Period', () {
    test('Territory at 160h (0% strength) remains within 72h grace period', () {
      final now = DateTime.now();
      final territory = Territory(
        id: 'poly_decay_160h',
        ownerId: 'usr_decay_1',
        polygon: const [
          LatLng(51.500, -0.120),
          LatLng(51.502, -0.120),
          LatLng(51.502, -0.122),
          LatLng(51.500, -0.122),
        ],
        areaSqMeters: 1000.0,
        capturedAt: now.subtract(const Duration(hours: 160)),
      );

      expect(territory.computeCurrentStrength(now: now), equals(0.0));
      expect(territory.isWeak(now: now), isTrue);
      expect(territory.isDespawned(now: now), isFalse);
    });

    test('Territory at 200h remains in grace period without despawning', () {
      final now = DateTime.now();
      final territory = Territory(
        id: 'poly_decay_200h',
        ownerId: 'usr_decay_2',
        polygon: const [
          LatLng(51.500, -0.120),
          LatLng(51.502, -0.120),
          LatLng(51.502, -0.122),
          LatLng(51.500, -0.122),
        ],
        areaSqMeters: 1000.0,
        capturedAt: now.subtract(const Duration(hours: 200)),
      );

      expect(territory.computeCurrentStrength(now: now), equals(0.0));
      expect(territory.isDespawned(now: now), isFalse);
    });

    test(
      'Territory beyond 232h (160h + 72h grace) despawns into public commons',
      () async {
        final now = DateTime.now();
        final territory = Territory(
          id: 'poly_despawned',
          ownerId: 'usr_abandoned',
          polygon: const [
            LatLng(51.500, -0.120),
            LatLng(51.502, -0.120),
            LatLng(51.502, -0.122),
            LatLng(51.500, -0.122),
          ],
          areaSqMeters: 1000.0,
          capturedAt: now.subtract(const Duration(hours: 233)),
        );

        expect(territory.isDespawned(now: now), isTrue);

        final service = TerritoryService();
        final box = Hive.box<Territory>('territories_v3');
        await box.put(territory.id, territory);

        // getCapturedTerritoryObjects filters out despawned territories
        final activeTerritories = service.getCapturedTerritoryObjects();
        expect(
          activeTerritories.any((t) => t.id == territory.id),
          isFalse,
          reason: 'Despawned territory must be excluded from active objects',
        );

        final activeIds = service.getCapturedTerritories();
        expect(
          activeIds.contains(territory.id),
          isFalse,
          reason: 'Despawned territory must be excluded from active IDs',
        );
      },
    );
  });
}
