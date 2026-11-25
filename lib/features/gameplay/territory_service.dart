import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:clipper2/clipper2.dart';

import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../services/api_client.dart';
import '../../services/firebase_service.dart';
import '../../ui/theme/app_colors.dart';
import '../../core/logging/app_logger.dart';
import 'polygon_enclosure_engine.dart';

class TerritoryService {
  static final TerritoryService _instance = TerritoryService._internal();
  factory TerritoryService() => _instance;

  Box<Territory>? get _territoryBox => Hive.isBoxOpen('territories_v3')
      ? Hive.box<Territory>('territories_v3')
      : null;
  Box<RunnerProfile>? get _profileBox =>
      Hive.isBoxOpen('profile') ? Hive.box<RunnerProfile>('profile') : null;
  final FirebaseService _firebaseService = FirebaseService();

  final StreamController<Territory> _captureEventController =
      StreamController<Territory>.broadcast();
  Stream<Territory> get onTerritoryCaptured => _captureEventController.stream;

  static const double _coordScale =
      10000000.0; // 1e7 for high-precision GPS integer clipping

  /// Smallest amount of genuinely new area (m²) that counts as a claim.
  /// Prevents farming XP by re-running loops inside land you already own.
  static const double minClaimAreaSqMeters = 25.0;

  /// Result of the most recent [capturePolygonTerritory] call, read by the UI
  /// so the celebration shows what was really gained (not the raw loop area).
  int lastCaptureXp = 0;
  double lastCaptureNetAreaSqM = 0.0;
  double lastCaptureStolenAreaSqM = 0.0;

  /// Total area of polygon rings. Holes (opposite orientation) are subtracted.
  static double _netAreaOf(List<List<LatLng>> polys) {
    double signed = 0.0;
    for (final poly in polys) {
      signed += PolygonEnclosureEngine.computeSignedGeodesicShoelaceArea(poly);
    }
    return signed.abs();
  }

  TerritoryService._internal() {
    _cleanLegacyHexes();
    _initProfileIfNeeded();
  }

