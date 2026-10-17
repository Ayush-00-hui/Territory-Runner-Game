import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/privacy_zone.dart';
import '../models/territory.dart';

/// Service responsible for managing user privacy exclusion zones (Home, Work)
/// and redacting GPS tracks or territorial claims that touch sensitive locations.
class PrivacyZoneService {
  static final PrivacyZoneService _instance = PrivacyZoneService._internal();
  factory PrivacyZoneService() => _instance;

  PrivacyZoneService._internal();

  static const String _storageKey = 'territory_runner_privacy_zones';
  static const Distance _distanceCalc = Distance();

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
    } catch (e) {
      debugPrint('[PrivacyZoneService] Error loading privacy zones: $e');
    }
    return zones;
  }

  Future<void> _saveZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_zones.map((z) => z.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[PrivacyZoneService] Error saving privacy zones: $e');
    }
  }

  /// Add a new privacy exclusion zone
  Future<void> addZone(PrivacyZone zone) async {
    if (!_isLoaded) await loadZones();
    _zones.add(zone);
    await _saveZones();
  }

  /// Update an existing privacy zone (e.g. adjust radius or rename)
  Future<void> updateZone(PrivacyZone updatedZone) async {
    if (!_isLoaded) await loadZones();
    final idx = _zones.indexWhere((z) => z.id == updatedZone.id);
    if (idx != -1) {
      _zones[idx] = updatedZone;
      await _saveZones();
    }
  }

  /// Delete a privacy zone
  Future<void> deleteZone(String id) async {
    if (!_isLoaded) await loadZones();
    _zones.removeWhere((z) => z.id == id);
    await _saveZones();
  }

  /// Enable or disable a privacy zone
  Future<void> toggleZone(String id, bool isEnabled) async {
    if (!_isLoaded) await loadZones();
    final idx = _zones.indexWhere((z) => z.id == id);
    if (idx != -1) {
      _zones[idx] = _zones[idx].copyWith(isEnabled: isEnabled);
      await _saveZones();
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

  /// Filters a list of territories, omitting any that fall inside active privacy zones
  List<Territory> filterTerritories(List<Territory> territories) {
    if (_zones.isEmpty || !_zones.any((z) => z.isEnabled)) {
      return territories;
    }
    return territories.where((t) => !isPolygonInPrivacyZone(t.polygon)).toList();
  }
}
