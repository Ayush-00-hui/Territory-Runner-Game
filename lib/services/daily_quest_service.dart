import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_logger.dart';
import '../features/gameplay/territory_service.dart';
import '../models/run_log_entry.dart';
import '../models/runner_profile.dart';
import 'run_log_service.dart';

/// Represents a concrete daily running/exploration quest and its live progress.
class DailyQuestProgress {
  final String id;
  final String title;
  final String description;
  final double current;
  final double target;
  final String unit;
  final int xpReward;
  final bool isClaimed;

  const DailyQuestProgress({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.unit,
    required this.xpReward,
    this.isClaimed = false,
  });

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => progress >= 1.0;

  DailyQuestProgress copyWith({bool? isClaimed}) => DailyQuestProgress(
    id: id,
    title: title,
    description: description,
    current: current,
    target: target,
    unit: unit,
    xpReward: xpReward,
    isClaimed: isClaimed ?? this.isClaimed,
  );
}

/// Manages rotating daily quests, block-discovery daily progress, and XP payouts.
class DailyQuestService {
  static final DailyQuestService _instance = DailyQuestService._internal();
  factory DailyQuestService() => _instance;
  DailyQuestService._internal();

  static const String _claimedPrefix = 'daily_quests_claimed_v1_';
  static const String _blocksPrefix = 'daily_blocks_discovered_v1_';
  static const String _defendedPrefix = 'daily_defended_v1_';

