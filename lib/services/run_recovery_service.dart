import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../core/logging/app_logger.dart';

/// Represents a persisted snapshot of an in-progress athletic run session.
class ActiveRunSnapshot {
  final List<Position> positions;
  final List<LatLng> coordinates;
  final DateTime startTime;
  final int elapsedDurationSeconds;
  final int movingDurationSeconds;
  final double distanceKm;
  final int territoriesClaimed;
  final double accumulatedPreviewArea;
  final int accumulatedPreviewXp;
  final DateTime lastSavedAt;

  ActiveRunSnapshot({
    required this.positions,
    required this.coordinates,
    required this.startTime,
    required this.elapsedDurationSeconds,
    required this.movingDurationSeconds,
    required this.distanceKm,
    required this.territoriesClaimed,
    required this.accumulatedPreviewArea,
    required this.accumulatedPreviewXp,
    required this.lastSavedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'start_time': startTime.toIso8601String(),
      'elapsed_duration_seconds': elapsedDurationSeconds,
      'moving_duration_seconds': movingDurationSeconds,
      'distance_km': distanceKm,
      'territories_claimed': territoriesClaimed,
      'accumulated_preview_area': accumulatedPreviewArea,
      'accumulated_preview_xp': accumulatedPreviewXp,
      'last_saved_at': lastSavedAt.toIso8601String(),
      'coordinates': coordinates.map((c) => {'lat': c.latitude, 'lng': c.longitude}).toList(),
      'positions': positions.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'timestamp': p.timestamp.toIso8601String(),
        'accuracy': p.accuracy,
        'altitude': p.altitude,
        'altitude_accuracy': p.altitudeAccuracy,
        'heading': p.heading,
        'heading_accuracy': p.headingAccuracy,
        'speed': p.speed,
        'speed_accuracy': p.speedAccuracy,
        'is_mocked': p.isMocked,
      }).toList(),
    };
  }

  factory ActiveRunSnapshot.fromMap(Map<String, dynamic> map) {
    final coordsRaw = (map['coordinates'] as List<dynamic>? ?? []);
    final coords = coordsRaw.map((c) {
      final m = c as Map<dynamic, dynamic>;
      return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
    }).toList();

    final posRaw = (map['positions'] as List<dynamic>? ?? []);
    final positions = posRaw.map((p) {
      final m = p as Map<dynamic, dynamic>;
      return Position(
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        timestamp: DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now(),
        accuracy: (m['accuracy'] as num?)?.toDouble() ?? 5.0,
        altitude: (m['altitude'] as num?)?.toDouble() ?? 0.0,
        altitudeAccuracy: (m['altitude_accuracy'] as num?)?.toDouble() ?? 0.0,
        heading: (m['heading'] as num?)?.toDouble() ?? 0.0,
        headingAccuracy: (m['heading_accuracy'] as num?)?.toDouble() ?? 0.0,
        speed: (m['speed'] as num?)?.toDouble() ?? 0.0,
        speedAccuracy: (m['speed_accuracy'] as num?)?.toDouble() ?? 0.0,
        isMocked: m['is_mocked'] as bool? ?? false,
      );
    }).toList();

    return ActiveRunSnapshot(
      positions: positions,
      coordinates: coords,
      startTime: DateTime.tryParse(map['start_time']?.toString() ?? '') ?? DateTime.now(),
      elapsedDurationSeconds: map['elapsed_duration_seconds'] as int? ?? 0,
      movingDurationSeconds: map['moving_duration_seconds'] as int? ?? 0,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      territoriesClaimed: map['territories_claimed'] as int? ?? 0,
      accumulatedPreviewArea: (map['accumulated_preview_area'] as num?)?.toDouble() ?? 0.0,
      accumulatedPreviewXp: map['accumulated_preview_xp'] as int? ?? 0,
      lastSavedAt: DateTime.tryParse(map['last_saved_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Service that persists in-progress runs to Hive for crash/kill resilience.
class RunRecoveryService {
  static const String boxName = 'active_run_recovery';
  static const String activeKey = 'current_active_run';

  static final RunRecoveryService _instance = RunRecoveryService._internal();
  factory RunRecoveryService() => _instance;
  RunRecoveryService._internal();

  Box<String>? _box;

  Future<void> init() async {
    if (_box == null || !Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox<String>(boxName);
    }
  }

  Box<String> get _safeBox {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
      return _box!;
    }
    throw StateError('RunRecoveryService box not opened. Call init() first.');
  }

  /// Persists the active run state to Hive.
  Future<void> saveActiveRun({
    required List<Position> positions,
    required List<LatLng> coordinates,
    required DateTime startTime,
    required int elapsedDurationSeconds,
    required int movingDurationSeconds,
    required double distanceKm,
    required int territoriesClaimed,
    required double accumulatedPreviewArea,
    required int accumulatedPreviewXp,
  }) async {
    try {
      final snapshot = ActiveRunSnapshot(
        positions: positions,
        coordinates: coordinates,
        startTime: startTime,
        elapsedDurationSeconds: elapsedDurationSeconds,
        movingDurationSeconds: movingDurationSeconds,
        distanceKm: distanceKm,
        territoriesClaimed: territoriesClaimed,
        accumulatedPreviewArea: accumulatedPreviewArea,
        accumulatedPreviewXp: accumulatedPreviewXp,
        lastSavedAt: DateTime.now().toUtc(),
      );
      final jsonStr = jsonEncode(snapshot.toMap());
      await _safeBox.put(activeKey, jsonStr);
    } catch (e) {
      AppLogger.error('Failed to persist active run: $e', tag: 'RunRecoveryService', error: e);
    }
  }

  /// Returns true if an unfinished run was recorded within the last 24 hours.
  bool hasRecoverableRun() {
    try {
      final raw = _safeBox.get(activeKey);
      if (raw == null || raw.isEmpty) return false;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = ActiveRunSnapshot.fromMap(map);

      // Must have at least 2 coordinates and be less than 24 hours old
      final age = DateTime.now().toUtc().difference(snapshot.lastSavedAt);
      if (age.inHours > 24) {
        clearRecovery();
        return false;
      }
      return snapshot.coordinates.length >= 2;
    } catch (e) {
      AppLogger.error('Error checking recoverable run: $e', tag: 'RunRecoveryService', error: e);
      return false;
    }
  }

  /// Retrieves the persisted active run snapshot, if valid.
  ActiveRunSnapshot? getRecoverableRun() {
    try {
      final raw = _safeBox.get(activeKey);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ActiveRunSnapshot.fromMap(map);
    } catch (e) {
      AppLogger.error('Error retrieving recoverable run: $e', tag: 'RunRecoveryService', error: e);
      return null;
    }
  }

  /// Clears the recovery cache once the run is successfully finished or explicitly discarded.
  Future<void> clearRecovery() async {
    try {
      await _safeBox.delete(activeKey);
    } catch (e) {
      AppLogger.error('Error clearing recovery: $e', tag: 'RunRecoveryService', error: e);
    }
  }
}
