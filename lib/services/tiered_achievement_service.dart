import 'dart:convert';

import 'package:hive/hive.dart';

import '../core/logging/app_logger.dart';
import '../features/gameplay/territory_service.dart';
import '../models/tiered_achievement.dart';
import 'exploration_service.dart';

/// Service managing tiered achievements evaluation, progression bars,
/// and permanent timeline tracking.
class TieredAchievementService {
  static const String boxName = 'achievements_timeline_v1';

  final TerritoryService _territoryService;
  final ExplorationService _explorationService;
  Box<String>? _box;

  TieredAchievementService({
    TerritoryService? territoryService,
    ExplorationService? explorationService,
  }) : _territoryService = territoryService ?? TerritoryService(),
       _explorationService = explorationService ?? ExplorationService();

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  /// Evaluates all standard achievements against live athlete metrics
  /// and updates the local unlock timeline whenever a new tier is attained.
  Future<List<TieredProgress>> evaluateAllAchievements() async {
    final profile = _territoryService.getProfile();
    final totalAreaSqm = _territoryService.getCapturedTerritoryObjects().fold(
      0.0,
      (acc, t) => acc + t.areaSqMeters,
    );
    final exploredCells = await _explorationService.getTotalExploredCells();

    final box = await _getBox();
    final results = <TieredProgress>[];

    for (final ach in TieredAchievement.standardCatalog) {
      double metricValue = 0.0;
      switch (ach.id) {
        case 'ach_distance':
          metricValue = profile.totalDistanceKm;
          break;
        case 'ach_territory':
          metricValue = totalAreaSqm;
          break;
        case 'ach_streak':
          metricValue = profile.currentStreak.toDouble();
          break;
        case 'ach_exploration':
          metricValue = exploredCells.toDouble();
          break;
      }

      final progress = ach.evaluate(metricValue);
      results.add(progress);

      // Check if unlocked tiers need to be added to timeline
      if (progress.currentTier != null) {
        final key = '${ach.id}_${progress.currentTier!.name}';
        if (!box.containsKey(key)) {
          final entry = AchievementTimelineEntry(
            achievementId: ach.id,
            title: ach.title,
            tier: progress.currentTier!,
            unlockedAt: DateTime.now(),
          );
          await box.put(key, jsonEncode(entry.toJson()));
          AppLogger.info(
            'Achievement unlocked: ${ach.title} (${progress.currentTier!.label})',
            tag: 'TieredAchievementService',
          );
        }
      }
    }

    return results;
  }

  /// Retrieves chronological timeline of all unlocked achievement tiers.
  Future<List<AchievementTimelineEntry>> getTimeline() async {
    try {
      final box = await _getBox();
      final timeline = <AchievementTimelineEntry>[];
      for (final raw in box.values) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          timeline.add(AchievementTimelineEntry.fromJson(json));
        } catch (_) {}
      }
      timeline.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
      return timeline;
    } catch (e) {
      AppLogger.error(
        'Error fetching achievement timeline: $e',
        tag: 'TieredAchievementService',
      );
      return [];
    }
  }
}
