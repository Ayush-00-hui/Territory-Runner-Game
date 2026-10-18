import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging/app_logger.dart';
import '../models/privacy_zone.dart';
import '../models/territory.dart';
import 'api_client.dart';

/// Service responsible for managing user privacy exclusion zones (Home, Work)
/// and redacting GPS tracks or territorial claims that touch sensitive locations.
///
/// Note: In Territory Runner, territory polygons themselves stay public because
/// territorial conquest is the core game mechanic. However, raw GPS tracks,
/// start/end coordinates, and live runner presence inside privacy zones are strictly
/// suppressed and redacted from rivals and public exports.
class PrivacyZoneService {
  static final PrivacyZoneService _instance = PrivacyZoneService._internal();
  factory PrivacyZoneService() => _instance;

  PrivacyZoneService._internal();

  static const String _storageKey = 'territory_runner_privacy_zones';
  static const Distance _distanceCalc = Distance();

  /// Maximum allowed privacy exclusion zones per user to prevent performance degradation
  static const int maxZones = 5;

  /// Minimum allowable radius in meters
  static const double minRadius = 50.0;

  /// Maximum allowable radius in meters
  static const double maxRadius = 2000.0;

  final List<PrivacyZone> _zones = [];
  bool _isLoaded = false;

  /// Current list of configured privacy zones
  List<PrivacyZone> get zones => List.unmodifiable(_zones);

  /// Load privacy zones from persistent storage
  Future<List<PrivacyZone>> loadZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      _zones.clear();
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _zones.add(PrivacyZone.fromJson(item));
          }
        }
      }
      _isLoaded = true;
    } catch (e, st) {
      AppLogger.error('Error loading privacy zones', error: e, stackTrace: st, tag: 'PrivacyZoneService');
    }
    return zones;
  }

  Future<void> _saveZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_zones.map((z) => z.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      AppLogger.error('Error saving privacy zones: $e', tag: 'PrivacyZoneService', error: e);
    }
  }

  /// Syncs configured privacy zones with the backend server.
  /// Supports offline-first: persists locally first; if the server is unreachable,
  /// the operation completes gracefully and local zones remain active.
  Future<bool> syncWithServer([ApiClient? apiClient]) async {
    final client = apiClient ?? ApiClient();
    try {
      final success = await client.putPrivacyZones(_zones);
      if (success) {
        AppLogger.info('Successfully synchronized ${_zones.length} privacy zones with server', tag: 'PrivacyZoneService');
        return true;
      }
    } catch (e) {
      AppLogger.warning('Server sync skipped or failed (offline-first preserved): $e', tag: 'PrivacyZoneService');
    }
    return false;
  }

  /// Fetches privacy zones from server and merges with local storage.
  Future<void> fetchAndSyncFromServer([ApiClient? apiClient]) async {
    final client = apiClient ?? ApiClient();
    try {
      final serverZones = await client.getPrivacyZones();
      if (serverZones.isNotEmpty) {
        _zones.clear();
        _zones.addAll(serverZones);
        await _saveZones();
        _isLoaded = true;
      }
    } catch (e) {
      AppLogger.warning('Failed to fetch privacy zones from server: $e', tag: 'PrivacyZoneService');
    }
  }

  /// Add a new privacy exclusion zone
  Future<void> addZone(PrivacyZone zone, {ApiClient? apiClient}) async {
    if (!_isLoaded) await loadZones();
    if (_zones.length >= maxZones) {
      throw StateError('Maximum $maxZones privacy zones allowed');
    }
    _zones.add(zone);
    await _saveZones();
    if (apiClient != null) {
      await syncWithServer(apiClient);
    }
  }

  /// Update an existing privacy zone (e.g. adjust radius or rename)
  Future<void> updateZone(PrivacyZone updatedZone, {ApiClient? apiClient}) async {
    if (!_isLoaded) await loadZones();
    final idx = _zones.indexWhere((z) => z.id == updatedZone.id);
    if (idx != -1) {
      _zones[idx] = updatedZone;
      await _saveZones();
      if (apiClient != null) {
        await syncWithServer(apiClient);
      }
    }
  }

  /// Delete a privacy zone
  Future<void> deleteZone(String id, {ApiClient? apiClient}) async {
    if (!_isLoaded) await loadZones();
    _zones.removeWhere((z) => z.id == id);
    await _saveZones();
    if (apiClient != null) {
      await syncWithServer(apiClient);
    }
  }

  /// Enable or disable a privacy zone
  Future<void> toggleZone(String id, bool isEnabled, {ApiClient? apiClient}) async {
    if (!_isLoaded) await loadZones();
    final idx = _zones.indexWhere((z) => z.id == id);
    if (idx != -1) {
      _zones[idx] = _zones[idx].copyWith(isEnabled: isEnabled);
      await _saveZones();
      if (apiClient != null) {
        await syncWithServer(apiClient);
      }
    }
  }

  /// Checks if a single coordinate point lies within any active privacy zone
  bool isPointInPrivacyZone(LatLng point) {
    for (final zone in _zones) {
      if (!zone.isEnabled) continue;
      final double distanceMeters = _distanceCalc.as(
        LengthUnit.Meter,
        point,
        zone.center,
      );
      if (distanceMeters <= zone.radiusMeters) {
        return true;
      }
    }
    return false;
  }

  /// Filters a GPS track by omitting points that fall inside any active privacy zone.
  /// If track segments enter and exit, the sensitive section is cleanly redacted.
  List<LatLng> filterGpsTrack(List<LatLng> points) {
    if (_zones.isEmpty || !_zones.any((z) => z.isEnabled)) {
      return points;
    }
    return points.where((p) => !isPointInPrivacyZone(p)).toList();
  }

  /// Checks if a polygon's centroid or majority of vertices fall within an active privacy zone
  bool isPolygonInPrivacyZone(List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    if (_zones.isEmpty || !_zones.any((z) => z.isEnabled)) return false;

    // 1. Check centroid
    double sumLat = 0;
    double sumLng = 0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    final centroid = LatLng(sumLat / polygon.length, sumLng / polygon.length);
    if (isPointInPrivacyZone(centroid)) {
      return true;
    }

    // 2. Check if at least half of vertices are inside
    int insideCount = 0;
    for (final p in polygon) {
      if (isPointInPrivacyZone(p)) {
        insideCount++;
      }
    }
    return insideCount > (polygon.length / 2);
  }

  /// Returns territories. Territory polygons themselves stay public on the map
  /// because territorial conquest is the game.
  List<Territory> filterTerritories(List<Territory> territories) {
    // Territory polygons stay public (they are the game arena)
    return territories;
  }
}

