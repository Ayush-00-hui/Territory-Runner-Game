import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/location_service.dart';
import '../gameplay/territory_service.dart';
import '../routing/route_service.dart';
import '../coach/pace_prediction_service.dart';
import '../coach/llm_coach_service.dart';
import '../coach/voice_coach_service.dart';
import '../gameplay/polygon_enclosure_engine.dart';
import '../../services/sync_queue.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../models/ws_events.dart';
import '../../main.dart'; // For showRunStartAnimation
import 'widgets/mode_tabs.dart';
import 'widgets/run_hud.dart';
import 'widgets/map_layers.dart';
import 'widgets/pacer_sheet.dart';
import 'widgets/summary_sheet.dart';
import 'widgets/leaderboard_sheet.dart';
import 'widgets/loop_celebration_overlay.dart';

class MapScreenFeature extends StatefulWidget {
  const MapScreenFeature({super.key});

  @override
  State<MapScreenFeature> createState() => _MapScreenFeatureState();
}

class _MapScreenFeatureState extends State<MapScreenFeature> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final TerritoryService _territoryService = TerritoryService();
  final RouteService _routeService = RouteService();
  final PacePredictionService _paceService = PacePredictionService();
  final LLMCoachService _coachService = LLMCoachService();
  final VoiceCoachService _voiceCoach = VoiceCoachService();
  final PolygonEnclosureEngine _polygonEngine = PolygonEnclosureEngine();
  final ApiClient _apiClient = ApiClient();
  final WebSocketService _wsService = WebSocketService();
  Timer? _rivalPollingTimer;

  // Real-time WebSocket presence and alert state
  final Map<String, RunnerPresenceEvent> _activeRivalRunners = {};
  StreamSubscription<RunnerPresenceEvent>? _wsPresenceSub;
  StreamSubscription<String>? _wsRunnerLeftSub;
  StreamSubscription<TerritoryAlertEvent>? _wsAlertSub;
  StreamSubscription<ConquestBroadcastEvent>? _wsBroadcastSub;
  
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BoxEvent>? _territorySub;
  
  LatLng? _currentLocation;
  bool _isRunActive = false;
  int _lastAnnouncedKm = 0;
  int _selectedModeTab = 0;

  // AI Route Suggestion State
  SuggestedRoute? _activeSuggestedRoute;

  // Strava-grade Telemetry Engine & Auto-Pause State
  final List<Position> _recentPositions = [];
  final List<LatLng> _runCoordinates = [];
  final List<Position> _rollingPaceWindow = [];
  int _territoriesClaimedThisRun = 0;
  double _runDistanceKm = 0.0;
  Timer? _runTimer;
  int _elapsedDurationSeconds = 0;
  int _movingDurationSeconds = 0;
  int _lowSpeedDurationSeconds = 0;
  bool _isAutoPaused = false;
  double _currentSpeedKmh = 0.0;
  double _satelliteAccuracyMeters = 3.5;
  bool _isCameraFollowLocked = true;
  double? _distanceToClosureMeters;
  double? _proximityToClosure;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Listen for new territory captures
    _territorySub = _territoryService.territoryStream.listen((event) {
      if (mounted) {
        setState(() {});
      }
    });

    // Poll rival territories every 20 seconds while map screen is open
    _rivalPollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _fetchVisibleRivals();
    });

    // Real-time WebSocket: Connect and listen for live rival runners and territory alerts
    _wsService.connect();
    _wsPresenceSub = _wsService.presenceStream.listen((presence) {
      if (mounted) {
        setState(() {
          _activeRivalRunners[presence.userId] = presence;
        });
      }
    });

    _wsRunnerLeftSub = _wsService.runnerLeftStream.listen((userId) {
      if (mounted) {
        setState(() {
          _activeRivalRunners.remove(userId);
        });
      }
    });

    _wsAlertSub = _wsService.alertStream.listen((alert) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E1015),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3366), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TERRITORY INTRUSION DETECTED',
                      style: TextStyle(
                        color: Color(0xFFFF3366),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      _fetchVisibleRivals();
    });

    _wsBroadcastSub = _wsService.broadcastStream.listen((_) {
      if (mounted) {
        _fetchVisibleRivals();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndInitLocation();
    });
  }

  Future<void> _checkPermissionsAndInitLocation() async {
    final isFirstTime = await _locationService.isFirstTimePermissionRequest();
    if (isFirstTime) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.accent, width: 1.2)),
          title: const Row(
            children: [
              Icon(Icons.satellite_alt_rounded, color: AppColors.accent, size: 24),
              SizedBox(width: 10),
              Text(
                'TACTICAL HUD AUTHORIZATION',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.1),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Territory Runner requires High-Accuracy Geolocation to track running loops and enclose real-world sovereign territory polygons.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: Color(0xFF00E676), size: 16),
                    SizedBox(width: 8),
                    Text('High-Accuracy GPS (Sub-meter)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'If denied or restricted on desktop, the engine falls back gracefully to interactive simulation mode with W/A/S/D keyboard controls.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('ENGAGE TRACKING & PROCEED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ],
        ),
      );
      await _locationService.markPermissionRequested();
    }
    _initLocation();
  }

  void _initLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _satelliteAccuracyMeters = pos.accuracy;
          _updatePosition(pos);
        });
      }
    }

    _locationService.startTracking();
    _positionSub = _locationService.locationStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _satelliteAccuracyMeters = pos.accuracy;
          _currentSpeedKmh = pos.speed * 3.6;
          _updatePosition(pos);

          if (_isCameraFollowLocked && _currentLocation != null) {
            try {
              _mapController.move(_currentLocation!, _mapController.camera.zoom);
            } catch (_) {}
          }
        });

        // Broadcast live kinematic presence to peers via WebSocket
        _wsService.sendPresenceUpdate(
          latitude: pos.latitude,
          longitude: pos.longitude,
          speed: pos.speed,
          heading: pos.heading,
        );
      }
    });
  }

  void _updatePosition(Position pos) {
    if (_currentLocation != null) {
      // Track positions for anti-cheat & telemetry
      _recentPositions.add(pos);
      if (_recentPositions.length > 20) {
        _recentPositions.removeAt(0);
      }

      // Rolling window for instantaneous split pace calculation
      _rollingPaceWindow.add(pos);
      final now = pos.timestamp;
      _rollingPaceWindow.removeWhere((p) => now.difference(p.timestamp).inSeconds > 15);

      if (_isRunActive) {
        _runCoordinates.add(_currentLocation!);
        
        // Loop Proximity Meter calculation
        if (_polygonEngine.currentPath.length >= 3) {
          final start = _polygonEngine.currentPath.first;
          final dist = Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            start.latitude,
            start.longitude,
          );
          _distanceToClosureMeters = dist;
          _proximityToClosure = (1.0 - ((dist - 35.0) / (120.0 - 35.0))).clamp(0.0, 1.0);
        } else {
          _distanceToClosureMeters = null;
          _proximityToClosure = null;
        }

        // 1. Arbitrary Polygon Enclosure Tracking (Automatic)
        final loopEvent = _polygonEngine.addPosition(_currentLocation!);
        if (loopEvent != null) {
          _distanceToClosureMeters = null;
          _proximityToClosure = null;
          _territoryService.capturePolygonTerritory(
            polygon: loopEvent.polygon,
            areaSqMeters: loopEvent.areaSqMeters,
          ).then((_) {
            if (mounted) {
              _showCaptureOutcome();
            }
          });
        } else if (_polygonEngine.lastInvalidReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E212B),
              duration: const Duration(seconds: 3),
              content: Text(
                '⚠️ ${_polygonEngine.lastInvalidReason}',
                style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        // High-Precision Geodesic Metric Accumulation on WGS84
        if (_runCoordinates.length >= 2) {
          final p1 = _runCoordinates[_runCoordinates.length - 2];
          final p2 = _runCoordinates.last;
          final double segmentMeters = Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
          
          _runDistanceKm += (segmentMeters / 1000.0);
          
          final int currentKmFloor = _runDistanceKm.floor();
          if (currentKmFloor > _lastAnnouncedKm && currentKmFloor >= 1) {
            _lastAnnouncedKm = currentKmFloor;
            HapticFeedback.heavyImpact();
            _voiceCoach.announceDistanceMilestone(currentKmFloor, _computeCurrentSplitPace());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.surface,
                duration: const Duration(seconds: 4),
                content: Text(
                  '🏁 MILESTONE: $currentKmFloor.0 KM COMPLETED • Split Pace: ${_computeCurrentSplitPace()}',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        }
      }
    }
  }

  String _computeCurrentSplitPace() {
    if (_rollingPaceWindow.length >= 2) {
      final pFirst = _rollingPaceWindow.first;
      final pLast = _rollingPaceWindow.last;
      final double distMeters = Geolocator.distanceBetween(
        pFirst.latitude,
        pFirst.longitude,
        pLast.latitude,
        pLast.longitude,
      );
      final double deltaSec = (pLast.timestamp.difference(pFirst.timestamp).inMilliseconds / 1000.0).abs();
      if (distMeters >= 5.0 && deltaSec > 1.0) {
        final double speedMps = distMeters / deltaSec;
        if (speedMps > 0.3) {
          final double paceSecondsPerKm = 1000.0 / speedMps;
          final int paceMin = (paceSecondsPerKm / 60.0).floor().clamp(2, 25);
          final int paceSec = (paceSecondsPerKm % 60).round().clamp(0, 59);
          return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"";
        }
      }
    }

    if (_runDistanceKm <= 0 || _movingDurationSeconds <= 0) return "5'30\"";
    final double pace = (_movingDurationSeconds / 60.0) / _runDistanceKm;
    final int paceMin = pace.floor().clamp(2, 25);
    final int paceSec = ((pace - paceMin) * 60).round().clamp(0, 59);
    return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"";
  }

  /// Shows the real result of the last capture: new land + land taken from rivals.
  /// A loop that only covers land you already own earns nothing (no XP farming).
  void _showCaptureOutcome() {
    final double netGained = _territoryService.lastCaptureNetAreaSqM;
    final double stolen = _territoryService.lastCaptureStolenAreaSqM;
    final int xp = _territoryService.lastCaptureXp;
    final double claimed = netGained + stolen;

    if (claimed < TerritoryService.minClaimAreaSqMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E212B),
          duration: Duration(seconds: 3),
          content: Text(
            'Already your territory — loop around new ground to claim more land.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() {
      _territoriesClaimedThisRun++;
    });
    AppMotion.heavyBurst();
    LoopCelebrationOverlay.show(
      context,
      areaSqMeters: claimed,
      xpAwarded: xp,
    );
    _voiceCoach.announceHexConquered(_territoriesClaimedThisRun);
  }

  void _sealCurrentShape() {
    if (!_isRunActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start a run first to seal sovereign territory')),
      );
      return;
    }

    final loopEvent = _polygonEngine.sealCurrentPath();
    if (loopEvent != null) {
      _territoryService.capturePolygonTerritory(
        polygon: loopEvent.polygon,
        areaSqMeters: loopEvent.areaSqMeters,
      ).then((_) {
        if (mounted) {
          setState(() {
            _distanceToClosureMeters = null;
            _proximityToClosure = null;
          });
          _showCaptureOutcome();
        }
      });
    } else {
      final errorMsg = _polygonEngine.lastInvalidReason ?? 'Need at least 3 GPS path points to seal a domain shape';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E212B),
          content: Text('⚠️ $errorMsg', style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  void _toggleRun() {
    if (!_isRunActive) {
      // START RUN
      _polygonEngine.clear();
      setState(() {
        _isRunActive = true;
        _territoriesClaimedThisRun = 0;
        _runDistanceKm = 0.0;
        _elapsedDurationSeconds = 0;
        _movingDurationSeconds = 0;
        _lowSpeedDurationSeconds = 0;
        _isAutoPaused = false;
        _lastAnnouncedKm = 0;
        _runCoordinates.clear();
        _rollingPaceWindow.clear();
      });

      _runTimer?.cancel();
      _runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRunActive) {
          setState(() {
            _elapsedDurationSeconds++;

            // Strava Auto-Pause Check: speed < 1.5 km/h for > 3 consecutive seconds
            if (_currentSpeedKmh < 1.5) {
              _lowSpeedDurationSeconds++;
              if (_lowSpeedDurationSeconds >= 3) {
                _isAutoPaused = true;
              }
            } else {
              _lowSpeedDurationSeconds = 0;
              _isAutoPaused = false;
              _movingDurationSeconds++;
            }
          });
        }
      });

      showRunStartAnimation(context);
      _voiceCoach.announceRunStart();
    } else {
      // STOP RUN & TRIGGER SUMMARY
      _runTimer?.cancel();
      final int finalSeconds = _movingDurationSeconds > 0 ? _movingDurationSeconds : _elapsedDurationSeconds;
      final double finalDistance = _runDistanceKm;
      final int finalTerritories = _territoriesClaimedThisRun;

      setState(() {
        _isRunActive = false;
        _isAutoPaused = false;
      });

      _voiceCoach.announceRunComplete(finalDistance, finalTerritories);
      _territoryService.addRunDistance(finalDistance);

      if (_runCoordinates.length >= 3) {
        SyncQueueService().enqueueRun(
          points: List<LatLng>.from(_runCoordinates),
          durationSeconds: finalSeconds,
          distanceMeters: finalDistance * 1000.0,
          clientPreviewArea: 0.0,
          clientPreviewXp: finalTerritories * 100,
        );
      }

      SummarySheet.show(
        context: context,
        distanceKm: finalDistance,
        durationSeconds: finalSeconds,
        territoriesClaimed: finalTerritories,
        profile: _territoryService.getProfile(),
        coachService: _coachService,
        routePoints: List<LatLng>.from(_runCoordinates),
      );
    }
  }

  Future<void> _suggestAiRoute() async {
    if (_currentLocation == null) return;

    final profile = _territoryService.getProfile();
    final prediction = _paceService.predictTarget(profile);

    final route = await _routeService.suggestRouteAsync(
      currentLocation: _currentLocation!,
      targetDistanceKm: prediction.predictedDistanceKm,
    );

    setState(() {
      _activeSuggestedRoute = route;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'AI Route synthesized: ${route.totalDistanceKm.toStringAsFixed(1)}km (~${route.estimatedNewTerritoryAreaSqM.toStringAsFixed(0)} m² new area)',
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _territorySub?.cancel();
    _runTimer?.cancel();
    _rivalPollingTimer?.cancel();
    _wsPresenceSub?.cancel();
    _wsRunnerLeftSub?.cancel();
    _wsAlertSub?.cancel();
    _wsBroadcastSub?.cancel();
    _wsService.disconnect();
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _fetchVisibleRivals() async {
    if (!mounted || _currentLocation == null) return;
    try {
      final bounds = _mapController.camera.visibleBounds;
      final serverTerritories = await _apiClient.getTerritoriesInBBox(
        minLng: bounds.west,
        minLat: bounds.south,
        maxLng: bounds.east,
        maxLat: bounds.north,
      );

      final myId = _territoryService.getProfile().id;
      for (final t in serverTerritories) {
        if (t.ownerId != myId) {
          await _territoryService.saveTerritory(t);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[MapScreen] Error polling rival territories: $e');
    }
  }

  void _inspectSectorAt(LatLng point) {
    HapticFeedback.selectionClick();
    final territories = _territoryService.getCapturedTerritoryObjects();
    final double area = territories.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
        content: Text(
          'Location: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)} (Total owned: ${area.toStringAsFixed(0)} m²)',
          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _recenter() {
    if (_currentLocation != null) {
      try {
        _mapController.move(_currentLocation!, 17.0);
      } catch (_) {}
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _locationService.moveSimulatedRunner(forwardMeters: 6.0);
      } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _locationService.moveSimulatedRunner(forwardMeters: -4.0);
      } else if (event.logicalKey == LogicalKeyboardKey.keyA || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _locationService.moveSimulatedRunner(turnDegrees: -15.0);
      } else if (event.logicalKey == LogicalKeyboardKey.keyD || event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _locationService.moveSimulatedRunner(turnDegrees: 15.0);
      }
    }
  }

  void _runAutomatedLoopDemo() {
    if (!_isRunActive) {
      _toggleRun();
    }

    final center = _currentLocation ?? const LatLng(37.7749, -122.4194);
    const double radiusLat = 0.0012;
    const double radiusLng = 0.0016;
    const int steps = 12;

    final waypoints = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final angle = (2 * math.pi * i) / steps;
      final lat = center.latitude + radiusLat * math.sin(angle);
      final lng = center.longitude + radiusLng * (1 - math.cos(angle));
      waypoints.add(LatLng(lat, lng));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        duration: Duration(seconds: 2),
        content: Text('⚡ Streaming 400m automated GPS loop scenario...', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
      ),
    );

    int currentStep = 0;
    Timer.periodic(const Duration(milliseconds: 320), (timer) {
      if (currentStep >= waypoints.length || !mounted) {
        timer.cancel();
        return;
      }

      final pt = waypoints[currentStep];
      final pos = Position(
        latitude: pt.latitude,
        longitude: pt.longitude,
        timestamp: DateTime.now(),
        accuracy: 2.5,
        altitude: 25.0,
        altitudeAccuracy: 1.0,
        heading: (360.0 * currentStep / steps) % 360.0,
        headingAccuracy: 1.0,
        speed: 3.2,
        speedAccuracy: 0.2,
      );

      setState(() {
        _currentLocation = pt;
        _currentSpeedKmh = pos.speed * 3.6;
        _updatePosition(pos);
      });

      try {
        _mapController.move(pt, _mapController.camera.zoom);
      } catch (_) {}

      currentStep++;
    });
  }

  void _runRivalConflictDemo() async {
    final center = _currentLocation ?? const LatLng(37.7749, -122.4194);
    
    await _territoryService.spawnMockRivalTerritory(center);
    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        duration: Duration(seconds: 2),
        content: Text('⚔️ Rival Crimson Sector #99 spawned! Executing slice conquest loop...', style: TextStyle(color: Color(0xFFFF3366), fontWeight: FontWeight.bold)),
      ),
    );

    if (!_isRunActive) {
      _toggleRun();
    }

    const double delta = 0.0018;
    final sliceWaypoints = [
      LatLng(center.latitude, center.longitude),
      LatLng(center.latitude + delta * 0.5, center.longitude + delta * 0.1),
      LatLng(center.latitude + delta * 1.5, center.longitude + delta * 0.5),
      LatLng(center.latitude + delta * 1.5, center.longitude + delta * 1.4),
      LatLng(center.latitude + delta * 0.1, center.longitude + delta * 1.4),
      LatLng(center.latitude, center.longitude),
    ];

    int step = 0;
    Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (step >= sliceWaypoints.length || !mounted) {
        timer.cancel();
        return;
      }

      final pt = sliceWaypoints[step];
      final pos = Position(
        latitude: pt.latitude,
        longitude: pt.longitude,
        timestamp: DateTime.now(),
        accuracy: 2.0,
        altitude: 20.0,
        altitudeAccuracy: 1.0,
        heading: 90.0,
        headingAccuracy: 1.0,
        speed: 3.5,
        speedAccuracy: 0.1,
      );

      setState(() {
        _currentLocation = pt;
        _currentSpeedKmh = pos.speed * 3.6;
        _updatePosition(pos);
      });

      step++;
    });
  }

  void _simulateSpeedAnomaly() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E212B),
        duration: Duration(seconds: 4),
        content: Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFFFF5252), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🚨 ANTI-CHEAT TRIGGERED: Telemetry speed 48.5 km/h exceeds human capability threshold (25 km/h)!',
                style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final profile = _territoryService.getProfile();
    final String athleteName = profile.username.isNotEmpty ? profile.username : 'Runner';
    final territories = _territoryService.getCapturedTerritoryObjects();
    final double totalAreaSqMeters = territories.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    final double totalAreaSqKm = totalAreaSqMeters / 1000000.0;

    return KeyboardListener(
      focusNode: _keyboardFocusNode..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Interactive Fullscreen Map wrapped in RepaintBoundary
            _currentLocation == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : RepaintBoundary(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLocation!,
                        initialZoom: 17.0,
                        backgroundColor: AppColors.bgDeep,
                        onTap: (tapPosition, point) => _inspectSectorAt(point),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        MapLayers.buildTileLayer(),
                        MapLayers.buildPolygonLayer(territories),
                        MapLayers.buildPolylineLayer(
                          isRunActive: _isRunActive,
                          runCoordinates: _runCoordinates,
                          currentEnclosurePath: _polygonEngine.currentPath,
                          suggestedRouteCoordinates: _activeSuggestedRoute?.polyline,
                        ),
                        MapLayers.buildMarkerLayer(
                          currentLocation: _currentLocation,
                          activeRivalRunners: _activeRivalRunners,
                        ),
                      ],
                    ),
                  ),

            // 2. Top Header Bar
            Positioned(
              top: pad.top + 10,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.surface2,
                            child: Text(
                              athleteName.isNotEmpty ? athleteName[0].toUpperCase() : 'A',
                              style: AppText.headingSmall,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Good run,', style: AppText.bodySmall),
                              Text('$athleteName 👋', style: AppText.headingSmall),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SyncChip(),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              profile.faction.isNotEmpty ? profile.faction : 'Run to own.',
                              style: AppText.bodyBold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sub-header Mode Pill Tabs
                  ModeTabs(
                    selectedIndex: _selectedModeTab,
                    onTabSelected: (index) {
                      setState(() => _selectedModeTab = index);
                      if (index == 2) {
                        LeaderboardSheet.show(
                          context: context,
                          apiClient: _apiClient,
                          currentUserId: _territoryService.getProfile().id,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // 3. Floating Overlays: Pacer Pill (left) & Territory Claimed Pill (right)
            Positioned(
              left: 20,
              bottom: pad.bottom + 175,
              child: GestureDetector(
                onTap: () {
                  AppMotion.lightTick();
                  VirtualPacerSheet.show(
                    context: context,
                    locationService: _locationService,
                    onSimulateLoop: _runAutomatedLoopDemo,
                    onSimulateRivalCut: _runRivalConflictDemo,
                    onSimulateAnomaly: _simulateSpeedAnomaly,
                    onSimulateCoachDebrief: () {
                      SummarySheet.show(
                        context: context,
                        distanceKm: 3.52,
                        durationSeconds: 1140,
                        territoriesClaimed: 3,
                        profile: _territoryService.getProfile(),
                        coachService: _coachService,
                      );
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: AppSpacing.br16,
                    border: Border.all(
                      color: _locationService.pacerMode != VirtualPacerMode.none
                          ? AppColors.info
                          : AppColors.border,
                    ),
                    boxShadow: _locationService.pacerMode != VirtualPacerMode.none
                        ? AppSpacing.neonGlow(AppColors.info, blur: 8)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_run_rounded,
                        size: 16,
                        color: _locationService.pacerMode != VirtualPacerMode.none
                            ? AppColors.info
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _locationService.pacerMode != VirtualPacerMode.none
                            ? 'PACER ${_locationService.pacerMode.name.replaceAll('sub', '')}:00'
                            : 'PACER OFF',
                        style: AppText.label.copyWith(
                          color: _locationService.pacerMode != VirtualPacerMode.none
                              ? AppColors.info
                              : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              right: 20,
              bottom: pad.bottom + 175,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('You own', style: AppText.label),
                    Text(
                      totalAreaSqKm > 0 ? '${totalAreaSqKm.toStringAsFixed(2)} km²' : '0.00 km²',
                      style: AppText.statSmall.copyWith(color: AppColors.accent),
                    ),
                    const Text('here', style: AppText.label),
                  ],
                ),
              ),
            ),

            // 4. Floating Control Buttons Stack
            Positioned(
              left: 20,
              bottom: pad.bottom + 230,
              child: Column(
                children: [
                  _buildFloatingCircleButton(
                    icon: Icons.speed_rounded,
                    color: _locationService.pacerMode != VirtualPacerMode.none ? AppColors.secondary : Colors.white70,
                    onTap: () {
                      VirtualPacerSheet.show(
                        context: context,
                        locationService: _locationService,
                        onSimulateLoop: _runAutomatedLoopDemo,
                        onSimulateRivalCut: _runRivalConflictDemo,
                        onSimulateAnomaly: _simulateSpeedAnomaly,
                        onSimulateCoachDebrief: () {
                          SummarySheet.show(
                            context: context,
                            distanceKm: 3.52,
                            durationSeconds: 1140,
                            territoriesClaimed: 3,
                            profile: _territoryService.getProfile(),
                            coachService: _coachService,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingCircleButton(
                    icon: _isCameraFollowLocked ? Icons.gps_fixed_rounded : Icons.pan_tool_rounded,
                    color: _isCameraFollowLocked ? AppColors.accent : Colors.white70,
                    onTap: () {
                      setState(() {
                        _isCameraFollowLocked = !_isCameraFollowLocked;
                      });
                      HapticFeedback.selectionClick();
                      if (_isCameraFollowLocked) _recenter();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingCircleButton(
                    icon: Icons.layers_rounded,
                    onTap: _suggestAiRoute,
                  ),
                  const SizedBox(height: 10),
                  _buildFloatingCircleButton(
                    icon: Icons.my_location_rounded,
                    onTap: _recenter,
                  ),
                ],
              ),
            ),

            // 5. Strava-Grade Live Telemetry HUD Obsidian Glass Card
            Positioned(
              left: 16,
              right: 16,
              bottom: pad.bottom + 12,
              child: RunHud(
                isRunActive: _isRunActive,
                isAutoPaused: _isAutoPaused,
                distanceKm: _runDistanceKm,
                elapsedSeconds: _elapsedDurationSeconds,
                movingSeconds: _movingDurationSeconds,
                splitPace: _computeCurrentSplitPace(),
                currentSpeedKmh: _currentSpeedKmh,
                satelliteAccuracyMeters: _satelliteAccuracyMeters,
                territoriesClaimed: _territoriesClaimedThisRun,
                distanceToClosureMeters: _distanceToClosureMeters,
                proximityToClosure: _proximityToClosure,
                targetPace: _locationService.pacerMode != VirtualPacerMode.none
                    ? '${_locationService.pacerMode.name.replaceAll('sub', '')}:00'
                    : null,
                onToggleRun: _toggleRun,
                onSealShape: _sealCurrentShape,
                onFinishRun: () {
                  if (_isRunActive) {
                    _toggleRun();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tap the center play button to begin tracking')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
