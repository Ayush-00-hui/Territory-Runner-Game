import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('t1_test_');
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
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
    final pBox = Hive.box<RunnerProfile>('profile');
    await pBox.put(
      'current',
      RunnerProfile(
        id: 'usr_t1_dart',
        username: 'DartRunner',
        faction: 'Cyber Vanguard',
      ),
    );
  });

  tearDown(() async {
    await Hive.box<Territory>('territories_v3').clear();
    await Hive.box<RunnerProfile>('profile').clear();
  });

  group('Phase T1 Invariants (Dart Client)', () {
    test('(a) & (b) Claiming same loop twice or loop inside own land yields zero net area and zero XP', () async {
      final service = TerritoryService();

      final loop1 = [
        const LatLng(51.5000, -0.1200),
        const LatLng(51.5010, -0.1200),
        const LatLng(51.5010, -0.1215),
        const LatLng(51.5000, -0.1215),
        const LatLng(51.5000, -0.1200),
      ];

      // First capture
      await service.capturePolygonTerritory(
        polygon: loop1,
        areaSqMeters: 10000.0,
      );
      expect(service.lastCaptureNetAreaSqM, greaterThan(8000.0));
      expect(service.lastCaptureXp, greaterThan(0));

      // Second capture of identical loop
      await service.capturePolygonTerritory(
        polygon: loop1,
        areaSqMeters: 10000.0,
      );
      expect(
        service.lastCaptureNetAreaSqM,
        equals(0.0),
        reason: 'Identical loop must yield 0 net new area',
      );
      expect(
        service.lastCaptureXp,
        equals(0),
        reason: 'Zero net area must yield 0 XP',
      );

      // Inner loop fully inside existing territory
      final innerLoop = [
        const LatLng(51.5003, -0.1205),
        const LatLng(51.5007, -0.1205),
        const LatLng(51.5007, -0.1210),
        const LatLng(51.5003, -0.1210),
        const LatLng(51.5003, -0.1205),
      ];

      await service.capturePolygonTerritory(
        polygon: innerLoop,
        areaSqMeters: 1500.0,
      );
      expect(
        service.lastCaptureNetAreaSqM,
        equals(0.0),
        reason: 'Inner loop must yield 0 net new area',
      );
      expect(
        service.lastCaptureXp,
        equals(0),
        reason: 'Inner loop must yield 0 XP',
      );
    });

    test(
      '(f) Small loop does not reset strength of distant territory to 100%',
      () async {
        final service = TerritoryService();
        final box = Hive.box<Territory>('territories_v3');
        final now = DateTime.now();

        // Seed large territory (10,000 m²) with decayed strength = 40.0%
        final initialT = Territory(
          id: 'poly_usr_t1_dart_territory',
          ownerId: 'usr_t1_dart',
          polygon: const [
            LatLng(51.5000, -0.1200),
            LatLng(51.5010, -0.1200),
            LatLng(51.5010, -0.1215),
            LatLng(51.5000, -0.1215),
            LatLng(51.5000, -0.1200),
          ],
          polygons: const [
            [
              LatLng(51.5000, -0.1200),
              LatLng(51.5010, -0.1200),
              LatLng(51.5010, -0.1215),
              LatLng(51.5000, -0.1215),
              LatLng(51.5000, -0.1200),
            ],
          ],
          areaSqMeters: 10000.0,
          capturedAt: now.subtract(const Duration(days: 4)),
          lastDefendedAt: now.subtract(const Duration(days: 4)),
          cooldownUntil: now.subtract(const Duration(hours: 1)),
          strength: 40.0,
        );
        await box.put(initialT.id, initialT);

        // Capture small expansion loop far away (200 m²)
        final smallLoop = [
          const LatLng(51.5030, -0.1200),
          const LatLng(51.5032, -0.1200),
          const LatLng(51.5032, -0.1202),
          const LatLng(51.5030, -0.1202),
          const LatLng(51.5030, -0.1200),
        ];

        final captured = await service.capturePolygonTerritory(
          polygon: smallLoop,
          areaSqMeters: 200.0,
          ownerId: 'usr_t1_dart',
        );

        // Invariant (f): Strength must NOT jump to 100%. Should be area-weighted (~41.2%)
        expect(
          captured.strength,
          lessThan(50.0),
          reason:
              'Small expansion must not reset strength of distant land to 100%',
        );
      },
    );

    test('(h) Thin out-and-back loops are rejected with "Loop too thin"', () {
      final engine = PolygonEnclosureEngine();
      final now = DateTime.now();

      // Thin loop (Perimeter ~450m, Area ~220m² > 200m² min area, thinness = 0.0136 < 0.02)
      // Run at realistic speed (~9.0 km/h, 25m per 10s, gap < 15s)
      final points = <LatLng>[];
      // Going north 250m (10 steps of 25m)
      for (int i = 0; i <= 10; i++) {
        points.add(LatLng(51.500000 + i * (0.00225 / 10), -0.120000));
      }
      // Step east 1.0m
      points.add(const LatLng(51.502250, -0.120014));
      // Going south 250m (10 steps of 25m)
      for (int i = 9; i >= 0; i--) {
        points.add(LatLng(51.500000 + i * (0.00225 / 10), -0.120014));
      }
      // Step back west to close
      points.add(const LatLng(51.500000, -0.120000));

      EnclosedLoopEvent? event;
      DateTime t = now;
      String? invalidReason;
      for (final p in points) {
        event = engine.addPosition(p, t);
        if (engine.lastInvalidReason != null) {
          invalidReason = engine.lastInvalidReason;
        }
        t = t.add(const Duration(seconds: 10));
      }

      expect(event, isNull, reason: 'Thin loop must be rejected');
      expect(invalidReason, equals('Loop too thin'));
    });
  });
}