  final ValueNotifier<int> revisionNotifier = ValueNotifier<int>(0);

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Records newly explored 100m map blocks discovered during today's runs.
  Future<void> recordNewBlocksToday(int count, {DateTime? now}) async {
    if (count <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_blocksPrefix${_dateKey(now ?? DateTime.now())}';
      final prev = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, prev + count);
      revisionNotifier.value++;
    } catch (_) {}
  }

  /// Records a territory defense/fortification action completed today.
  Future<void> recordDefenseToday({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_defendedPrefix${_dateKey(now ?? DateTime.now())}';
      await prefs.setBool(key, true);
      revisionNotifier.value++;
    } catch (_) {}
  }

  /// Synchronously builds today's 3 rotating daily quests from the given state.
  List<DailyQuestProgress> getTodayQuestsSync({
    DateTime? now,
    List<RunLogEntry>? overrideRuns,
    double? totalAreaSqMeters,
    int todayBlocks = 0,
    bool defendedToday = false,
    Set<String> claimedIds = const {},
  }) {
    final currentNow = now ?? DateTime.now();
    final todayStart = DateTime(
      currentNow.year,
      currentNow.month,
      currentNow.day,
    );
    final dateKey = _dateKey(currentNow);
    final daySeed =
        currentNow.difference(DateTime(currentNow.year, 1, 1)).inDays +
        currentNow.year;

    final runs =
        overrideRuns ??
        (RunLogService().isBoxOpen ? RunLogService().getAllRuns() : const []);
    final todayRuns = runs
        .where((r) => !r.simulated && !r.startedAt.isBefore(todayStart))
        .toList();

    final double todayDistanceKm = todayRuns.fold(
      0.0,
      (sum, r) => sum + (r.distanceM / 1000.0),
    );
    final double todayClaimedSqm = todayRuns.fold(
      0.0,
      (sum, r) => sum + r.claimedAreaSqM,
    );
    final int todayLoopCount = todayRuns
        .where((r) => r.claimedAreaSqM >= 25.0)
        .length;
    final int todayActiveMinutes =
        todayRuns.fold<int>(0, (sum, r) => sum + r.movingSeconds) ~/ 60;

    // Rotating Distance Quest
    const distanceTargets = [1.5, 2.0, 3.0];
    const distanceTitles = [
      'Morning or evening stride',
      'Daily distance run',
      'Steady 3K push',
    ];
    final distIdx = daySeed % distanceTargets.length;
    final distTarget = distanceTargets[distIdx];
    final distId = 'quest_dist_${dateKey}_$distIdx';

    // Rotating Territory Loop / Claim Quest
    final loopVariant = (daySeed + 1) % 3;
    final DailyQuestProgress territoryQuest;
    if (loopVariant == 0) {
      final id = 'quest_loop_${dateKey}_0';
      territoryQuest = DailyQuestProgress(
        id: id,
        title: 'Loop closure',
        description: 'Enclose and claim at least 1 loop on foot today',
        current: todayLoopCount.toDouble(),
        target: 1.0,
        unit: 'loop',
        xpReward: 120,
        isClaimed: claimedIds.contains(id),
      );
    } else if (loopVariant == 1) {
      final id = 'quest_area_${dateKey}_1';
      territoryQuest = DailyQuestProgress(
        id: id,
        title: 'Fresh turf claim',
        description: 'Claim 500 m² of closed territory today',
        current: todayClaimedSqm,
        target: 500.0,
        unit: 'm²',
        xpReward: 140,
        isClaimed: claimedIds.contains(id),
      );
    } else {
      final id = 'quest_hold_${dateKey}_2';
      final defendedOrClaimed = (defendedToday || todayLoopCount > 0)
          ? 1.0
          : 0.0;
      territoryQuest = DailyQuestProgress(
        id: id,
        title: 'Guard your turf',
        description: 'Complete a loop or fortify an owned area today',
        current: defendedOrClaimed,
        target: 1.0,
        unit: 'run',
        xpReward: 110,
        isClaimed: claimedIds.contains(id),
      );
    }

    // Rotating Explorer / Consistency Quest
    final exploreVariant = (daySeed + 2) % 3;
    final DailyQuestProgress exploreQuest;
    if (exploreVariant == 0) {
      final id = 'quest_blocks_${dateKey}_0';
      exploreQuest = DailyQuestProgress(
        id: id,
        title: 'Neighborhood scout',
        description: 'Discover 5 new map blocks on foot today',
        current: todayBlocks.toDouble(),
        target: 5.0,
        unit: 'blocks',
        xpReward: 95,
        isClaimed: claimedIds.contains(id),
      );
    } else if (exploreVariant == 1) {
      final id = 'quest_mins_${dateKey}_1';
      exploreQuest = DailyQuestProgress(
        id: id,
        title: 'Active 15 minutes',
        description: 'Log at least 15 moving minutes today',
        current: todayActiveMinutes.toDouble(),
        target: 15.0,
        unit: 'min',
        xpReward: 85,
        isClaimed: claimedIds.contains(id),
      );
    } else {
      final id = 'quest_footprint_${dateKey}_2';
      final area = totalAreaSqMeters ?? todayClaimedSqm;
      exploreQuest = DailyQuestProgress(
        id: id,
        title: 'Territory expansion',
        description: 'Hold or claim 10,000 m² of ground',
        current: math.max(area, todayClaimedSqm),
        target: 10000.0,
        unit: 'm²',
        xpReward: 200,
        isClaimed: claimedIds.contains(id),
      );
    }

    return [
      DailyQuestProgress(
        id: distId,
        title: distanceTitles[distIdx],
        description:
            'Cover at least ${distTarget.toStringAsFixed(1)} km on foot today',
        current: todayDistanceKm,
        target: distTarget,
        unit: 'km',
        xpReward: (distTarget * 40).round(),
        isClaimed: claimedIds.contains(distId),
      ),
      territoryQuest,
      exploreQuest,
    ];
  }

  /// Evaluates today's 3 rotating daily quests from real run logs & cached daily metrics.
  Future<List<DailyQuestProgress>> getTodayQuests({
    DateTime? now,
    List<RunLogEntry>? overrideRuns,
    double? totalAreaSqMeters,
  }) async {
    final currentNow = now ?? DateTime.now();
    final dateKey = _dateKey(currentNow);

    int todayBlocks = 0;
    bool defendedToday = false;
    Set<String> claimedIds = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      todayBlocks = prefs.getInt('$_blocksPrefix$dateKey') ?? 0;
      defendedToday = prefs.getBool('$_defendedPrefix$dateKey') ?? false;
      final rawClaimed = prefs.getString('$_claimedPrefix$dateKey');
      if (rawClaimed != null && rawClaimed.isNotEmpty) {
        claimedIds = (jsonDecode(rawClaimed) as List).cast<String>().toSet();
      }
    } catch (_) {}

    return getTodayQuestsSync(
      now: currentNow,
      overrideRuns: overrideRuns,
      totalAreaSqMeters: totalAreaSqMeters,
      todayBlocks: todayBlocks,
      defendedToday: defendedToday,
      claimedIds: claimedIds,
    );
  }

  /// Evaluates today's quests, grants real XP to [RunnerProfile] for any newly
  /// completed & unclaimed quests, and returns the list of newly rewarded quests.
  Future<List<DailyQuestProgress>> claimCompletedQuests({
    DateTime? now,
    TerritoryService? territoryService,
    List<RunLogEntry>? overrideRuns,
    double? totalAreaSqMeters,
  }) async {
    final currentNow = now ?? DateTime.now();
    final dateKey = _dateKey(currentNow);
    final ts = territoryService ?? TerritoryService();
    final double heldArea =
        totalAreaSqMeters ??
        ts.getCapturedTerritoryObjects().fold(
          0.0,
          (s, t) => s + t.areaSqMeters,
        );

    final quests = await getTodayQuests(
      now: currentNow,
      overrideRuns: overrideRuns,
      totalAreaSqMeters: heldArea,
    );

    final newlyCompleted = quests
        .where((q) => q.isCompleted && !q.isClaimed)
        .toList();
    if (newlyCompleted.isEmpty) return const [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final claimedKey = '$_claimedPrefix$dateKey';
      final rawClaimed = prefs.getString(claimedKey);
      final Set<String> claimedIds = rawClaimed != null && rawClaimed.isNotEmpty
          ? (jsonDecode(rawClaimed) as List).cast<String>().toSet()
          : <String>{};

      int totalAwardedXp = 0;
      for (final q in newlyCompleted) {
        if (claimedIds.add(q.id)) {
          totalAwardedXp += q.xpReward;
        }
      }

      if (totalAwardedXp > 0) {
        final RunnerProfile profile = ts.getProfile();
        profile.addXp(totalAwardedXp);
        await ts.saveProfile(profile);
        await prefs.setString(claimedKey, jsonEncode(claimedIds.toList()));
        AppLogger.info(
          'Awarded +$totalAwardedXp XP across ${newlyCompleted.length} daily quests',
          tag: 'DailyQuestService',
        );
      }
      revisionNotifier.value++;
      return newlyCompleted.map((q) => q.copyWith(isClaimed: true)).toList();
    } catch (e) {
      AppLogger.warning(
        'Failed persisting claimed daily quests: $e',
        tag: 'DailyQuestService',
      );
      return const [];
    }
  }
}
