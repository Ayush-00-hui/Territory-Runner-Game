import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/logging/app_logger.dart';
import '../../models/loot_crate.dart';
import '../../services/arcade_audio_service.dart';

/// Service managing procedural tactical loot crate drops, proximity detection,
/// and collection rewards during a run.
class LootCrateService extends ChangeNotifier {
  static final LootCrateService _instance = LootCrateService._internal();
  factory LootCrateService() => _instance;
  LootCrateService._internal();

  final List<LootCrate> _activeCrates = [];
  final List<LootCrate> _collectedHistory = [];
  final Distance _distanceCalc = const Distance();

  // Active buff status
  bool _isOverchargeActive = false;
  double _overchargeRemainingMeters = 0.0;
  bool hasTrailMagnet = false;
  int _collectedShards = 0;

  List<LootCrate> get activeCrates => List.unmodifiable(_activeCrates);
  List<LootCrate> get collectedHistory => List.unmodifiable(_collectedHistory);
  bool get isOverchargeActive => _isOverchargeActive;
  double get overchargeRemainingMeters => _overchargeRemainingMeters;
  int get collectedShards => _collectedShards;

  /// Callback stream when a crate is collected for HUD presentation
  final StreamController<LootCrate> _crateCollectedStream =
      StreamController<LootCrate>.broadcast();
  Stream<LootCrate> get onCrateCollected => _crateCollectedStream.stream;

  /// Resets state for a new run session
  void reset() {
    _activeCrates.clear();
    _collectedHistory.clear();
    _isOverchargeActive = false;
    _overchargeRemainingMeters = 0.0;
    hasTrailMagnet = false;
    _collectedShards = 0;
    notifyListeners();
  }

  /// Spawns a procedural tactical crate ahead of the runner along current heading
  void spawnProceduralCrate({
    required LatLng runnerPos,
    required double headingDeg,
    double distanceMeters = 220.0,
    LootCrateType? specificType,
  }) {
    // Offset slightly left or right of running corridor (15-30 degrees)
    final random = math.Random();
    final angleJitter = (random.nextBool() ? 1 : -1) * (15.0 + random.nextDouble() * 25.0);
    final spawnBearing = (headingDeg + angleJitter) % 360.0;

    // Project coordinate
    final cratePos = _distanceCalc.offset(runnerPos, distanceMeters, spawnBearing);

    final type = specificType ??
        LootCrateType.values[random.nextInt(LootCrateType.values.length)];

    final crate = LootCrate(
      id: 'crate_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(999)}',
      type: type,
      position: cratePos,
      spawnedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 25)),
      bonusMultiplier: type == LootCrateType.overchargeBeacon ? 2.0 : 1.5,
      bonusXp: type == LootCrateType.factionShard ? 75 : 30,
    );

    _activeCrates.add(crate);
    AppLogger.info(
      'Spawned ${crate.title} at (${cratePos.latitude.toStringAsFixed(4)}, ${cratePos.longitude.toStringAsFixed(4)}) '
      'dist: ${distanceMeters.round()}m',
      tag: 'LootCrateService',
    );
    notifyListeners();
  }

  /// Evaluates runner proximity against active crates on each GPS update
  void updateRunnerLocation(LatLng currentPos, double speedMps, double stepDistanceMeters) {
    if (_activeCrates.isEmpty && !_isOverchargeActive) return;

    // Update active overcharge buff distance
    if (_isOverchargeActive) {
      _overchargeRemainingMeters -= stepDistanceMeters;
      if (_overchargeRemainingMeters <= 0) {
        _isOverchargeActive = false;
        _overchargeRemainingMeters = 0.0;
        AppLogger.info('Overcharge Beacon buff expired.', tag: 'LootCrateService');
      }
      notifyListeners();
    }

    final pickupRadius = hasTrailMagnet ? 50.0 : 25.0;
    final toRemove = <LootCrate>[];

    for (final crate in _activeCrates) {
      if (crate.isExpired) {
        toRemove.add(crate);
        continue;
      }

      final dist = _distanceCalc.as(LengthUnit.Meter, currentPos, crate.position);
      if (dist <= pickupRadius) {
        // Collect Crate!
        crate.isCollected = true;
        toRemove.add(crate);
        _collectedHistory.add(crate);
        _applyCrateReward(crate);
        _crateCollectedStream.add(crate);
        ArcadeAudioService().playCrateCollectedSound();
        AppLogger.info('Collected ${crate.title} within ${dist.toStringAsFixed(1)}m!', tag: 'LootCrateService');
      }
    }

    if (toRemove.isNotEmpty) {
      _activeCrates.removeWhere((c) => toRemove.contains(c));
      notifyListeners();
    }
  }

  void _applyCrateReward(LootCrate crate) {
    switch (crate.type) {
      case LootCrateType.shieldBattery:
        // Shield battery effect handled via territory service
        break;
      case LootCrateType.overchargeBeacon:
        _isOverchargeActive = true;
        _overchargeRemainingMeters += 500.0; // 500m boost
        break;
      case LootCrateType.factionShard:
        _collectedShards += crate.bonusXp;
        break;
    }
  }
}
