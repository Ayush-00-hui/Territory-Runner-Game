import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/ws_events.dart';

/// Mixin encapsulating rival simulation state and periodic orbit mechanics.
mixin MapRivalSimulationMixin on ChangeNotifier {
  final Map<String, RunnerPresenceEvent> _activeRivalRunners = {};
  final Map<String, List<LatLng>> _rivalBreadcrumbs = {};
  Timer? _rivalSimulationTimer;
  bool _isRivalSimulating = false;
  double _rivalSimAngle = 0.0;

  Map<String, RunnerPresenceEvent> get activeRivalRunners => _activeRivalRunners;
  Map<String, List<LatLng>> get rivalBreadcrumbs => _rivalBreadcrumbs;
  bool get isRivalSimulating => _isRivalSimulating;

  void toggleRivalSimulation(LatLng center) {
    if (_isRivalSimulating) {
      _rivalSimulationTimer?.cancel();
      _rivalSimulationTimer = null;
      _isRivalSimulating = false;
      _activeRivalRunners.remove('sim_rival_phantom');
      _rivalBreadcrumbs.remove('sim_rival_phantom');
      notifyListeners();
      return;
    }
    _isRivalSimulating = true;
    _rivalSimAngle = 0.0;
    const double radiusMeters = 180.0;
    const double earthRadius = 6378137.0;

    _rivalSimulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isRivalSimulating) {
        timer.cancel();
        return;
      }
      _rivalSimAngle = (_rivalSimAngle + 0.12) % (2 * math.pi);
      final dLat = (radiusMeters * math.cos(_rivalSimAngle)) / earthRadius * (180.0 / math.pi);
      final dLng = (radiusMeters * math.sin(_rivalSimAngle)) /
          (earthRadius * math.cos(center.latitude * (math.pi / 180.0))) *
          (180.0 / math.pi);
      final rivalPos = LatLng(center.latitude + dLat, center.longitude + dLng);
      final headingDeg = ((_rivalSimAngle + math.pi / 2) * (180.0 / math.pi)) % 360.0;

      final event = RunnerPresenceEvent(
        userId: 'sim_rival_phantom',
        username: 'Phantom_Vanguard',
        faction: 'Neon Syndicate',
        position: rivalPos,
        speed: 3.2,
        heading: headingDeg,
        updatedAt: DateTime.now(),
      );
      _activeRivalRunners['sim_rival_phantom'] = event;
      final trail = _rivalBreadcrumbs.putIfAbsent('sim_rival_phantom', () => []);
      trail.add(rivalPos);
      if (trail.length > 40) trail.removeAt(0);
      notifyListeners();
    });
    notifyListeners();
  }

  void disposeRivalSimulation() {
    _rivalSimulationTimer?.cancel();
  }
}
