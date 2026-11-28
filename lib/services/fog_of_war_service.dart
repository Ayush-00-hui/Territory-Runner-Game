import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_logger.dart';

/// Persistent service managing city Fog of War, tracking visited coordinate cells,
/// and computing district exploration coverage.
class FogOfWarService extends ChangeNotifier {
  static final FogOfWarService _instance = FogOfWarService._internal();
  factory FogOfWarService() => _instance;
  FogOfWarService._internal();

  static const String _prefKey = 'territory_fog_visited_cells_v1';
  // Grid resolution: ~0.00045 degrees latitude is roughly 50 meters
  static const double _gridCellSizeDegrees = 0.00045;

  final Set<String> _visitedCells = {};
  final List<LatLng> _recentExploredPoints = [];

  Set<String> get visitedCells => Set.unmodifiable(_visitedCells);
  List<LatLng> get recentExploredPoints =>
      List.unmodifiable(_recentExploredPoints);

  /// Approximate explored land area in square kilometers (each 50m cell ≈ 0.0025 km²)
  double get totalExploredAreaSqKm => (_visitedCells.length * 0.0025);

  /// Exploration percentage of the active metropolitan region (based on a nominal 50 km² urban footprint)
  double get urbanExplorationPercentage =>
      ((totalExploredAreaSqKm / 50.0) * 100.0).clamp(0.1, 100.0);

  /// Loads saved explored cells from persistent storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefKey);
      if (savedJson != null) {
        final List<dynamic> list = jsonDecode(savedJson);
        _visitedCells.addAll(list.map((e) => e.toString()));
        AppLogger.info(
          'Loaded ${_visitedCells.length} explored Fog of War cells from disk.',
          tag: 'FogOfWarService',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load Fog of War cache: $e',
        tag: 'FogOfWarService',
      );
    }
  }

  /// Clears fog of war in a 50m radius around runner coordinate
  void revealFogAt(LatLng position) {
    _recentExploredPoints.add(position);
    if (_recentExploredPoints.length > 500) {
      _recentExploredPoints.removeAt(0);
    }

    final cellX = (position.latitude / _gridCellSizeDegrees).floor();
    final cellY = (position.longitude / _gridCellSizeDegrees).floor();

    // Reveal 3x3 block around current position
    bool newlyAdded = false;
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final key = '${cellX + dx},${cellY + dy}';
        if (_visitedCells.add(key)) {
          newlyAdded = true;
        }
      }
    }

    if (newlyAdded) {
      notifyListeners();
    }
  }

  /// Persists explored cells to storage
  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_visitedCells.toList()));
    } catch (e) {
      AppLogger.warning(
        'Failed to persist Fog of War cells: $e',
        tag: 'FogOfWarService',
      );
    }
  }
}
