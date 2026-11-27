import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/run_log_entry.dart';
import 'hive_encryption_service.dart';

/// Personal records calculated strictly from authentic recorded run sessions.
class PersonalRecords {
  final double longestRunDistanceM;
  final double? fastestKmPaceSeconds;
  final double? fastestMilePaceSeconds;
  final double biggestCaptureSqm;
  final double weeklyAreaSqm;
  final int longestStreakDays;

  const PersonalRecords({
    this.longestRunDistanceM = 0.0,
    this.fastestKmPaceSeconds,
    this.fastestMilePaceSeconds,
    this.biggestCaptureSqm = 0.0,
    this.weeklyAreaSqm = 0.0,
    this.longestStreakDays = 0,
  });

  bool get hasAnyRecord =>
      longestRunDistanceM > 0 ||
      fastestKmPaceSeconds != null ||
      biggestCaptureSqm > 0 ||
      longestStreakDays > 0;
}

/// Offline-first service managing the encrypted on-device run log,
/// sample downsampling, 200-run retention, Douglas-Peucker simplification,
/// and personal records calculation.
class RunLogService {
  static const String boxName = 'run_log_v1';
  static const int fullRetentionCap = 200;
  static const int perRunSampleCap = 10000;

  static final RunLogService _instance = RunLogService._internal();
  final HiveEncryptionService _encryptionService;
  Box<String>? _box;

  final ValueNotifier<List<RunLogEntry>> runsNotifier =
      ValueNotifier<List<RunLogEntry>>([]);

  factory RunLogService({
    HiveEncryptionService? encryptionService,
    Box<String>? overrideBox,
  }) {
    if (encryptionService != null || overrideBox != null) {
      return RunLogService.custom(
        encryptionService: encryptionService,
        overrideBox: overrideBox,
      );
    }
    return _instance;
  }

  RunLogService.custom({
    HiveEncryptionService? encryptionService,
    Box<String>? overrideBox,
  }) : _encryptionService = encryptionService ?? HiveEncryptionService(),
       _box = overrideBox {
    if (_box != null && _box!.isOpen) {
      _loadRunsFromBox();
    }
  }

