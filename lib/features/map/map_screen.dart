import 'dart:async';
import 'package:flutter/material.dart';
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
import '../gameplay/rival_agent_service.dart';
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
  final RivalAgentService _rivalService = RivalAgentService();
  
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BoxEvent>? _territorySub;
  StreamSubscription<List<RivalAgent>>? _rivalSub;
  
  LatLng? _currentLocation;
  String? _currentHexId;
  bool _isRunActive = false;
  int _lastAnnouncedKm = 0;

  // AI Route Suggestion State
  SuggestedRoute? _activeSuggestedRoute;
  bool _isGeneratingRoute = false;

  // Run telemetry & Anti-cheat tracking
  final List<Position> _recentPositions = [];
  final List<LatLng> _runCoordinates = [];
  int _hexesClaimedThisRun = 0;
  double _runDistanceKm = 0.0;
  Timer? _runTimer;
  int _runDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    
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

  Future<void> _checkPermissionsAndInitLocation() async {
    final isFirstTime = await _locationService.isFirstTimePermissionRequest();
    if (isFirstTime) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Realtime GPS Needed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Territory Runner requires your background location to let you capture territories in the real world!\n\nIf you deny this, the app will fall back to a Virtual Simulation Mode.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('GOT IT', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
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
          _updateHexagon(pos);
        });
        _rivalService.initializeRivals(_currentLocation!);
        _rivalService.startSimulation();
      }
    }

    _locationService.startTracking();
    _positionSub = _locationService.locationStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _updateHexagon(pos);
        });
      }
    });

    _rivalSub = _rivalService.onRivalsUpdated.listen((_) {
      if (mounted) setState(() {});
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

      if (_isRunActive) {
        _runCoordinates.add(_currentLocation!);
        if (_runCoordinates.length >= 2) {
          final p1 = _runCoordinates[_runCoordinates.length - 2];
          final p2 = _runCoordinates.last;
          _runDistanceKm += (Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude) / 1000.0);
          
          final int currentKmFloor = _runDistanceKm.floor();
          if (currentKmFloor > _lastAnnouncedKm && currentKmFloor >= 1) {
            _lastAnnouncedKm = currentKmFloor;
            _voiceCoach.announceDistanceMilestone(currentKmFloor, _computeCurrentPace());
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

  String _computeCurrentPace() {
    if (_runDistanceKm <= 0 || _runDurationSeconds <= 0) return "6'00\"/km";
    final double pace = (_runDurationSeconds / 60.0) / _runDistanceKm;
    final int paceMin = pace.floor().clamp(2, 20);
    final int paceSec = ((pace - paceMin) * 60).round().clamp(0, 59);
    return "$paceMin'${paceSec.toString().padLeft(2, '0')}\"/km";
  }

  void _toggleRun() {
    if (!_isRunActive) {
      // START RUN
      setState(() {
        _isRunActive = true;
        _hexesClaimedThisRun = 0;
        _runDistanceKm = 0.0;
        _runDurationSeconds = 0;
        _lastAnnouncedKm = 0;
        _runCoordinates.clear();
      });

      _runTimer?.cancel();
      _runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRunActive) {
          setState(() {
            _runDurationSeconds++;
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
      // STOP RUN & TRIGGER LLM COACH
      _runTimer?.cancel();
      final int finalSeconds = _runDurationSeconds;
      final double finalDistance = _runDistanceKm;
      final int finalHexes = _hexesClaimedThisRun;

      setState(() {
        _isRunActive = false;
      });

      _voiceCoach.announceRunComplete(finalDistance, finalHexes);
      _territoryService.addRunDistance(finalDistance);
      _showRunCompleteSummary(finalDistance, finalSeconds, finalHexes);
    }
  }

  Future<void> _suggestAiRoute() async {
    if (_currentLocation == null) return;

    setState(() {
      _isGeneratingRoute = true;
    });

    final profile = _territoryService.getProfile();
    final prediction = _paceService.predictTarget(profile);

    // Run Route Recommendation Engine
    final route = _routeService.suggestRoute(
      currentLocation: _currentLocation!,
      targetDistanceKm: prediction.predictedDistanceKm,
    );

    setState(() {
      _activeSuggestedRoute = route;
      _isGeneratingRoute = false;
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
    
    // Show instant bottom sheet with loading state while LLM generates
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
                                    'Gemini AI Run Coach analyzing telemetry...',
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
    _positionSub?.cancel();
    _territorySub?.cancel();
    _rivalSub?.cancel();
    _rivalService.stopSimulation();
    _runTimer?.cancel();
    _locationService.stopTracking();
    super.dispose();
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
    
    // Draw all permanently captured hexes with their owner faction color
    for (final territory in territories) {
      if (territory.polygon.length == 6) {
        polygons.add(
          Polygon(
            points: territory.polygon,
            color: territory.color.withValues(alpha: 0.35),
            borderColor: territory.color,
            borderStrokeWidth: 2.0,
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
            color: AppColors.accent.withValues(alpha: 0.1),
            borderColor: AppColors.accent.withValues(alpha: 0.5),
            borderStrokeWidth: 1.8,
          ),
        );
      }
    }
    
    return polygons;
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    
    // User Location Marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // AI Rival Runners Markers
    for (final rival in _rivalService.rivals) {
      markers.add(
        Marker(
          point: rival.currentPosition,
          width: 34,
          height: 34,
          child: Tooltip(
            message: '${rival.name} (${rival.faction})',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rival.color,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: rival.color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  rival.name.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The Interactive Map
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 17.0,
                    backgroundColor: AppColors.bgDeep,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    // Cyber-Dark theme map tiles
                    TileLayer(
                      urlTemplate: AppConstants.mapApiKey.isNotEmpty
                          ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token={accessToken}'
                          : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      additionalOptions: {
                        'accessToken': AppConstants.mapApiKey,
                      },
                      userAgentPackageName: 'com.territoryrunner.app',
                    ),
                    
                    // Hexagon Territory Overlay
                    PolygonLayer(
                      polygons: _buildPolygons(),
                    ),

                    // AI Recommended Route Polyline Overlay
                    if (_activeSuggestedRoute != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _activeSuggestedRoute!.polyline,
                            color: AppColors.accent,
                            strokeWidth: 4.5,
                          ),
                        ],
                      ),
                      
                    // Live Markers (Player & Rival Runners)
                    MarkerLayer(
                      markers: _buildMarkers(),
                    ),
                  ],
                ),
                
          // Top HUD
          Positioned(
            top: pad.top + 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _isRunActive
                        ? 'CONQUEST IN PROGRESS (${_runDurationSeconds ~/ 60}m ${_runDurationSeconds % 60}s)'
                        : 'GRID CONQUEST (LIVE)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: _isRunActive ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                if (!_isRunActive)
                  _MapIconButton(
                    icon: _isGeneratingRoute ? Icons.hourglass_top : Icons.auto_awesome,
                    tooltip: 'Suggest AI Route',
                    onPressed: _suggestAiRoute,
                  ),
                const SizedBox(width: 8),
                _MapIconButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter',
                  onPressed: _recenter,
                ),
              ],
            ),
          ),
          
          // Bottom HUD & Run Controls
          Positioned(
            left: 20,
            right: 20,
            bottom: pad.bottom + 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_activeSuggestedRoute != null && !_isRunActive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_run, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI LOOP ROUTE: ${_activeSuggestedRoute!.totalDistanceKm.toStringAsFixed(1)} KM',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '~${_activeSuggestedRoute!.estimatedNewTerritoryCount} new hexes reachable',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: () {
                            setState(() {
                              _activeSuggestedRoute = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                _MapBottomSheet(
                  isActive: _isRunActive,
                  distanceKm: _runDistanceKm,
                  hexesClaimed: _hexesClaimedThisRun,
                  onToggleRun: _toggleRun,
                ),
              ],
            ),
          ),
        ],
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

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onPressed, this.tooltip});
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 22, color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _MapBottomSheet extends StatelessWidget {
  const _MapBottomSheet({
    required this.isActive,
    required this.onToggleRun,
    this.distanceKm = 0.0,
    this.hexesClaimed = 0,
  });
  
  final bool isActive;
  final VoidCallback onToggleRun;
  final double distanceKm;
  final int hexesClaimed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isActive ? AppColors.accent : AppColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          if (isActive)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 5,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isActive
                      ? '${distanceKm.toStringAsFixed(2)} KM • $hexesClaimed HEXES'
                      : 'HEXAGON CONQUEST GRID',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: isActive ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                isActive ? 'Tracking active' : 'Live preview',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isActive ? Colors.redAccent : AppColors.accent,
                      foregroundColor: isActive ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onToggleRun,
                    child: Text(
                      isActive ? 'End Run & Get AI Insights' : 'Start Conquest Run',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
