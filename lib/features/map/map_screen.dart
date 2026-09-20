import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/location_service.dart';
import '../gameplay/h3_service.dart';
import '../gameplay/territory_service.dart';
import '../routing/route_service.dart';
import '../security/anomaly_service.dart';
import '../coach/pace_prediction_service.dart';
import '../coach/llm_coach_service.dart';
import '../coach/voice_coach_service.dart';
import '../gameplay/polygon_enclosure_engine.dart';
import '../physics/flight_physics_controller.dart';
import '../sensors/sensor_explore_screen.dart';
import '../../main.dart'; // For AppColors and animations
import '../../core/utils/constants.dart';

class MapScreenFeature extends StatefulWidget {
  const MapScreenFeature({super.key});

  @override
  State<MapScreenFeature> createState() => _MapScreenFeatureState();
}

class _MapScreenFeatureState extends State<MapScreenFeature> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final H3Service _h3Service = H3Service();
  final TerritoryService _territoryService = TerritoryService();
  final RouteService _routeService = RouteService();
  final AnomalyService _anomalyService = AnomalyService();
  final PacePredictionService _paceService = PacePredictionService();
  final LLMCoachService _coachService = LLMCoachService();
  final VoiceCoachService _voiceCoach = VoiceCoachService();
  final FlightPhysicsController _flightPhysics = FlightPhysicsController();
  final PolygonEnclosureEngine _polygonEngine = PolygonEnclosureEngine();
  
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BoxEvent>? _territorySub;
  
  LatLng? _currentLocation;
  String? _currentHexId;
  bool _isRunActive = false;
  int _lastAnnouncedKm = 0;
  int _selectedModeTab = 0;

  // AI Route Suggestion State
  SuggestedRoute? _activeSuggestedRoute;

  // Strava-grade Telemetry Engine & Auto-Pause State
  final List<Position> _recentPositions = [];
  final List<LatLng> _runCoordinates = [];
  final List<Position> _rollingPaceWindow = [];
  int _hexesClaimedThisRun = 0;
  double _runDistanceKm = 0.0;
  Timer? _runTimer;
  int _elapsedDurationSeconds = 0;
  int _movingDurationSeconds = 0;
  int _lowSpeedDurationSeconds = 0;
  bool _isAutoPaused = false;
  double _currentSpeedKmh = 0.0;
  double _satelliteAccuracyMeters = 3.5;
  bool _isCameraFollowLocked = true;

  @override
  void initState() {
    super.initState();
    
    // Start anti-gravity physics simulation
    _flightPhysics.startPhysicsLoop();
    _flightPhysics.addListener(_onFlightPhysicsChanged);

    // Listen for new captures
    _territorySub = _territoryService.territoryStream.listen((event) {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndInitLocation();
    });
  }

  void _onFlightPhysicsChanged() {
    if (mounted) {
      setState(() {});
    }
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
                'Territory Runner requires Geolocation & 3-Axis Kinematic Motion Sensors to calculate sub-orbital glide physics and enclose real-world sovereign polygons.',
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
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gps_fixed_rounded, color: Color(0xFF00E676), size: 16),
                        SizedBox(width: 8),
                        Text('High-Accuracy GPS (Sub-meter)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.sensors_rounded, color: Color(0xFF00F0FF), size: 16),
                        SizedBox(width: 8),
                        Text('6DOF Gyroscope & Accelerometer', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'If denied or restricted, the engine falls back gracefully to localized virtual simulation mode.',
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
              child: const Text('ENGAGE SENSORS & PROCEED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
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
          _updateHexagon(pos);
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
          _updateHexagon(pos);

          if (_isCameraFollowLocked && _currentLocation != null) {
            try {
              _mapController.move(_currentLocation!, _mapController.camera.zoom);
            } catch (_) {}
          }
        });
      }
    });
  }

  void _updateHexagon(Position pos) {
    if (_currentLocation != null) {
      final newHexId = _h3Service.getHexagonForLocation(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      // Track positions for anti-cheat & telemetry
      _recentPositions.add(pos);
      if (_recentPositions.length > 20) {
        _recentPositions.removeAt(0);
      }

      // Rolling window for instantaneous 15-second / 30-meter split pace calculation
      _rollingPaceWindow.add(pos);
      final now = pos.timestamp;
      _rollingPaceWindow.removeWhere((p) => now.difference(p.timestamp).inSeconds > 15);

      if (_isRunActive) {
        _runCoordinates.add(_currentLocation!);
        
        // 1. Arbitrary Polygon Enclosure Tracking (Automatic)
        final loopEvent = _polygonEngine.addPosition(_currentLocation!);
        if (loopEvent != null) {
          final multiplier = _flightPhysics.conquestMultiplier;
          _territoryService.capturePolygonTerritory(
            polygon: loopEvent.polygon,
            areaSqMeters: loopEvent.areaSqMeters,
            multiplier: multiplier,
          ).then((_) {
            if (mounted) {
              setState(() {
                _hexesClaimedThisRun++;
              });
              HapticFeedback.heavyImpact();
              _voiceCoach.announceHexConquered(_hexesClaimedThisRun);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surface,
                  duration: const Duration(seconds: 3),
                  content: Text(
                    '⚡ Arbitrary Loop Enclosed! +${(loopEvent.areaSqMeters / 20 * multiplier).round()} XP (${loopEvent.areaSqMeters.toStringAsFixed(0)} m²)',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
          });
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
      
      if (_currentHexId != newHexId) {
        _currentHexId = newHexId;
        
        // If run is active, attempt to capture this new hexagon with anti-cheat verification
        if (_isRunActive && _currentHexId != null) {
          final AnomalyResult anomaly = _anomalyService.scoreSegment(_recentPositions);
          _territoryService.captureTerritory(_currentHexId!, isPendingReview: anomaly.isAnomaly).then((captured) {
            if (captured && mounted) {
              setState(() {
                _hexesClaimedThisRun++;
              });
              _voiceCoach.announceHexConquered(_hexesClaimedThisRun);
            }
          });
        }
      }
    }
  }

  /// Calculates instantaneous split pace using rolling 15-second / 30-meter moving window
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

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Manual "SEAL CURRENT SHAPE" override action
  void _sealCurrentShape() {
    if (!_isRunActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start a run first to seal sovereign territory')),
      );
      return;
    }

    final loopEvent = _polygonEngine.sealCurrentPath();
    if (loopEvent != null) {
      final multiplier = _flightPhysics.conquestMultiplier;
      _territoryService.capturePolygonTerritory(
        polygon: loopEvent.polygon,
        areaSqMeters: loopEvent.areaSqMeters,
        multiplier: multiplier,
      ).then((_) {
        if (mounted) {
          setState(() {
            _hexesClaimedThisRun++;
          });
          HapticFeedback.heavyImpact();
          _voiceCoach.announceHexConquered(_hexesClaimedThisRun);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surface,
              duration: const Duration(seconds: 4),
              content: Text(
                '⚡ DOMAIN SEALED! +${(math.max(100, (loopEvent.areaSqMeters / 20.0).round()) * multiplier).round()} XP (${loopEvent.areaSqMeters.toStringAsFixed(0)} m²)',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 3 GPS path points to seal a domain shape')),
      );
    }
  }

  void _toggleRun() {
    if (!_isRunActive) {
      // START RUN
      _polygonEngine.clear();
      setState(() {
        _isRunActive = true;
        _hexesClaimedThisRun = 0;
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

      if (_currentHexId != null) {
        _territoryService.captureTerritory(_currentHexId!).then((captured) {
          if (captured && mounted) {
            setState(() {
              _hexesClaimedThisRun++;
            });
            _voiceCoach.announceHexConquered(_hexesClaimedThisRun);
          }
        });
      }
    } else {
      // STOP RUN & TRIGGER SUMMARY
      _runTimer?.cancel();
      final int finalSeconds = _movingDurationSeconds > 0 ? _movingDurationSeconds : _elapsedDurationSeconds;
      final double finalDistance = _runDistanceKm;
      final int finalHexes = _hexesClaimedThisRun;

      setState(() {
        _isRunActive = false;
        _isAutoPaused = false;
      });

      _voiceCoach.announceRunComplete(finalDistance, finalHexes);
      _territoryService.addRunDistance(finalDistance);
      _showRunCompleteSummary(finalDistance, finalSeconds, finalHexes);
    }
  }

  Future<void> _suggestAiRoute() async {
    if (_currentLocation == null) return;

    final profile = _territoryService.getProfile();
    final prediction = _paceService.predictTarget(profile);

    // Run Route Recommendation Engine
    final route = _routeService.suggestRoute(
      currentLocation: _currentLocation!,
      targetDistanceKm: prediction.predictedDistanceKm,
    );

    setState(() {
      _activeSuggestedRoute = route;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'AI Route synthesized: ${route.totalDistanceKm.toStringAsFixed(1)}km (~${route.estimatedNewTerritoryCount} new hexes)',
          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showRunCompleteSummary(double distance, int durationSeconds, int hexesClaimed) async {
    final profile = _territoryService.getProfile();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return FutureBuilder<CoachInsight>(
          future: _coachService.generateRunInsight(
            distanceKm: distance,
            durationSeconds: durationSeconds,
            hexesClaimed: hexesClaimed,
            profile: profile,
          ),
          builder: (context, snapshot) {
            final insight = snapshot.data;
            final double pace = (distance > 0) ? (durationSeconds / 60.0) / distance : 0.0;
            final int paceMin = pace.floor();
            final int paceSec = ((pace - paceMin) * 60).round();
            final String paceFormatted = "$paceMin'${paceSec.toString().padLeft(2, '0')}\"/km";

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CONQUEST COMPLETE 🏁',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryTile(title: 'DISTANCE', value: '${distance.toStringAsFixed(2)} km'),
                      _SummaryTile(title: 'TIME', value: '${durationSeconds ~/ 60}m ${durationSeconds % 60}s'),
                      _SummaryTile(title: 'AVG PACE', value: paceFormatted),
                      _SummaryTile(title: 'HEXES', value: '+$hexesClaimed'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'AI Run Coach analyzing telemetry...',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI COACH INSIGHT (${insight?.moodTag.name.toUpperCase() ?? 'COACH'})',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                insight?.summary ?? 'Great run session!',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.bgDeep,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "💡 Tip: ${insight?.tip ?? 'Keep up the momentum!'}",
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CLAIM REWARDS & CLOSE', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _flightPhysics.removeListener(_onFlightPhysicsChanged);
    _flightPhysics.stopPhysicsLoop();
    _positionSub?.cancel();
    _territorySub?.cancel();
    _runTimer?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }

  void _inspectSectorAt(LatLng point) {
    final hexId = _h3Service.getHexagonForLocation(point.latitude, point.longitude);
    final isCaptured = _territoryService.isTerritoryCaptured(hexId);
    HapticFeedback.selectionClick();
    _showSectorDetailsSheet(hexId, point, isCaptured);
  }

  void _showSectorDetailsSheet(String hexId, LatLng point, bool isCaptured) {
    final areaSqM = _h3Service.getHexagonAreaSqMeters(hexId);
    final multiplier = _flightPhysics.conquestMultiplier;
    final baseReward = 10;
    final totalReward = (baseReward * multiplier).round();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isNowCaptured = _territoryService.isTerritoryCaptured(hexId);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isNowCaptured ? AppColors.accent : const Color(0xFF00F0FF)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.hexagon_outlined,
                              color: isNowCaptured ? AppColors.accent : const Color(0xFF00F0FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HEX SECTOR TELEMETRY',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                '#$hexId',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isNowCaptured
                              ? AppColors.accent.withValues(alpha: 0.2)
                              : Colors.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isNowCaptured ? AppColors.accent : Colors.cyanAccent,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          isNowCaptured ? 'CONQUERED' : 'UNCLAIMED',
                          style: TextStyle(
                            color: isNowCaptured ? AppColors.accent : Colors.cyanAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sector Area', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            Text('${areaSqM.toStringAsFixed(0)} m²', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GPS Coordinates', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            Text(
                              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Conquest Bounty', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                if (multiplier > 1.0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF8A2BE2), width: 1),
                                    ),
                                    child: const Text('1.5x FLIGHT', style: TextStyle(color: Color(0xFF00F0FF), fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '+$totalReward XP',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isNowCaptured) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        final success = await _territoryService.captureTerritory(hexId, multiplier: multiplier);
                        if (!mounted) return;
                        if (success) {
                          setModalState(() {});
                          setState(() {});
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surface,
                              content: Text(
                                'Sector #$hexId Conquered! (+$totalReward XP)',
                                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('TACTICAL CLAIM SECTOR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface2,
                        foregroundColor: Colors.white70,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mapController.move(point, 17.5);
                      },
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.accent),
                      label: const Text('SECTOR SECURED BY RUNNER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _recenter() {
    if (_currentLocation != null) {
      try {
        _mapController.move(_currentLocation!, 17.0);
      } catch (_) {
        // MapController not yet mounted
      }
    }
  }

  List<Polygon> _buildPolygons() {
    final List<Polygon> polygons = [];
    final territories = _territoryService.getCapturedTerritoryObjects();
    final Set<String> renderedHexes = {};
    
    // Draw all permanently captured hexes & arbitrary polygons with glowing outline
    for (final territory in territories) {
      if (territory.polygon.length >= 3) {
        polygons.add(
          Polygon(
            points: territory.polygon,
            color: territory.color.withValues(alpha: 0.25),
            borderColor: territory.color,
            borderStrokeWidth: 2.5,
          ),
        );
        renderedHexes.add(territory.id);
      }
    }
    
    // Draw current outline if not already captured
    if (_currentHexId != null && !renderedHexes.contains(_currentHexId!)) {
      final vertices = _h3Service.getHexagonVertices(_currentHexId!);
      if (vertices.length == 6) {
        polygons.add(
          Polygon(
            points: vertices,
            color: AppColors.accent.withValues(alpha: 0.12),
            borderColor: AppColors.accent.withValues(alpha: 0.6),
            borderStrokeWidth: 2.0,
          ),
        );
      }
    }
    
    return polygons;
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    
    // User Location Waypoint Marker (Glowing Blue dot from reference)
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2979FF).withValues(alpha: 0.25),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2979FF),
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2979FF).withValues(alpha: 0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final profile = _territoryService.getProfile();
    final String athleteName = profile.username.isNotEmpty ? profile.username : 'Runner';
    final territoriesCount = _territoryService.getCapturedTerritories().length;
    final totalAreaSqKm = (territoriesCount * 0.015047).clamp(0.0, 999.0);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Interactive Fullscreen Map
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 17.0,
                    backgroundColor: AppColors.bgDeep,
                    onTap: (tapPosition, point) {
                      _inspectSectorAt(point);
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    // Clean Dark Theme Map Tiles (100% Free, No Watermarks, No API Key Required)
                    TileLayer(
                      urlTemplate: AppConstants.mapApiKey.isNotEmpty
                          ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}'
                          : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                      additionalOptions: {
                        'accessToken': AppConstants.mapApiKey,
                      },
                      userAgentPackageName: 'com.territoryrunner.app',
                    ),
                    
                    // Conquered Territories Polygon Overlay (Arbitrary Enclosures & Hexagons)
                    PolygonLayer(
                      polygons: _buildPolygons(),
                    ),

                    // Active Runner Breadcrumb Trail & AI Suggested Route
                    PolylineLayer(
                      polylines: [
                        if (_isRunActive && _runCoordinates.length >= 2)
                          Polyline(
                            points: _runCoordinates,
                            color: const Color(0xFF00E676),
                            strokeWidth: 4.0,
                          ),
                        if (_polygonEngine.currentPath.length >= 2)
                          Polyline(
                            points: _polygonEngine.currentPath,
                            color: const Color(0xFF00F0FF),
                            strokeWidth: 2.5,
                          ),
                        if (_activeSuggestedRoute != null)
                          Polyline(
                            points: _activeSuggestedRoute!.polyline,
                            color: const Color(0xFFFF9100),
                            strokeWidth: 4.0,
                          ),
                      ],
                    ),
                      
                    // Live Markers (Player & Rival Runners)
                    MarkerLayer(
                      markers: _buildMarkers(),
                    ),
                  ],
                ),

          // Particle Slipstream Visualizer for Anti-Gravity Propulsion
          if (_flightPhysics.particles.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SlipstreamPainter(particles: _flightPhysics.particles),
                ),
              ),
            ),

          // 2. Top Header Bar ("Good run, Alex 👋" + "Run to own." capsule)
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Good run,',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$athleteName 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        profile.faction.isNotEmpty ? profile.faction : 'Run to own.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sub-header Mode Pill Tabs (Run | Explore | Leaderboard | Challenges)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildModePill(0, 'Run'),
                      _buildModePill(1, 'Explore'),
                      _buildModePill(2, 'Leaderboard'),
                      _buildModePill(3, 'Challenges'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Anti-Gravity Flight Propulsion Telemetry HUD
          Positioned(
            top: pad.top + 115,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _flightPhysics.isAirborne ? const Color(0xFF00F0FF) : AppColors.border,
                  width: _flightPhysics.isAirborne ? 1.5 : 1.0,
                ),
                boxShadow: [
                  if (_flightPhysics.isAirborne)
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _flightPhysics.isAirborne ? Icons.rocket_launch_rounded : Icons.flight_takeoff_rounded,
                        color: _flightPhysics.isAirborne ? const Color(0xFF00F0FF) : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'ALT: ${_flightPhysics.altitude.toStringAsFixed(1)}m',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              const Text(' / 85m', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                            ],
                          ),
                          Text(
                            _flightPhysics.kinematicState == KinematicState.zeroGSubOrbitalGlide
                                ? 'ZERO-G GLIDE (-0.4G)'
                                : 'GROUND TRACTION (1.0G)',
                            style: TextStyle(
                              color: _flightPhysics.kinematicState == KinematicState.zeroGSubOrbitalGlide
                                  ? const Color(0xFF00F0FF)
                                  : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_flightPhysics.momentumBoostActive)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9100).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFF9100)),
                          ),
                          child: const Text(
                            '+40% BOOST',
                            style: TextStyle(color: Color(0xFFFF9100), fontWeight: FontWeight.w900, fontSize: 9),
                          ),
                        ),
                      if (_flightPhysics.isAirborne)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF8A2BE2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFF00F0FF), size: 14),
                              SizedBox(width: 3),
                              Text(
                                '1.5x XP',
                                style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.w900, fontSize: 10),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _flightPhysics.energy / 100.0,
                                  backgroundColor: Colors.white12,
                                  color: const Color(0xFF00F0FF),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_flightPhysics.energy.toStringAsFixed(0)}%',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating "You own X.X km² here" Pill Overlay on Map
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
                  const Text(
                    'You own',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    totalAreaSqKm > 0 ? '${totalAreaSqKm.toStringAsFixed(1)} km²' : '2.3 km²',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'here',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // 5. Floating Control Buttons Stack (Left & Right)
          Positioned(
            left: 20,
            bottom: pad.bottom + 230,
            child: Column(
              children: [
                // Anti-Gravity Thruster Hold-To-Glide Button
                GestureDetector(
                  onTapDown: (_) => _flightPhysics.setThruster(true, currentRunSpeedMps: _currentSpeedKmh / 3.6),
                  onTapUp: (_) => _flightPhysics.setThruster(false),
                  onTapCancel: () => _flightPhysics.setThruster(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _flightPhysics.isThrusterEngaged
                            ? [const Color(0xFF00F0FF), const Color(0xFF8A2BE2)]
                            : [AppColors.surface, AppColors.surface2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _flightPhysics.isThrusterEngaged ? const Color(0xFF00F0FF) : const Color(0xFF8A2BE2),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_flightPhysics.isThrusterEngaged ? const Color(0xFF00F0FF) : const Color(0xFF8A2BE2))
                              .withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.rocket_rounded,
                        color: _flightPhysics.isThrusterEngaged ? Colors.black : const Color(0xFF00F0FF),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Virtual Pacer / Simulation Selector
                _buildFloatingCircleButton(
                  icon: Icons.speed_rounded,
                  color: _locationService.pacerMode != VirtualPacerMode.none ? const Color(0xFFFF9100) : Colors.white70,
                  onTap: _showVirtualPacerSheet,
                ),
                const SizedBox(height: 10),
                // Camera Follow vs Free-Pan Toggle
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

          // 6. Strava-Grade Live Telemetry HUD Obsidian Glass Card
          Positioned(
            left: 16,
            right: 16,
            bottom: pad.bottom + 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101218).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isAutoPaused ? const Color(0xFFFF9100).withValues(alpha: 0.6) : AppColors.border,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Auto-Pause Luminous Banner
                  if (_isAutoPaused && _isRunActive) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9100).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF9100), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle_filled_rounded, color: Color(0xFFFF9100), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'AUTO-PAUSED • MOVING SPEED < 1.5 KM/H',
                            style: TextStyle(
                              color: Color(0xFFFF9100),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Core Strava Metric Display: Distance | Moving Time | Split Pace
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // Massive Distance
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DISTANCE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _isRunActive ? _runDistanceKm.toStringAsFixed(2) : '5.12',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'KM',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Moving Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'TIME',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              if (_isRunActive && !_isAutoPaused) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRunActive
                                ? _formatDuration(_movingDurationSeconds > 0 ? _movingDurationSeconds : _elapsedDurationSeconds)
                                : '28:17',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),

                      // Instantaneous Split Pace
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'AVG PACE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRunActive ? _computeCurrentSplitPace() : "5'30\"",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Secondary Telemetry Row: Speed | Calories | Satellite Precision | Domain Claims
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed_rounded, color: Color(0xFF00F0FF), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_currentSpeedKmh.toStringAsFixed(1)} km/h',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9100), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '+${(_runDistanceKm * 65.0).round()} kcal',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.satellite_alt_rounded, color: AppColors.accent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '±${_satelliteAccuracyMeters.toStringAsFixed(0)}m',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF8A2BE2), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$_hexesClaimedThisRun domains',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Controls Row: Manual Seal Domain Button | Center Giant Play/Pause | Finish Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Manual "SEAL SHAPE" Override Button
                      GestureDetector(
                        onTap: _sealCurrentShape,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF8A2BE2), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_rounded, color: Color(0xFF00F0FF), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'SEAL SHAPE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Center Giant Glowing Neon Green Play/Pause Action Button
                      GestureDetector(
                        onTap: _toggleRun,
                        child: Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _isRunActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 36,
                            ),
                          ),
                        ),
                      ),

                      // Right Slide to Finish / Complete Button
                      GestureDetector(
                        onTap: () {
                          if (_isRunActive) {
                            _toggleRun(); // Finish run
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tap the center play button to begin tracking')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isRunActive ? Colors.redAccent.withValues(alpha: 0.2) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _isRunActive ? Colors.redAccent : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isRunActive ? Icons.stop_rounded : Icons.lock_outline_rounded,
                                color: _isRunActive ? Colors.redAccent : Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRunActive ? 'FINISH' : 'LOCKED',
                                style: TextStyle(
                                  color: _isRunActive ? Colors.redAccent : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVirtualPacerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.speed_rounded, color: AppColors.accent, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'VIRTUAL PACER & GNSS SIMULATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a pacer velocity profile for rapid indoor debugging, desktop simulation, or real hardware GPS:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 18),
                  _buildPacerOption(
                    mode: VirtualPacerMode.none,
                    title: 'Real Hardware GNSS Stream',
                    subtitle: 'Best for navigation (High Accuracy GPS)',
                    icon: Icons.satellite_alt_rounded,
                    color: const Color(0xFF00E676),
                    setModalState: setModalState,
                  ),
                  _buildPacerOption(
                    mode: VirtualPacerMode.walking,
                    title: 'Virtual Walk — 5.0 km/h',
                    subtitle: '1.39 m/s with micro-oscillation heading drift',
                    icon: Icons.directions_walk_rounded,
                    color: const Color(0xFF00F0FF),
                    setModalState: setModalState,
                  ),
                  _buildPacerOption(
                    mode: VirtualPacerMode.running,
                    title: 'Virtual Run — 10.0 km/h',
                    subtitle: '2.78 m/s standard athletic pacing',
                    icon: Icons.directions_run_rounded,
                    color: const Color(0xFFFF9100),
                    setModalState: setModalState,
                  ),
                  _buildPacerOption(
                    mode: VirtualPacerMode.sprinting,
                    title: 'Virtual Sprint — 15.0 km/h',
                    subtitle: '4.17 m/s high-velocity sub-orbital charge',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF8A2BE2),
                    setModalState: setModalState,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPacerOption({
    required VirtualPacerMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required StateSetter setModalState,
  }) {
    final isSelected = _locationService.pacerMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _locationService.setVirtualPacer(mode);
        setModalState(() {});
        setState(() {});
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 2),
            content: Text('Pacer mode: $title ⚡', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? color : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModePill(int index, String title) {
    final isSelected = _selectedModeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedModeTab = index;
          });
          if (index == 1) {
            // Sensor Explore Screen (6DOF Oscilloscope & Telemetry)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SensorExploreScreen()),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
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

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
