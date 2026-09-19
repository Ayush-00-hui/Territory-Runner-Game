import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/territory.dart';
import 'h3_service.dart';
import 'territory_service.dart';

/// Represents an AI Rival Faction runner contesting territory
class RivalAgent {
  final String id;
  final String name;
  final String faction;
  final Color color;
  final int level;
  LatLng currentPosition;
  String currentHexId;

  RivalAgent({
    required this.id,
    required this.name,
    required this.faction,
    required this.color,
    required this.level,
    required this.currentPosition,
    required this.currentHexId,
  });
}

/// On-Device Autonomous AI Rival Simulation Engine (100% Free & Local).
///
/// Simulates rival runners traversing the H3 hex grid and contesting hexes
/// to create a dynamic, competitive turf war environment.
class RivalAgentService {
  static final RivalAgentService _instance = RivalAgentService._internal();
  factory RivalAgentService() => _instance;

  final H3Service _h3Service = H3Service();
  final TerritoryService _territoryService = TerritoryService();
  final List<RivalAgent> _rivals = [];
  Timer? _simulationTimer;

  final StreamController<List<RivalAgent>> _rivalsController =
      StreamController<List<RivalAgent>>.broadcast();
  Stream<List<RivalAgent>> get onRivalsUpdated => _rivalsController.stream;

  RivalAgentService._internal();

  List<RivalAgent> get rivals => List.unmodifiable(_rivals);

  /// Initializes rival agents around the player's initial position
  void initializeRivals(LatLng playerLocation) {
    if (_rivals.isNotEmpty) return;

    final String playerHex =
        _h3Service.getHexagonForLocation(playerLocation.latitude, playerLocation.longitude);
    final List<String> nearbyHexes = _h3Service.getHexagonsInRadius(playerHex, 3);

    final List<Map<String, dynamic>> rivalConfigs = [
      {
        'id': 'rival_phantom_1',
        'name': 'Phantom_Velo',
        'faction': 'Phantom Faction',
        'color': const Color(0xFFFF0055), // Neon Crimson
        'level': 4,
      },
      {
        'id': 'rival_syndicate_1',
        'name': 'Syndicate_Stride',
        'faction': 'Solar Syndicate',
        'color': const Color(0xFFFF9100), // Solar Amber
        'level': 6,
      },
      {
        'id': 'rival_vortex_1',
        'name': 'Vortex_Racer',
        'faction': 'Vortex Guild',
        'color': const Color(0xFF00FF88), // Spring Green
        'level': 3,
      },
    ];

    for (int i = 0; i < rivalConfigs.length; i++) {
      final config = rivalConfigs[i];
      final String hex = (i + 1 < nearbyHexes.length) ? nearbyHexes[i + 1] : playerHex;
      final LatLng pos = _h3Service.getHexagonCenter(hex);

      _rivals.add(RivalAgent(
        id: config['id'] as String,
        name: config['name'] as String,
        faction: config['faction'] as String,
        color: config['color'] as Color,
        level: config['level'] as int,
        currentPosition: pos,
        currentHexId: hex,
      ));
    }

    _rivalsController.add(_rivals);
  }

  /// Starts periodic simulation step (rivals advance along neighboring hexes)
  void startSimulation({Duration interval = const Duration(seconds: 45)}) {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(interval, (_) => _stepSimulation());
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  /// Steps autonomous rivals to conquer adjacent sectors
  void _stepSimulation() {
    if (_rivals.isEmpty) return;
    final math.Random rng = math.Random.secure();

    for (final rival in _rivals) {
      final List<String> neighbors = _h3Service.getNeighbors(rival.currentHexId);
      if (neighbors.isEmpty) continue;

      // Move to a random neighbor
      final String nextHex = neighbors[rng.nextInt(neighbors.length)];
      rival.currentHexId = nextHex;
      rival.currentPosition = _h3Service.getHexagonCenter(nextHex);

      // 40% probability to contest or claim territory for their faction
      if (rng.nextDouble() < 0.40) {
        final vertices = _h3Service.getHexagonVertices(nextHex);
        final rivalTerritory = Territory(
          id: nextHex,
          ownerId: rival.id,
          polygon: vertices,
          areaSqMeters: _h3Service.getHexagonAreaSqMeters(nextHex),
          capturedAt: DateTime.now(),
          color: rival.color,
        );
        _territoryService.saveTerritory(rivalTerritory);
      }
    }

    _rivalsController.add(_rivals);
  }

  void dispose() {
    stopSimulation();
    _rivalsController.close();
  }
}
