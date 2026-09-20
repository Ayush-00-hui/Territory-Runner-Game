import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:clipper2/clipper2.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../services/firebase_service.dart';
import 'polygon_enclosure_engine.dart';

class TerritoryService {
  static final TerritoryService _instance = TerritoryService._internal();
  factory TerritoryService() => _instance;

  late final Box<Territory> _territoryBox;
  late final Box<RunnerProfile> _profileBox;
  final FirebaseService _firebaseService = FirebaseService();

  final StreamController<Territory> _captureEventController = StreamController<Territory>.broadcast();
  Stream<Territory> get onTerritoryCaptured => _captureEventController.stream;

  static const double _coordScale = 10000000.0; // 1e7 for high-precision GPS integer clipping

  TerritoryService._internal() {
    _territoryBox = Hive.box<Territory>('territories_v2');
    _profileBox = Hive.box<RunnerProfile>('profile');
    _initProfileIfNeeded();
  }

  void _initProfileIfNeeded() {
    if (_profileBox.isEmpty) {
      _profileBox.put(
        'current_user',
        RunnerProfile(
          id: _firebaseService.currentUserId,
          username: _firebaseService.currentUsername,
          totalDistanceKm: 0.0,
          xp: 0,
          level: 1,
          badges: ['Cyber Rookie'],
          totalHexesClaimed: 0,
          currentStreak: 1,
        ),
      );
    }
  }

  /// Helper: converts LatLng list to Clipper2 Path64
  static Path64 latLngsToPath64(List<LatLng> points) {
    return points
        .map((p) => Point64((p.longitude * _coordScale).round(), (p.latitude * _coordScale).round()))
        .toList();
  }

  /// Helper: converts Clipper2 Path64 to LatLng list
  static List<LatLng> path64ToLatLngs(Path64 path) {
    return path.map((pt) => LatLng(pt.y / _coordScale, pt.x / _coordScale)).toList();
  }

  /// Returns active runner profile
  RunnerProfile getProfile() {
    _initProfileIfNeeded();
    return _profileBox.get('current_user')!;
  }

  /// Updates and saves the runner profile
  Future<void> saveProfile(RunnerProfile profile) async {
    await _profileBox.put('current_user', profile);
    unawaited(_firebaseService.syncProfileToCloud(profile));
  }

  /// Returns all currently captured territory IDs
  List<String> getCapturedTerritories() {
    return _territoryBox.values.map((t) => t.id).toList();
  }

  /// Returns all currently captured Territory model objects
  List<Territory> getCapturedTerritoryObjects() {
    return _territoryBox.values.toList();
  }

