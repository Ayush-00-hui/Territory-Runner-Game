import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../services/firebase_service.dart';
import '../physics/flight_physics_controller.dart';
import 'h3_service.dart';

class TerritoryService {
  static final TerritoryService _instance = TerritoryService._internal();
  factory TerritoryService() => _instance;

  late final Box<Territory> _territoryBox;
  late final Box<RunnerProfile> _profileBox;
  final H3Service _h3Service = H3Service();
  final FirebaseService _firebaseService = FirebaseService();

  final StreamController<Territory> _captureEventController = StreamController<Territory>.broadcast();
  Stream<Territory> get onTerritoryCaptured => _captureEventController.stream;

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

  /// Returns all currently captured hex IDs (for backwards compatibility)
  List<String> getCapturedTerritories() {
    return _territoryBox.values.map((t) => t.id).toList();
  }

  /// Returns all currently captured Territory model objects
  List<Territory> getCapturedTerritoryObjects() {
    return _territoryBox.values.toList();
  }

  /// Checks if a specific hex is already captured by the user
  bool isTerritoryCaptured(String hexId) {
    return _territoryBox.containsKey(hexId);
  }

  /// Capture a new territory hex
  /// Calculates real vertices, area in m², awards XP (with flight bonus), and syncs
  Future<bool> captureTerritory(
    String hexId, {
    String? ownerId,
    bool isPendingReview = false,
    double? multiplier,
  }) async {
    if (_territoryBox.containsKey(hexId)) {
      return false; // Already captured
    }

    final String activeOwner = ownerId ?? _firebaseService.currentUserId;
    final vertices = _h3Service.getHexagonVertices(hexId);
    final double area = _h3Service.getHexagonAreaSqMeters(hexId);

    final newTerritory = Territory(
      id: hexId,
      ownerId: activeOwner,
      polygon: vertices,
      areaSqMeters: area,
      capturedAt: DateTime.now(),
      isPendingReview: isPendingReview,
    );

    // Persist locally in Hive
    await _territoryBox.put(hexId, newTerritory);

    // Award XP and increment claimed hex count in RunnerProfile (applies flight multiplier)
    final profile = getProfile();
    final effectiveMultiplier = multiplier ?? FlightPhysicsController().conquestMultiplier;
    final bool leveledUp = profile.claimHex(multiplier: effectiveMultiplier);
    await saveProfile(profile);

    debugPrint('[TerritoryService] Hex $hexId captured with ${effectiveMultiplier}x bonus! Total claimed: ${profile.totalHexesClaimed}, XP: ${profile.xp}, Level: ${profile.level} (Leveled up: $leveledUp)');

    // Emit live capture event
    _captureEventController.add(newTerritory);

    // Sync to Cloud Firestore
    unawaited(_firebaseService.syncTerritoryToCloud(newTerritory));

    return true;
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
