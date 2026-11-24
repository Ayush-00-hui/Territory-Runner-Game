import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:territory_runner/models/tiered_achievement.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tiered_achievement_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TieredAchievement Model Tests', () {
    test('TieredAchievement standard catalog is populated', () {
      final catalog = TieredAchievement.standardCatalog;
      expect(catalog.length, greaterThanOrEqualTo(4));
      expect(catalog.any((a) => a.id == 'ach_distance'), isTrue);
      expect(catalog.any((a) => a.id == 'ach_territory'), isTrue);
      expect(catalog.any((a) => a.id == 'ach_streak'), isTrue);
      expect(catalog.any((a) => a.id == 'ach_exploration'), isTrue);
    });

    test('TieredAchievement progress calculation and tier determination', () {
      const achievement = TieredAchievement(
        id: 'dist_milestone',
        title: 'Distance Legend',
        description: 'Run cumulative distance on foot',
        metricUnit: 'km',
        thresholds: {
          AchievementTier.bronze: 10.0, // 10 km
          AchievementTier.silver: 50.0, // 50 km
          AchievementTier.gold: 100.0, // 100 km
          AchievementTier.platinum: 500.0, // 500 km
        },
      );

      // At 5km: No tier unlocked, bronze in progress (50%)
      final p5k = achievement.evaluate(5.0);
      expect(p5k.currentTier, isNull);
      expect(p5k.nextTier, AchievementTier.bronze);
      expect(p5k.progressFraction, closeTo(0.5, 0.01));

      // At 25km: Bronze unlocked, silver in progress (25/50 = 50%)
      final p25k = achievement.evaluate(25.0);
      expect(p25k.currentTier, AchievementTier.bronze);
      expect(p25k.nextTier, AchievementTier.silver);

      // At 150km: Gold unlocked, platinum next
      final p150k = achievement.evaluate(150.0);
      expect(p150k.currentTier, AchievementTier.gold);
      expect(p150k.nextTier, AchievementTier.platinum);

      // At 600km: Platinum maxed
      final p600k = achievement.evaluate(600.0);
      expect(p600k.currentTier, AchievementTier.platinum);
      expect(p600k.nextTier, isNull);
      expect(p600k.isMaxed, isTrue);
      expect(p600k.progressFraction, 1.0);
    });
  });
}
