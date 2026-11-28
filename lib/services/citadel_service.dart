import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/logging/app_logger.dart';
import '../models/citadel.dart';
import 'arcade_audio_service.dart';

/// Service managing Landmark Citadels / Fortresses (King of the Hill POIs).
class CitadelService extends ChangeNotifier {
  static final CitadelService _instance = CitadelService._internal();
  factory CitadelService() => _instance;
  CitadelService._internal();

  final List<Citadel> _citadels = [];
  final Distance _distanceCalc = const Distance();

  List<Citadel> get citadels => List.unmodifiable(_citadels);

  /// Seeds realistic default landmark Citadels around user's initial location
  void seedCitadelsNear(LatLng center) {
    if (_citadels.isNotEmpty) return;

    final random = math.Random(42);
    final categories = CitadelCategory.values;
    final names = [
      'Apex Summit Citadel',
      'Emerald Park Stronghold',
      'Obsidian Bridge Gate',
      'Apex Arena Oval',
      'Horizon Hilltop Beacon',
    ];

    for (int i = 0; i < names.length; i++) {
      // Scatter within 800m - 2.5km radius
      final angle = (i * (360.0 / names.length)) + random.nextDouble() * 20.0;
      final dist = 600.0 + random.nextDouble() * 1400.0;
      final pos = _distanceCalc.offset(center, dist, angle);

      _citadels.add(
        Citadel(
          id: 'citadel_$i',
          name: names[i],
          category: categories[i % categories.length],
          position: pos,
          radiusMeters: 90.0,
          controllingFaction: i % 2 == 0 ? 'Apex' : 'Obsidian',
          rulerAthleteName: i == 0 ? 'Rival_Ghost_X' : 'Local_Legend',
          capturedAt: DateTime.now().subtract(Duration(days: i + 1)),
          defenseLevel: (i % 3) + 1,
        ),
      );
    }
    AppLogger.info(
      'Seeded ${_citadels.length} Landmark Citadels.',
      tag: 'CitadelService',
    );
    notifyListeners();
  }

  /// Evaluates whether an enclosed polygon captured a Citadel
  Citadel? checkPolygonEnclosure(
    List<LatLng> polygonVertices,
    String claimerName,
    String claimerFaction,
  ) {
    if (polygonVertices.length < 3) return null;

    for (final citadel in _citadels) {
      if (_isPointInPolygon(citadel.position, polygonVertices)) {
        // Captured!
        citadel.controllingFaction = claimerFaction;
        citadel.rulerAthleteName = claimerName;
        citadel.capturedAt = DateTime.now();
        citadel.defenseLevel = 1;
        ArcadeAudioService().playLoopVictoryChime();
        AppLogger.info(
          'CITADEL CAPTURED! ${citadel.name} is now ruled by $claimerName ($claimerFaction)!',
          tag: 'CitadelService',
        );
        notifyListeners();
        return citadel;
      }
    }
    return null;
  }

  /// Ray-casting algorithm to test if a point is inside a polygon
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersect =
          ((pi.longitude > point.longitude) !=
              (pj.longitude > point.longitude)) &&
          (point.latitude <
              (pj.latitude - pi.latitude) *
                      (point.longitude - pi.longitude) /
                      (pj.longitude - pi.longitude + 1e-12) +
                  pi.latitude);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
