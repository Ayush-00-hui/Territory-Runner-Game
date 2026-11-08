import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_logger.dart';
import '../models/crew.dart';
import '../models/season.dart';
import 'api_client.dart';

/// Offline-first service managing active season and crew operations.
class CrewSeasonService {
  static const String _cachedSeasonKey = 'territory_runner_cached_season_data';
  static const String _cachedCrewKey = 'territory_runner_cached_crew_data';
  static const String _lastSyncedKey = 'territory_runner_cached_crew_synced_at';

  static CrewSeasonService? _instance;
  static CrewSeasonService get instance => _instance ??= CrewSeasonService();

  @visibleForTesting
  static void setMockInstance(CrewSeasonService mock) {
    _instance = mock;
  }

  @visibleForTesting
  static void resetMockInstance() {
    _instance = null;
  }

  final ApiClient _apiClient;
  final ValueNotifier<CurrentSeasonData?> currentSeason = ValueNotifier(null);
  final ValueNotifier<MyCrewData?> currentCrew = ValueNotifier(null);
  final ValueNotifier<bool> isOffline = ValueNotifier(false);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

  CrewSeasonService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Loads cached season and crew states from local storage.
  Future<void> loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seasonJson = prefs.getString(_cachedSeasonKey);
      if (seasonJson != null && seasonJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(seasonJson);
        currentSeason.value = CurrentSeasonData.fromJson(data);
      }

      final crewJson = prefs.getString(_cachedCrewKey);
      if (crewJson != null && crewJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(crewJson);
        currentCrew.value = MyCrewData.fromJson(data);
      }

      final syncedStr = prefs.getString(_lastSyncedKey);
      if (syncedStr != null && syncedStr.isNotEmpty) {
        lastSyncedAt.value = DateTime.tryParse(syncedStr)?.toLocal();
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load cached crew & season data: $e',
        tag: 'CrewSeasonService',
      );
    }
  }

  /// Refreshes season and crew from API, falling back to cached state if offline.
  Future<void> refresh() async {
    bool hasNetworkFailure = false;

    try {
      final season = await _apiClient.getCurrentSeason();
      if (season != null) {
        currentSeason.value = season;
        _saveCachedSeason(season);
      }
    } catch (e) {
      hasNetworkFailure = true;
      AppLogger.warning(
        'Failed to fetch current season: $e',
        tag: 'CrewSeasonService',
      );
    }

    try {
      final crew = await _apiClient.getMyCrew();
      if (crew != null) {
        currentCrew.value = crew;
        _saveCachedCrew(crew);
      }
    } catch (e) {
      hasNetworkFailure = true;
      AppLogger.warning(
        'Failed to fetch current crew: $e',
        tag: 'CrewSeasonService',
      );
    }

    if (!hasNetworkFailure) {
      isOffline.value = false;
      final now = DateTime.now();
      lastSyncedAt.value = now;
      _saveLastSyncedAt(now);
    } else {
      isOffline.value = true;
    }
  }

  /// Creates a new crew and refreshes the state.
  Future<Crew?> createCrew(String name) async {
    final crew = await _apiClient.createCrew(name);
    await refresh();
    return crew;
  }

  /// Joins an existing crew with the join code and refreshes state.
  Future<Crew?> joinCrew(String joinCode) async {
    final crew = await _apiClient.joinCrew(joinCode);
    await refresh();
    return crew;
  }

  /// Sets weekly target for the crew (leader only).
  Future<CrewGoal?> setCrewGoal(String goalType, double targetValue) async {
    final goal = await _apiClient.setCrewGoal(goalType, targetValue);
    await refresh();
    return goal;
  }

  Future<void> _saveCachedSeason(CurrentSeasonData season) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedSeasonKey, jsonEncode(season.toJson()));
    } catch (e) {
      AppLogger.warning('Failed to cache season: $e', tag: 'CrewSeasonService');
    }
  }

  Future<void> _saveCachedCrew(MyCrewData crew) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedCrewKey, jsonEncode(crew.toJson()));
    } catch (e) {
      AppLogger.warning('Failed to cache crew: $e', tag: 'CrewSeasonService');
    }
  }

  Future<void> _saveLastSyncedAt(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastSyncedKey,
        timestamp.toUtc().toIso8601String(),
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to save last synced at: $e',
        tag: 'CrewSeasonService',
      );
    }
  }

  /// Purges local cached data on account logout or data reset.
  Future<void> clearLocalCache() async {
    currentSeason.value = null;
    currentCrew.value = null;
    isOffline.value = false;
    lastSyncedAt.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedSeasonKey);
      await prefs.remove(_cachedCrewKey);
      await prefs.remove(_lastSyncedKey);
    } catch (e) {
      AppLogger.warning(
        'Failed to clear crew season cache: $e',
        tag: 'CrewSeasonService',
      );
    }
  }
}