  /// Captures an arbitrary enclosed GPS polygon as sovereign player territory.
  /// 1. Unions the new loop with the player's existing territory into a single MultiPolygon.
  /// 2. Uses Clipper difference to contest and carve away overlapping rival territories.
  /// 3. Computes accurate total area in m² and awards XP.
  Future<Territory> capturePolygonTerritory({
    required List<LatLng> polygon,
    required double areaSqMeters,
    String? ownerId,
    Color? color,
    bool isPendingReview = false,
  }) async {
    final String activeOwner = ownerId ?? _firebaseService.currentUserId;
    final Color activeColor = color ?? const Color(0xFF00E676);
    final newPath64 = latLngsToPath64(polygon);

    // 1. Clipper Union: merge with the player's existing captured shapes
    final playerExistingTerritories = _territoryBox.values.where((t) => t.ownerId == activeOwner).toList();
    final Paths64 playerExistingPaths = [];
    for (final t in playerExistingTerritories) {
      for (final poly in t.polygons) {
        if (poly.length >= 3) {
          playerExistingPaths.add(latLngsToPath64(poly));
        }
      }
    }

    final Paths64 mergedPaths = playerExistingPaths.isNotEmpty
        ? Clipper.union(
            subject: playerExistingPaths,
            clip: [newPath64],
            fillRule: FillRule.nonZero,
          )
        : [newPath64];

    final List<List<LatLng>> mergedMultiPolys = mergedPaths.map(path64ToLatLngs).toList();
    final double totalUnifiedAreaSqM = mergedMultiPolys.fold(
      0.0,
      (acc, poly) => acc + PolygonEnclosureEngine.computeGeodesicShoelaceArea(poly),
    );

    // Remove previous fragmented territories for this player to store the unified MultiPolygon
    for (final t in playerExistingTerritories) {
      await _territoryBox.delete(t.id);
    }

    final String territoryId = 'poly_${activeOwner}_territory';
    final unifiedTerritory = Territory(
      id: territoryId,
      ownerId: activeOwner,
      polygon: mergedMultiPolys.isNotEmpty ? mergedMultiPolys.first : polygon,
      polygons: mergedMultiPolys,
      areaSqMeters: totalUnifiedAreaSqM > 0 ? totalUnifiedAreaSqM : areaSqMeters,
      capturedAt: DateTime.now(),
      color: activeColor,
      isPendingReview: isPendingReview,
    );

    await _territoryBox.put(territoryId, unifiedTerritory);

    // 2. Clipper Difference: contest and clip overlapping rival territories
    final rivalTerritories = _territoryBox.values.where((t) => t.ownerId != activeOwner).toList();
    for (final rival in rivalTerritories) {
      final Paths64 rivalPaths = [];
      for (final poly in rival.polygons) {
        if (poly.length >= 3) {
          rivalPaths.add(latLngsToPath64(poly));
        }
      }

      if (rivalPaths.isNotEmpty) {
        final Paths64 clippedRivalPaths = Clipper.difference(
          subject: rivalPaths,
          clip: [newPath64],
          fillRule: FillRule.nonZero,
        );

        if (clippedRivalPaths.isEmpty) {
          // Rival territory completely overtaken
          await _territoryBox.delete(rival.id);
          debugPrint('[TerritoryService] Rival territory ${rival.id} completely conquered by $activeOwner');
        } else {
          final List<List<LatLng>> clippedMultiPolys = clippedRivalPaths.map(path64ToLatLngs).toList();
          final double remainingArea = clippedMultiPolys.fold(
            0.0,
            (acc, poly) => acc + PolygonEnclosureEngine.computeGeodesicShoelaceArea(poly),
          );

          final updatedRival = rival.copyWith(
            polygon: clippedMultiPolys.first,
            polygons: clippedMultiPolys,
            areaSqMeters: remainingArea,
          );
          await _territoryBox.put(rival.id, updatedRival);
          debugPrint('[TerritoryService] Rival territory ${rival.id} clipped to ${remainingArea.toStringAsFixed(1)} m²');
        }
      }
    }

    // 3. Award XP in RunnerProfile
    final profile = getProfile();
    final int gainedXp = profile.claimPolygonArea(areaSqMeters);
    await saveProfile(profile);

    debugPrint(
      '[TerritoryService] Polygon claimed! Player total territory area: ${totalUnifiedAreaSqM.toStringAsFixed(1)}m², XP: +$gainedXp',
    );

    // Emit live capture event
    _captureEventController.add(unifiedTerritory);

    // Sync to Cloud Firestore
    unawaited(_firebaseService.syncTerritoryToCloud(unifiedTerritory));

    return unifiedTerritory;
  }

  /// Records distance added during a run
  Future<void> addRunDistance(double km) async {
    final profile = getProfile();
    profile.addDistance(km);
    await saveProfile(profile);
  }

  /// Saves a specific territory (e.g. captured by rival faction or cloud sync)
  Future<void> saveTerritory(Territory territory) async {
    await _territoryBox.put(territory.id, territory);
    _captureEventController.add(territory);
  }

  /// Wipe all territories (e.g. for testing)
  Future<void> resetTerritories() async {
    await _territoryBox.clear();
  }

  /// Listen to changes in territories to update UI in real-time
  Stream<BoxEvent> get territoryStream => _territoryBox.watch();
}

