import 'dart:math' as math;

import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../core/logging/app_logger.dart';
import 'privacy_zone_service.dart';

/// Local-only service managing runner geographic exploration and fog-of-war grid cells.
/// All cell coordinates and visited timestamps remain 100% on the local device.
class ExplorationService {
  static const String boxName = 'exploration_cells_v1';
  static const double cellSizeDegrees = 0.001; // ~100m grid cell resolution

  final PrivacyZoneService _privacyZoneService;
  Box<int>? _box;

  ExplorationService({PrivacyZoneService? privacyZoneService})
    : _privacyZoneService = privacyZoneService ?? PrivacyZoneService();

  Future<Box<int>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<int>(boxName);
    return _box!;
  }

  /// Converts a latitude/longitude coordinate to a discrete grid cell identifier.
  static String getCellKey(double lat, double lng) {
    final x = (lat / cellSizeDegrees).floor();
    final y = (lng / cellSizeDegrees).floor();
    return '${x}_$y';
  }

  /// Returns total number of unique cells revealed by the runner.
  Future<int> getTotalExploredCells() async {
    final box = await _getBox();
    return box.length;
  }

  /// Discovers and records all cells crossed by the given GPS track.
  /// Automatically filters out points falling within configured privacy zones.
  /// Returns the count of newly discovered cells during this run.
  Future<int> recordVisitedPoints(List<LatLng> points) async {
    if (points.isEmpty) return 0;

    final box = await _getBox();
    final privacyZones = await _privacyZoneService.loadZones();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int newlyDiscovered = 0;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      // Privacy Zone check: do not reveal or store cells inside privacy zones
      bool inPrivacyZone = false;
      for (final zone in privacyZones) {
        if (zone.contains(p.latitude, p.longitude)) {
          inPrivacyZone = true;
          break;
        }
      }
      if (inPrivacyZone) continue;

      final key = getCellKey(p.latitude, p.longitude);
      if (!box.containsKey(key)) {
        await box.put(key, nowMs);
        newlyDiscovered++;
      }

      // Linear interpolation for gaps > 60m between consecutive fixes
      if (i < points.length - 1) {
        final pNext = points[i + 1];
        final dist = const Distance().as(LengthUnit.Meter, p, pNext);
        if (dist > 60.0 && dist < 500.0) {
          final steps = (dist / 50.0).ceil();
          for (int s = 1; s < steps; s++) {
            final t = s / steps;
            final interLat = p.latitude + (t * (pNext.latitude - p.latitude));
            final interLng =
                p.longitude + (t * (pNext.longitude - p.longitude));
            final interKey = getCellKey(interLat, interLng);
            if (!box.containsKey(interKey)) {
              await box.put(interKey, nowMs);
              newlyDiscovered++;
            }
          }
        }
      }
    }

    if (newlyDiscovered > 0) {
      AppLogger.info(
        'Exploration: discovered $newlyDiscovered new grid cells (total: ${box.length})',
        tag: 'ExplorationService',
      );
    }
    return newlyDiscovered;
  }

  /// Computes the exploration density percentage within a radius around the runner.
  Future<double> getAreaExplorationPercentage({
    required LatLng center,
    double radiusKm = 2.0,
  }) async {
    final box = await _getBox();
    if (box.isEmpty) return 0.0;

    // Approximate total expected cells within disc of radiusKm:
    // Area = pi * r^2. Each cell is ~0.01 km^2 (100m x 100m).
    final approxTotalCells = (math.pi * radiusKm * radiusKm) / 0.01;
    if (approxTotalCells <= 0) return 0.0;

    final minLat = center.latitude - (radiusKm / 111.32);
    final maxLat = center.latitude + (radiusKm / 111.32);
    final minLng =
        center.longitude -
        (radiusKm / (111.32 * math.cos(center.latitude * (math.pi / 180.0))));
    final maxLng =
        center.longitude +
        (radiusKm / (111.32 * math.cos(center.latitude * (math.pi / 180.0))));

    int visitedInRadius = 0;
    for (final rawKey in box.keys) {
      final key = rawKey.toString();
      final parts = key.split('_');
      if (parts.length != 2) continue;
      final x = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      if (x == null || y == null) continue;

      final cellLat = (x + 0.5) * cellSizeDegrees;
      final cellLng = (y + 0.5) * cellSizeDegrees;

      if (cellLat >= minLat &&
          cellLat <= maxLat &&
          cellLng >= minLng &&
          cellLng <= maxLng) {
        visitedInRadius++;
      }
    }

    final percentage = (visitedInRadius / approxTotalCells) * 100.0;
    return percentage.clamp(0.0, 100.0);
  }
}