  RunLogService._internal({HiveEncryptionService? encryptionService})
    : _encryptionService = encryptionService ?? HiveEncryptionService();

  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<String>(boxName);
      } else {
        try {
          final cipher = await _encryptionService.getCipherForBox(boxName);
          _box = await Hive.openBox<String>(boxName, encryptionCipher: cipher);
        } catch (e) {
          AppLogger.warning(
            'Failed opening encrypted box $boxName ($e). Retrying without wiping.',
            tag: 'RunLogService',
          );
          rethrow;
        }
      }
    }
    _loadRunsFromBox();
  }

  Box<String> get _safeBox {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
      return _box!;
    }
    throw StateError('RunLogService box not opened. Call init() first.');
  }

  void _loadRunsFromBox() {
    try {
      final List<RunLogEntry> loaded = [];
      for (final raw in _safeBox.values) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          loaded.add(RunLogEntry.fromJson(json));
        } catch (e) {
          AppLogger.warning(
            'Corrupted run log entry skipped: $e',
            tag: 'RunLogService',
          );
        }
      }
      loaded.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      runsNotifier.value = loaded;
    } catch (_) {}
  }

  /// Returns all stored runs sorted chronologically (newest first).
  List<RunLogEntry> getAllRuns() {
    return List<RunLogEntry>.from(runsNotifier.value);
  }

  /// Returns a single run log by its unique ID, or null if not found.
  RunLogEntry? getRun(String id) {
    try {
      final raw = _safeBox.get(id);
      if (raw == null) return null;
      return RunLogEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Persists a completed athletic run log entry to the encrypted Hive box.
  /// Enforces the 10,000-sample per-run cap (decimates 2x on overflow) and
  /// 200-run retention policy (applies Douglas-Peucker simplification to older runs).
  Future<RunLogEntry> recordRun({
    required String id,
    required DateTime startedAt,
    required DateTime endedAt,
    String activityType = 'running',
    required int movingSeconds,
    required int totalSeconds,
    required double distanceM,
    required List<RunSample> samples,
    int? stepCount,
    CadenceStats? cadenceStats,
    int? calories,
    String? calorieModelVersion,
    double? elevationGainM,
    double? elevationLossM,
    double claimedAreaSqM = 0.0,
    int xp = 0,
    String syncStatus = 'synced',
    bool simulated = false,
  }) async {
    // 1. Enforce per-run sample cap with graceful 2x downsampling on overflow
    List<RunSample> effectiveSamples = List<RunSample>.from(samples);
    while (effectiveSamples.length > perRunSampleCap) {
      final List<RunSample> decimated = [];
      for (int i = 0; i < effectiveSamples.length; i += 2) {
        decimated.add(effectiveSamples[i]);
      }
      if (decimated.last != effectiveSamples.last) {
        decimated.add(effectiveSamples.last);
      }
      effectiveSamples = decimated;
    }

    final entry = RunLogEntry(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      activityType: activityType,
      movingSeconds: movingSeconds,
      totalSeconds: totalSeconds,
      distanceM: distanceM,
      samples: effectiveSamples,
      stepCount: stepCount,
      cadenceStats: cadenceStats,
      calories: calories,
      calorieModelVersion: calorieModelVersion,
      elevationGainM: elevationGainM,
      elevationLossM: elevationLossM,
      claimedAreaSqM: claimedAreaSqM,
      xp: xp,
      syncStatus: syncStatus,
      isSimplified: false,
      simulated: simulated,
    );

    await _safeBox.put(id, jsonEncode(entry.toJson()));
    _loadRunsFromBox();

    // 2. Enforce 200-run retention policy: simplify runs beyond the latest 200
    await _applyRetentionPolicy();

    AppLogger.info(
      'Recorded RunLogEntry $id ($distanceM m, $movingSeconds s, ${effectiveSamples.length} samples)',
      tag: 'RunLogService',
    );
    return entry;
  }

  /// Simplifies older runs beyond the 200-run cap via Douglas-Peucker
  Future<void> _applyRetentionPolicy() async {
    try {
      final all = getAllRuns();
      if (all.length <= fullRetentionCap) return;

      // Runs are sorted newest first. Elements beyond index 199 are candidates for simplification.
      for (int i = fullRetentionCap; i < all.length; i++) {
        final olderRun = all[i];
        if (!olderRun.isSimplified && olderRun.samples.length > 2) {
          final simplifiedSamples = douglasPeucker(olderRun.samples, 5.0);
          final updatedRun = olderRun.copyWith(
            samples: simplifiedSamples,
            isSimplified: true,
          );
          await _safeBox.put(olderRun.id, jsonEncode(updatedRun.toJson()));
          AppLogger.info(
            'Retention: Douglas-Peucker simplified older run ${olderRun.id} (${olderRun.samples.length} -> ${simplifiedSamples.length} pts)',
            tag: 'RunLogService',
          );
        }
      }
      _loadRunsFromBox();
    } catch (e) {
      AppLogger.warning(
        'Retention policy execution warning: $e',
        tag: 'RunLogService',
      );
    }
  }

  /// Deletes a single run entry by ID
  Future<void> deleteRun(String id) async {
    await _safeBox.delete(id);
    _loadRunsFromBox();
    AppLogger.info('Deleted RunLogEntry $id', tag: 'RunLogService');
  }

  /// Restores a previously deleted run (e.g. for Undo after swipe-to-delete)
  Future<void> restoreRun(RunLogEntry entry) async {
    await _safeBox.put(entry.id, jsonEncode(entry.toJson()));
    _loadRunsFromBox();
    AppLogger.info('Restored RunLogEntry ${entry.id}', tag: 'RunLogService');
  }

  /// Updates title or notes on a stored run
  Future<void> updateRunMetadata(
    String id, {
    String? title,
    String? notes,
  }) async {
    final entry = getRun(id);
    if (entry == null) return;
    final updated = entry.copyWith(title: title, notes: notes);
    await _safeBox.put(id, jsonEncode(updated.toJson()));
    _loadRunsFromBox();
    AppLogger.info(
      'Updated metadata for RunLogEntry $id',
      tag: 'RunLogService',
    );
  }

  /// Merges remote runs returned by GET /v1/runs into the encrypted local log.
  /// Updates existing entries by ID or idempotency key to 'synced' and adds missing ones.
  Future<int> mergeServerRuns(List<Map<String, dynamic>> serverRuns) async {
    if (serverRuns.isEmpty) return 0;
    int mergedCount = 0;

    final existingById = <String, RunLogEntry>{
      for (final r in getAllRuns()) r.id: r,
    };

    for (final raw in serverRuns) {
      final serverId = raw['id']?.toString() ?? '';
      final idempotencyKey = raw['idempotency_key']?.toString() ?? '';
      final matchKey = existingById.containsKey(serverId)
          ? serverId
          : (idempotencyKey.isNotEmpty &&
                    existingById.containsKey(idempotencyKey)
                ? idempotencyKey
                : '');

      if (matchKey.isNotEmpty) {
        final local = existingById[matchKey]!;
        if (local.syncStatus != 'synced') {
          final updated = local.copyWith(syncStatus: 'synced');
          await _safeBox.put(matchKey, jsonEncode(updated.toJson()));
          mergedCount++;
        }
        continue;
      }

      final entryId = serverId.isNotEmpty ? serverId : idempotencyKey;
      if (entryId.isEmpty) continue;

      final durationSec = (raw['duration_seconds'] as num?)?.toInt() ?? 0;
      final distanceM = (raw['distance_meters'] as num?)?.toDouble() ?? 0.0;
      final areaClaimed = (raw['area_claimed'] as num?)?.toDouble() ?? 0.0;
      final areaStolen = (raw['area_stolen'] as num?)?.toDouble() ?? 0.0;
      final stepCount = (raw['step_count'] as num?)?.toInt();
      final activityType = raw['activity_type']?.toString() ?? 'running';
      final createdAt = raw['created_at'] != null
          ? DateTime.tryParse(raw['created_at'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now();
      final startedAt = createdAt.subtract(Duration(seconds: durationSec));
      final totalAreaGained = areaClaimed + areaStolen;
      final xpAwarded = totalAreaGained >= 25.0
          ? math.max(5, (totalAreaGained / 20.0).round())
          : 0;

      final entry = RunLogEntry(
        id: entryId,
        startedAt: startedAt,
        endedAt: createdAt,
        activityType: activityType.isNotEmpty ? activityType : 'running',
        movingSeconds: durationSec,
        totalSeconds: durationSec,
        distanceM: distanceM,
        samples: const [],
        stepCount: stepCount,
        claimedAreaSqM: areaClaimed,
        xp: xpAwarded,
        syncStatus: raw['status']?.toString() == 'flagged_review'
            ? 'flagged_review'
            : 'synced',
        isSimplified: false,
      );

      await _safeBox.put(entryId, jsonEncode(entry.toJson()));
      mergedCount++;
    }

    if (mergedCount > 0) {
      _loadRunsFromBox();
      await _applyRetentionPolicy();
    }
    return mergedCount;
  }

  /// Clears all stored runs (used during "Delete my data" and account deletion)
  Future<void> clearAllRuns() async {
    await _safeBox.clear();
    runsNotifier.value = [];
    AppLogger.info('Purged all RunLog entries from disk', tag: 'RunLogService');
  }

  bool get isBoxOpen =>
      (_box != null && _box!.isOpen) || Hive.isBoxOpen(boxName);

  /// Computes real consecutive calendar-day streak ending today or yesterday
  /// across non-simulated runs (ignoring tiny jitter < 100 m).
  int computeActiveStreakDays({
    List<RunLogEntry>? overrideRuns,
    DateTime? referenceNow,
  }) {
    final runs = overrideRuns ?? (isBoxOpen ? runsNotifier.value : const []);
    final uniqueDays = <DateTime>{};
    for (final run in runs) {
      if (run.simulated || run.distanceM < 100.0) continue;
      uniqueDays.add(
        DateTime.utc(
          run.startedAt.year,
          run.startedAt.month,
          run.startedAt.day,
        ),
      );
    }
    if (uniqueDays.isEmpty) return 0;

    final now = referenceNow ?? DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final yesterday = DateTime.utc(now.year, now.month, now.day - 1);

    DateTime cursor;
    if (uniqueDays.contains(today)) {
      cursor = today;
    } else if (uniqueDays.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (uniqueDays.contains(cursor)) {
      streak++;
      cursor = DateTime.utc(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// Computes personal records derived exclusively from real recorded runs.
  PersonalRecords computePersonalRecords({List<RunLogEntry>? overrideRuns}) {
    final runs = (overrideRuns ?? runsNotifier.value)
        .where((r) => !r.simulated)
        .toList();
    if (runs.isEmpty) {
      return const PersonalRecords();
    }

    double longestRunDist = 0.0;
    double biggestCapture = 0.0;
    double? fastestKmPace;
    double? fastestMilePace;
    double weeklyArea = 0.0;

    final now = DateTime.now();
    final weekWindowStart = DateTime(now.year, now.month, now.day - 6);

    for (final run in runs) {
      if (run.distanceM > longestRunDist) {
        longestRunDist = run.distanceM;
      }
      if (run.claimedAreaSqM > biggestCapture) {
        biggestCapture = run.claimedAreaSqM;
      }

      // Fastest km pace: for runs >= 1000m
      if (run.distanceM >= 1000.0 && run.movingSeconds > 0) {
        final pace = run.paceSecondsPerKm;
        if (fastestKmPace == null || pace < fastestKmPace) {
          fastestKmPace = pace;
        }
      }

      // Fastest mile pace: for runs >= 1609.34m
      if (run.distanceM >= 1609.344 && run.movingSeconds > 0) {
        final pace = run.paceSecondsPerMile;
        if (fastestMilePace == null || pace < fastestMilePace) {
          fastestMilePace = pace;
        }
      }

      // Weekly area: runs completed in the last 7 calendar days up to now
      if (!run.endedAt.isBefore(weekWindowStart) && !run.endedAt.isAfter(now)) {
        weeklyArea += run.claimedAreaSqM;
      }
    }

    // Longest streak: max consecutive calendar days with a completed run (DST-safe UTC calendar dates)
    final uniqueDays = <DateTime>{};
    for (final run in runs) {
      uniqueDays.add(
        DateTime.utc(
          run.startedAt.year,
          run.startedAt.month,
          run.startedAt.day,
        ),
      );
    }
    final sortedDays = uniqueDays.toList()..sort();

    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? prevDay;

    for (final day in sortedDays) {
      if (prevDay == null) {
        currentStreak = 1;
      } else if (day.difference(prevDay).inDays == 1) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
      prevDay = day;
    }

    return PersonalRecords(
      longestRunDistanceM: longestRunDist,
      fastestKmPaceSeconds: fastestKmPace,
      fastestMilePaceSeconds: fastestMilePace,
      biggestCaptureSqm: biggestCapture,
      weeklyAreaSqm: weeklyArea,
      longestStreakDays: longestStreak,
    );
  }
}