  void _cleanLegacyHexes() {
    final box = _territoryBox;
    if (box == null) return;
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final t = box.get(key);
      if (t != null) {
        // Only remove genuine legacy hex-grid records. Polygon territories use the
        // 'poly_' prefix and may legitimately have any vertex count (including 6),
        // so they must never be deleted here.
        final bool isPolygonTerritory = t.id.startsWith('poly_');
        final bool isLegacyHex =
            t.id.startsWith('hex_') ||
            RegExp(r'^8[0-9a-f]{14}$').hasMatch(t.id);
        if (!isPolygonTerritory && isLegacyHex) {
          keysToDelete.add(key);
        }
      }
    }
    for (final k in keysToDelete) {
      box.delete(k);
    }
  }

  void _initProfileIfNeeded() {
    final box = _profileBox;
    if (box == null) return;
    if (box.isEmpty) {
      final uid = _firebaseService.currentUserId;
      box.put(
        'current_user',
        RunnerProfile(
          id: uid,
          runnerCode: RunnerProfile.generateFallbackCode(uid),
          username: _firebaseService.currentUsername,
          totalDistanceKm: 0.0,
          xp: 0,
          level: 1,
          badges: ['Rookie Runner'],
          totalTerritoriesClaimed: 0,
          currentStreak: 1,
        ),
      );
    }
  }

  /// Helper: converts LatLng list to Clipper2 Path64
  static Path64 latLngsToPath64(List<LatLng> points) {
    return points
        .map(
          (p) => Point64(
            (p.longitude * _coordScale).round(),
            (p.latitude * _coordScale).round(),
          ),
        )
        .toList();
  }

  /// Helper: converts Clipper2 Path64 to LatLng list
  static List<LatLng> path64ToLatLngs(Path64 path) {
    return path
        .map((pt) => LatLng(pt.y / _coordScale, pt.x / _coordScale))
        .toList();
  }

  /// Returns active runner profile
  RunnerProfile getProfile() {
    _initProfileIfNeeded();
    final box = _profileBox;
    return box?.get('current_user') ??
        RunnerProfile(
          id: _firebaseService.currentUserId,
          username: _firebaseService.currentUsername,
          totalDistanceKm: 0.0,
          xp: 0,
          level: 1,
          badges: ['Rookie Runner'],
          totalTerritoriesClaimed: 0,
          currentStreak: 1,
        );
  }

  /// Updates and saves the runner profile
  Future<void> saveProfile(RunnerProfile profile) async {
    if (profile.runnerCode.trim().isEmpty && profile.id.trim().isNotEmpty) {
      profile.runnerCode = RunnerProfile.generateFallbackCode(profile.id);
    }
    final box = _profileBox;
    if (box != null) {
      await box.put('current_user', profile);
    }
    unawaited(_firebaseService.syncProfileToCloud(profile));
  }

  /// Syncs the authenticated user's profile with the backend and ensures
  /// a permanent unique Runner ID (`runnerCode`) is stored locally.
  Future<RunnerProfile> syncIdentityWithBackend({
    String? displayName,
    ApiClient? apiClient,
  }) async {
    final profile = getProfile();
    final uid = _firebaseService.currentUserId;
    if (uid.isNotEmpty) {
      profile.id = uid;
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      profile.username = displayName.trim();
    }
    if (profile.runnerCode.trim().isEmpty) {
      profile.runnerCode = RunnerProfile.generateFallbackCode(profile.id);
    }
    await saveProfile(profile);

    if (apiClient == null && !Hive.isBoxOpen('profile')) {
      return profile;
    }

    final client = apiClient ?? ApiClient();
    try {
      final cleanName = profile.username.trim();
      final serverProfile =
          await (cleanName.length >= 2 && cleanName.length <= 24
                  ? client.updateMe(username: cleanName)
                  : client.getMe())
              .timeout(const Duration(seconds: 4));
      if (serverProfile.runnerCode.trim().isNotEmpty) {
        profile.runnerCode = serverProfile.runnerCode.trim().toUpperCase();
      }
      if (serverProfile.id.isNotEmpty) {
        profile.id = serverProfile.id;
      }
      if (profile.faction.isEmpty && serverProfile.faction.isNotEmpty) {
        profile.faction = serverProfile.faction;
      }
      if (apiClient != null || Hive.isBoxOpen('profile')) {
        await saveProfile(profile);
      }
    } catch (e) {
      AppLogger.debug(
        'Offline or skipped backend identity sync: $e',
        tag: 'TerritoryService',
      );
    }
    return profile;
  }

  /// Returns all currently captured territory IDs
  List<String> getCapturedTerritories() {
    final box = _territoryBox;
    if (box == null) return [];
    final now = DateTime.now();
    return box.values
        .where((t) => !t.isDespawned(now: now))
        .map((t) => t.id)
        .toList();
  }

  /// Returns all currently captured Territory model objects
  List<Territory> getCapturedTerritoryObjects() {
    final box = _territoryBox;
    if (box == null) return [];
    final now = DateTime.now();
    return box.values.where((t) => !t.isDespawned(now: now)).toList();
  }

  /// Captures an arbitrary enclosed GPS polygon as player territory.
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
    final Color activeColor = color ?? AppColors.accent;
    final newPath64 = latLngsToPath64(polygon);
    final box = _territoryBox;
    final DateTime now = DateTime.now();

    // 0. Sovereign Shield Check: subtract any intersecting rival land that is actively shielded
    final shieldedRivalPaths = <Path64>[];
    if (box != null) {
      for (final t in box.values) {
        if (t.ownerId != activeOwner &&
            !t.isDespawned(now: now) &&
            t.isShielded(now: now)) {
          for (final poly in t.polygons) {
            if (poly.length >= 3) {
              shieldedRivalPaths.add(latLngsToPath64(poly));
            }
          }
        }
      }
    }

    Paths64 effectiveNewPaths = [newPath64];
    if (shieldedRivalPaths.isNotEmpty) {
      effectiveNewPaths = Clipper.difference(
        subject: [newPath64],
        clip: shieldedRivalPaths,
        fillRule: FillRule.nonZero,
      );
    }

    // 1. Clipper Union: merge with the player's existing captured shapes
    final playerExistingTerritories = box != null
        ? box.values.where((t) => t.ownerId == activeOwner).toList()
        : <Territory>[];
    final Paths64 playerExistingPaths = [];
    for (final t in playerExistingTerritories) {
      for (final poly in t.polygons) {
        if (poly.length >= 3) {
          playerExistingPaths.add(latLngsToPath64(poly));
        }
      }
    }

    final Paths64 mergedPaths = effectiveNewPaths.isNotEmpty
        ? (playerExistingPaths.isNotEmpty
              ? Clipper.union(
                  subject: playerExistingPaths,
                  clip: effectiveNewPaths,
                  fillRule: FillRule.nonZero,
                )
              : effectiveNewPaths)
        : playerExistingPaths;

    final List<List<LatLng>> rawMultiPolys = mergedPaths
        .map(path64ToLatLngs)
        .toList();

    // Geometry hygiene (T8): drop sliver components < 2 m²
    final List<List<LatLng>> mergedMultiPolys = rawMultiPolys
        .where(
          (poly) =>
              PolygonEnclosureEngine.computeGeodesicShoelaceArea(poly) >= 2.0,
        )
        .toList();

    final double previousTotalAreaSqM = playerExistingTerritories.fold(
      0.0,
      (acc, t) => acc + t.areaSqMeters,
    );
    final double totalUnifiedAreaSqM = _netAreaOf(mergedMultiPolys);

    // Calculate rival area stolen before committing mutations
    final rivalTerritories = box != null
        ? box.values
              .where(
                (t) => t.ownerId != activeOwner && !t.isDespawned(now: now),
              )
              .toList()
        : <Territory>[];

    double precalculatedStolenSqM = 0.0;
    for (final rival in rivalTerritories) {
      if (rival.isShielded(now: now)) continue;
      final Paths64 rPaths = [];
      for (final poly in rival.polygons) {
        if (poly.length >= 3) rPaths.add(latLngsToPath64(poly));
      }
      if (rPaths.isNotEmpty && effectiveNewPaths.isNotEmpty) {
        final Paths64 overlap = Clipper.intersect(
          subject: rPaths,
          clip: effectiveNewPaths,
          fillRule: FillRule.nonZero,
        );
        if (overlap.isNotEmpty) {
          final double overlapArea = _netAreaOf(
            overlap.map(path64ToLatLngs).toList(),
          );
          precalculatedStolenSqM += overlapArea;
        }
      }
    }

    final double rawNetGain = totalUnifiedAreaSqM - previousTotalAreaSqM;
    final double netGainedSqM = rawNetGain > 0 ? rawNetGain : 0.0;
    final double claimableSqM = netGainedSqM + precalculatedStolenSqM;

    // Floor check (T6): if gained < 25 m², do not touch territories or rivals at all
    if (claimableSqM < minClaimAreaSqMeters) {
      lastCaptureXp = 0;
      lastCaptureNetAreaSqM = 0.0;
      lastCaptureStolenAreaSqM = 0.0;
      AppLogger.info(
        'Capture below 25 m² floor (${claimableSqM.toStringAsFixed(1)}m²) — territories untouched, 0 XP awarded',
        tag: 'TerritoryService',
      );
      return playerExistingTerritories.isNotEmpty
          ? playerExistingTerritories.first
          : Territory(
              id: 'poly_${activeOwner}_territory',
              ownerId: activeOwner,
              polygon: polygon,
              polygons: [polygon],
              areaSqMeters: 0.0,
              capturedAt: now,
              lastDefendedAt: now,
              cooldownUntil: now,
              strength: 100.0,
              color: activeColor,
            );
    }

    // Calculate area-weighted strength (T4)
    double calculatedStrength = Territory.defaultInitialStrength;
    if (playerExistingTerritories.isNotEmpty && totalUnifiedAreaSqM > 0) {
      final oldTerritory = playerExistingTerritories.first;
      final double oldEffectiveStrength = oldTerritory.computeCurrentStrength();

      final Paths64 defendedPaths =
          effectiveNewPaths.isNotEmpty && playerExistingPaths.isNotEmpty
          ? Clipper.intersect(
              subject: playerExistingPaths,
              clip: effectiveNewPaths,
              fillRule: FillRule.nonZero,
            )
          : <Path64>[];
      final double defendedOverlapArea = _netAreaOf(
        defendedPaths.map(path64ToLatLngs).toList(),
      );
      final double undisturbedOldArea =
          (previousTotalAreaSqM - defendedOverlapArea).clamp(
            0.0,
            double.infinity,
          );

      calculatedStrength =
          ((oldEffectiveStrength * undisturbedOldArea) +
              (100.0 * (defendedOverlapArea + netGainedSqM))) /
          totalUnifiedAreaSqM;
      calculatedStrength = calculatedStrength.clamp(0.0, 100.0);
    }

    // Remove previous fragmented territories for this player to store the unified MultiPolygon
    if (box != null) {
      for (final t in playerExistingTerritories) {
        await box.delete(t.id);
      }
    }

    final String territoryId = 'poly_${activeOwner}_territory';
    final unifiedTerritory = Territory(
      id: territoryId,
      ownerId: activeOwner,
      polygon: mergedMultiPolys.isNotEmpty ? mergedMultiPolys.first : polygon,
      polygons: mergedMultiPolys,
      areaSqMeters: totalUnifiedAreaSqM > 0
          ? totalUnifiedAreaSqM
          : areaSqMeters,
      capturedAt: now,
      lastDefendedAt: now,
      cooldownUntil: now.add(Territory.defaultShieldDuration),
      strength: calculatedStrength,
      color: activeColor,
      isPendingReview: isPendingReview,
    );

    if (box != null) {
      await box.put(territoryId, unifiedTerritory);
    }

    double stolenAreaSqM = 0.0;

    // 2. Clipper Difference: contest and clip overlapping rival territories
    for (final rival in rivalTerritories) {
      if (rival.isShielded(now: now)) {
        // Shielded rival territory cannot be invaded or damaged
        continue;
      }
      final Paths64 rivalPaths = [];
      for (final poly in rival.polygons) {
        if (poly.length >= 3) {
          rivalPaths.add(latLngsToPath64(poly));
        }
      }

      if (rivalPaths.isNotEmpty && effectiveNewPaths.isNotEmpty) {
        final Paths64 clippedRivalPaths = Clipper.difference(
          subject: rivalPaths,
          clip: effectiveNewPaths,
          fillRule: FillRule.nonZero,
        );

        if (clippedRivalPaths.isEmpty) {
          // Rival territory completely overtaken
          stolenAreaSqM += rival.areaSqMeters;
          if (box != null) {
            await box.delete(rival.id);
          }
          AppLogger.info(
            'Rival territory ${rival.id} claimed by $activeOwner',
            tag: 'TerritoryService',
          );
        } else {
          final List<List<LatLng>> rawClippedPolys = clippedRivalPaths
              .map(path64ToLatLngs)
              .toList();
          final List<List<LatLng>> clippedMultiPolys = rawClippedPolys
              .where(
                (poly) =>
                    PolygonEnclosureEngine.computeGeodesicShoelaceArea(poly) >=
                    2.0,
              )
              .toList();

          if (clippedMultiPolys.isEmpty) {
            stolenAreaSqM += rival.areaSqMeters;
            if (box != null) await box.delete(rival.id);
          } else {
            final double remainingArea = _netAreaOf(clippedMultiPolys);
            final double lostByRival = rival.areaSqMeters - remainingArea;

            final bool rivalIsWeak = rival.isWeak();
            if (lostByRival > 0) {
              stolenAreaSqM += rivalIsWeak ? (lostByRival * 1.5) : lostByRival;
            }

            if (rivalIsWeak && remainingArea < 50.0) {
              stolenAreaSqM += remainingArea;
              if (box != null) {
                await box.delete(rival.id);
              }
            } else {
              final double currentRivalStrength = rival
                  .computeCurrentStrength();
              final updatedRival = rival.copyWith(
                polygon: clippedMultiPolys.first,
                polygons: clippedMultiPolys,
                areaSqMeters: remainingArea,
                strength: (currentRivalStrength - 25.0).clamp(0.0, 100.0),
                lastDefendedAt: rival.lastDefendedAt,
              );
              if (box != null) {
                await box.put(rival.id, updatedRival);
              }
            }
          }
        }
      }
    }

    // 3. Award XP only for land that is genuinely NEW (net gain over your existing
    //    territory + area taken from rivals). Looping inside your own land earns nothing.
    final double claimableForXp = netGainedSqM + stolenAreaSqM;
    int gainedXp = 0;
    if (claimableForXp >= minClaimAreaSqMeters) {
      final profile = getProfile();
      gainedXp = profile.claimPolygonArea(claimableForXp);
      await saveProfile(profile);
    }
    lastCaptureXp = gainedXp;
    lastCaptureNetAreaSqM = netGainedSqM;
    lastCaptureStolenAreaSqM = stolenAreaSqM;

    AppLogger.info(
      'Polygon claimed! Player total territory area: ${totalUnifiedAreaSqM.toStringAsFixed(1)}m², XP: +$gainedXp',
      tag: 'TerritoryService',
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
    await _territoryBox?.put(territory.id, territory);
    _captureEventController.add(territory);
  }

  /// Spawns a mock rival territory (e.g. Crimson Faction) near the given coordinate for live demonstration
  Future<Territory> spawnMockRivalTerritory(LatLng center) async {
    const double deltaLat = 0.0018; // approx 200m
    const double deltaLng = 0.0022;

    final rivalPolygon = [
      LatLng(
        center.latitude + deltaLat * 0.2,
        center.longitude + deltaLng * 0.1,
      ),
      LatLng(
        center.latitude + deltaLat * 1.2,
        center.longitude + deltaLng * 0.1,
      ),
      LatLng(
        center.latitude + deltaLat * 1.2,
        center.longitude + deltaLng * 1.3,
      ),
      LatLng(
        center.latitude + deltaLat * 0.2,
        center.longitude + deltaLng * 1.3,
      ),
    ];

    final area = PolygonEnclosureEngine.computeGeodesicShoelaceArea(
      rivalPolygon,
    );
    const rivalOwner = 'rival_crimson_runner_99';
    const territoryId = 'poly_rival_crimson_zone';

    final rivalTerritory = Territory(
      id: territoryId,
      ownerId: rivalOwner,
      polygon: rivalPolygon,
      polygons: [rivalPolygon],
      areaSqMeters: area,
      capturedAt: DateTime.now().subtract(const Duration(minutes: 35)),
      lastDefendedAt: DateTime.now().subtract(const Duration(minutes: 35)),
      cooldownUntil: DateTime.now().subtract(const Duration(minutes: 5)),
      color: AppColors.rival, // Muted Crimson
      isPendingReview: false,
    );

    await _territoryBox?.put(territoryId, rivalTerritory);
    _captureEventController.add(rivalTerritory);
    return rivalTerritory;
  }

  /// Wipe all territories (e.g. for testing)
  Future<void> resetTerritories() async {
    await _territoryBox?.clear();
  }

  /// Refreshes and fortifies the runner's territory defense back to 100% strength
  Future<Territory?> defendTerritory(String ownerId) async {
    final box = _territoryBox;
    if (box == null) return null;
    final territoryId = 'poly_${ownerId}_territory';
    final existing = box.get(territoryId);
    if (existing != null) {
      final now = DateTime.now();
      final defended = existing.copyWith(
        strength: Territory.defaultInitialStrength,
        lastDefendedAt: now,
        cooldownUntil: now.add(Territory.defaultShieldDuration),
      );
      await box.put(territoryId, defended);
      _captureEventController.add(defended);
      unawaited(_firebaseService.syncTerritoryToCloud(defended));
      AppLogger.info(
        'Territory $territoryId fortified to 100% defense (2h shield active)!',
        tag: 'TerritoryService',
      );
      return defended;
    }
    return null;
  }

  /// Manually degrades territory strength for testing and Viva demonstrations
  Future<Territory?> simulateDecay(
    String ownerId, {
    double targetStrength = 20.0,
    int daysAgo = 5,
  }) async {
    final box = _territoryBox;
    if (box == null) return null;
    final territoryId = 'poly_${ownerId}_territory';
    final existing = box.get(territoryId);
    if (existing != null) {
      final decayed = existing.copyWith(
        strength: targetStrength,
        lastDefendedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      );
      await box.put(territoryId, decayed);
      _captureEventController.add(decayed);
      AppLogger.debug(
        'Territory $territoryId simulated decay: $targetStrength% (defended $daysAgo days ago)',
        tag: 'TerritoryService',
      );
      return decayed;
    }
    return null;
  }

  /// Listen to changes in territories to update UI in real-time
  Stream<BoxEvent> get territoryStream =>
      _territoryBox?.watch() ?? const Stream.empty();
}
