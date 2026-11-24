import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/saved_loop.dart';
import 'package:territory_runner/services/saved_loop_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('saved_loop_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SavedLoop Model & Service Tests', () {
    final samplePoints = [
      const LatLng(51.5000, -0.1200),
      const LatLng(51.5010, -0.1200),
      const LatLng(51.5010, -0.1210),
      const LatLng(51.5000, -0.1210),
      const LatLng(51.5000, -0.1200),
    ];

    test('SavedLoop JSON serialization roundtrip', () {
      final loop = SavedLoop(
        id: 'loop_1',
        name: 'Hyde Park 1K',
        points: samplePoints,
        distanceMeters: 1000.0,
        areaSqMeters: 12500.0,
        createdAt: DateTime(2026, 1, 1),
        bestTimeSeconds: 300,
        runCount: 3,
      );

      final json = loop.toJson();
      final revived = SavedLoop.fromJson(json);

      expect(revived.id, 'loop_1');
      expect(revived.name, 'Hyde Park 1K');
      expect(revived.points.length, 5);
      expect(revived.distanceMeters, 1000.0);
      expect(revived.areaSqMeters, 12500.0);
      expect(revived.bestTimeSeconds, 300);
      expect(revived.runCount, 3);
    });

    test('SavedLoopService saves, retrieves, and deletes loop', () async {
      final service = SavedLoopService();
      final saved = await service.saveLoop(
        name: 'Morning Loop',
        points: samplePoints,
        distanceMeters: 800.0,
        areaSqMeters: 5000.0,
      );

      expect(saved.id, isNotEmpty);
      expect(saved.name, 'Morning Loop');

      final all = await service.getSavedLoops();
      expect(all.length, 1);
      expect(all.first.id, saved.id);

      await service.deleteLoop(saved.id);

      final emptyList = await service.getSavedLoops();
      expect(emptyList.isEmpty, isTrue);
    });

    test('recordLoopRun updates run count and personal best', () async {
      final service = SavedLoopService();
      final loop = await service.saveLoop(
        name: 'Sprint Loop',
        points: samplePoints,
        distanceMeters: 500.0,
        areaSqMeters: 2500.0,
      );

      // First run: 180s
      await service.recordLoopRun(loop.id, 180);
      var current = (await service.getSavedLoops()).first;
      expect(current.runCount, 1);
      expect(current.bestTimeSeconds, 180);

      // Second run: slower (200s), PB should remain 180s
      await service.recordLoopRun(loop.id, 200);
      current = (await service.getSavedLoops()).first;
      expect(current.runCount, 2);
      expect(current.bestTimeSeconds, 180);

      // Third run: faster (150s), PB should become 150s
      await service.recordLoopRun(loop.id, 150);
      current = (await service.getSavedLoops()).first;
      expect(current.runCount, 3);
      expect(current.bestTimeSeconds, 150);
    });

    test('computeProgress computes on-route progress and detects off-route deviation >40m', () {
      final service = SavedLoopService();
      final loop = SavedLoop(
        id: 'test_loop',
        name: 'Test',
        points: samplePoints,
        distanceMeters: 500.0,
        areaSqMeters: 1000.0,
        createdAt: DateTime.now(),
      );

      // Test point exactly on the route (start point)
      final pOnRoute = service.computeProgress(samplePoints.first, loop.points);
      expect(pOnRoute.isOffRoute, isFalse);
      expect(pOnRoute.remainingDistanceMeters, greaterThanOrEqualTo(0));
      expect(pOnRoute.progressFraction, inInclusiveRange(0.0, 1.0));

      // Test point far away (>1km away)
      const farPoint = LatLng(51.6000, -0.1200);
      final pOffRoute = service.computeProgress(farPoint, loop.points);
      expect(pOffRoute.isOffRoute, isTrue);
      expect(pOffRoute.distanceToRouteMeters, greaterThan(40.0));
    });
  });
}
