import 'dart:convert';
import 'dart:math' as math;

import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../core/logging/app_logger.dart';
import '../models/saved_loop.dart';

/// Service managing offline persistent saved loops and real-time route progress tracking.
class SavedLoopService {
  static const String boxName = 'saved_loops_v1';
  static const double offRouteThresholdMeters = 40.0;
  static const Distance _distance = Distance();

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  /// Retrieves all user-saved loops ordered by creation date (newest first).
  Future<List<SavedLoop>> getSavedLoops() async {
    try {
      final box = await _getBox();
      final loops = <SavedLoop>[];
      for (final raw in box.values) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          loops.add(SavedLoop.fromJson(json));
        } catch (e) {
          AppLogger.error(
            'Corrupted saved loop entry: $e',
            tag: 'SavedLoopService',
          );
        }
      }
      loops.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return loops;
    } catch (e) {
      AppLogger.error(
        'Error fetching saved loops: $e',
        tag: 'SavedLoopService',
      );
      return [];
    }
  }

  /// Saves a new loop to local storage.
  Future<SavedLoop> saveLoop({
    required String name,
    required List<LatLng> points,
    required double distanceMeters,
    required double areaSqMeters,
  }) async {
    final box = await _getBox();
    final id = 'loop_${DateTime.now().millisecondsSinceEpoch}_${points.length}';
    final loop = SavedLoop(
      id: id,
      name: name.trim().isEmpty
          ? 'Loop ${(distanceMeters / 1000.0).toStringAsFixed(1)} km'
          : name.trim(),
      points: points,
      distanceMeters: distanceMeters,
      areaSqMeters: areaSqMeters,
      createdAt: DateTime.now(),
      runCount: 0,
    );

    await box.put(id, jsonEncode(loop.toJson()));
    AppLogger.info(
      'Saved loop "${loop.name}" (${loop.distanceMeters.toStringAsFixed(0)}m, ${loop.points.length} pts)',
      tag: 'SavedLoopService',
    );
    return loop;
  }

  /// Deletes a saved loop by its unique ID.
  Future<void> deleteLoop(String id) async {
    final box = await _getBox();
    await box.delete(id);
    AppLogger.info('Deleted saved loop $id', tag: 'SavedLoopService');
  }

  /// Updates run count and personal best time for a completed loop.
  Future<void> recordLoopRun(String id, int durationSeconds) async {
    final box = await _getBox();
    final raw = box.get(id);
    if (raw == null) return;
    try {
      final loop = SavedLoop.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final newBest =
          loop.bestTimeSeconds == null ||
              durationSeconds < loop.bestTimeSeconds!
          ? durationSeconds
          : loop.bestTimeSeconds;
      final updated = loop.copyWith(
        runCount: loop.runCount + 1,
        bestTimeSeconds: newBest,
      );
      await box.put(id, jsonEncode(updated.toJson()));
      AppLogger.info(
        'Updated saved loop $id stats: runs=${updated.runCount}, best=${updated.bestTimeSeconds}s',
        tag: 'SavedLoopService',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to update saved loop stats: $e',
        tag: 'SavedLoopService',
      );
    }
  }

  /// Projects the runner's current location onto the saved route to evaluate
  /// progress fraction, perpendicular distance to route, and off-route status.
  SavedLoopProgress computeProgress(
    LatLng currentPos,
    List<LatLng> routePoints,
  ) {
    if (routePoints.isEmpty) {
      return const SavedLoopProgress(
        progressFraction: 0.0,
        distanceToRouteMeters: 0.0,
        isOffRoute: false,
        remainingDistanceMeters: 0.0,
      );
    }

    if (routePoints.length == 1) {
      final d = _distance.as(LengthUnit.Meter, currentPos, routePoints.first);
      return SavedLoopProgress(
        progressFraction: 0.0,
        distanceToRouteMeters: d,
        isOffRoute: d > offRouteThresholdMeters,
        remainingDistanceMeters: 0.0,
      );
    }

    // Precompute cumulative distance along the polyline
    final cumulativeDist = <double>[0.0];
    double totalRouteMeters = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      final segLen = _distance.as(
        LengthUnit.Meter,
        routePoints[i],
        routePoints[i + 1],
      );
      totalRouteMeters += segLen;
      cumulativeDist.add(totalRouteMeters);
    }

    double minDistanceToRoute = double.infinity;
    double bestProgressMeters = 0.0;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final p0 = routePoints[i];
      final p1 = routePoints[i + 1];

      // Geodesic projection onto segment p0 -> p1
      final proj = _projectPointOnSegment(currentPos, p0, p1);
      final distToSeg = _distance.as(
        LengthUnit.Meter,
        currentPos,
        proj.projectedPoint,
      );

      if (distToSeg < minDistanceToRoute) {
        minDistanceToRoute = distToSeg;
        final segLen = cumulativeDist[i + 1] - cumulativeDist[i];
        bestProgressMeters = cumulativeDist[i] + (proj.t * segLen);
      }
    }

    final fraction = totalRouteMeters > 0
        ? (bestProgressMeters / totalRouteMeters).clamp(0.0, 1.0)
        : 0.0;
    final remaining = math.max(0.0, totalRouteMeters - bestProgressMeters);

    return SavedLoopProgress(
      progressFraction: fraction,
      distanceToRouteMeters: minDistanceToRoute,
      isOffRoute: minDistanceToRoute > offRouteThresholdMeters,
      remainingDistanceMeters: remaining,
    );
  }

  /// Internal projection of point P onto segment A -> B using equirectangular planar approximation.
  _SegmentProjection _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    const latFactor = 111320.0; // meters per degree latitude
    final midLatRad = ((a.latitude + b.latitude) / 2.0) * (math.pi / 180.0);
    final lngFactor = latFactor * math.cos(midLatRad);

    final ax = a.longitude * lngFactor;
    final ay = a.latitude * latFactor;
    final bx = b.longitude * lngFactor;
    final by = b.latitude * latFactor;
    final px = p.longitude * lngFactor;
    final py = p.latitude * latFactor;

    final dx = bx - ax;
    final dy = by - ay;
    final segLenSq = (dx * dx) + (dy * dy);

    if (segLenSq < 1e-6) {
      return _SegmentProjection(projectedPoint: a, t: 0.0);
    }

    final t = (((px - ax) * dx) + ((py - ay) * dy)) / segLenSq;
    final clampedT = t.clamp(0.0, 1.0);

    final projLat = a.latitude + (clampedT * (b.latitude - a.latitude));
    final projLng = a.longitude + (clampedT * (b.longitude - a.longitude));

    return _SegmentProjection(
      projectedPoint: LatLng(projLat, projLng),
      t: clampedT,
    );
  }
}

class _SegmentProjection {
  final LatLng projectedPoint;
  final double t;

  _SegmentProjection({required this.projectedPoint, required this.t});
}
