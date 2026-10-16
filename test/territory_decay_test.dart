import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/models/ws_events.dart';

void main() {
  group('Territory Strength and Decay Mechanics Tests', () {
    test('computeCurrentStrength correctly decays at 15 points per day', () {
      final now = DateTime(2026, 10, 15, 12, 0, 0);
      final territory = Territory(
        id: 'poly_test_decay',
        ownerId: 'runner_1',
        polygon: [
          const LatLng(51.5, -0.12),
          const LatLng(51.501, -0.12),
          const LatLng(51.501, -0.121),
          const LatLng(51.5, -0.121),
        ],
        areaSqMeters: 5000.0,
        capturedAt: now.subtract(const Duration(days: 2)),
        lastDefendedAt: now.subtract(const Duration(days: 2)),
        strength: 100.0,
      );

      // After 2 days at 15 points/day: 100 - (2 * 15) = 70.0
      final s2 = territory.computeCurrentStrength(now: now);
      expect(s2, closeTo(70.0, 0.1));
      expect(territory.isWeak(now: now), isFalse);

      // After 5 days at 15 points/day: 100 - (5 * 15) = 25.0 (< 30.0, weak!)
      final now5 = now.subtract(const Duration(days: 2)).add(const Duration(days: 5));
      final s5 = territory.computeCurrentStrength(now: now5);
      expect(s5, closeTo(25.0, 0.1));
      expect(territory.isWeak(now: now5), isTrue);

      // After 10 days: clamped at 0.0
      final now10 = now.subtract(const Duration(days: 2)).add(const Duration(days: 10));
      final s10 = territory.computeCurrentStrength(now: now10);
      expect(s10, equals(0.0));
      expect(territory.isWeak(now: now10), isTrue);
    });

    test('Defending territory resets strength to 100% and updates lastDefendedAt', () {
      final initialDefended = DateTime.now().subtract(const Duration(days: 4));
      final territory = Territory(
        id: 'poly_defend_test',
        ownerId: 'runner_1',
        polygon: [const LatLng(51.5, -0.12)],
        areaSqMeters: 1000.0,
        capturedAt: initialDefended,
        lastDefendedAt: initialDefended,
        strength: 40.0,
      );

      final defended = territory.copyWith(
        strength: 100.0,
        lastDefendedAt: DateTime.now(),
      );

      expect(defended.strength, equals(100.0));
      expect(defended.computeCurrentStrength(), equals(100.0));
      expect(defended.isWeak(), isFalse);
    });

    test('Backward compatibility: legacy JSON without strength or lastDefendedAt deserializes safely', () {
      final legacyJson = {
        'id': 'poly_legacy_001',
        'ownerId': 'legacy_runner',
        'polygon': [
          {'lat': 51.5, 'lng': -0.12},
          {'lat': 51.501, 'lng': -0.12},
        ],
        'areaSqMeters': 3200.0,
        'capturedAt': '2026-10-10T10:00:00.000Z',
      };

      final territory = Territory.fromJson(legacyJson);
      expect(territory.id, equals('poly_legacy_001'));
      expect(territory.strength, equals(100.0));
      expect(territory.lastDefendedAt, equals(DateTime.parse('2026-10-10T10:00:00.000Z')));
    });

    test('Hive TerritoryAdapter serialization preserves strength and lastDefendedAt', () async {
      final tempDir = Directory.systemTemp.createTempSync('hive_adapter_test');
      try {
        Hive.init(tempDir.path);
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(TerritoryAdapter());
        }
        final box = await Hive.openBox<Territory>('test_adapter_box');

        final original = Territory(
          id: 'poly_adapter_test',
          ownerId: 'runner_hive',
          polygon: [
            const LatLng(51.5, -0.12),
            const LatLng(51.501, -0.12),
            const LatLng(51.501, -0.121),
          ],
          areaSqMeters: 4500.0,
          capturedAt: DateTime(2026, 10, 15, 10, 0),
          lastDefendedAt: DateTime(2026, 10, 15, 12, 0),
          strength: 85.0,
        );

        await box.put('t1', original);
        final loaded = box.get('t1');

        expect(loaded, isNotNull);
        expect(loaded!.id, equals(original.id));
        expect(loaded.strength, equals(85.0));
        expect(loaded.lastDefendedAt, equals(DateTime(2026, 10, 15, 12, 0)));

        await box.close();
      } finally {
        await Hive.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('TerritoryAlertEvent deserializes territory_under_attack WebSocket packet', () {
      final jsonPacket = {
        'type': 'territory_under_attack',
        'event': 'territory_under_attack',
        'attacker_id': 'shadow_01',
        'attacker_name': 'ShadowRunner',
        'area_claimed_sqm': 3500.0,
        'victim_user_id': 'ayush_01',
        'message': '⚠️ ALERT: Territory under attack! Rival ShadowRunner captured 3500 m²!',
        'timestamp': '2026-10-15T12:00:00Z',
      };

      final alert = TerritoryAlertEvent.fromJson(jsonPacket);
      expect(alert.event, equals('territory_under_attack'));
      expect(alert.attackerName, equals('ShadowRunner'));
      expect(alert.areaClaimedSqm, equals(3500.0));
      expect(alert.message, contains('Territory under attack'));
    });
  });
}
