import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/location_service.dart';
import '../gameplay/h3_service.dart';
import '../gameplay/territory_service.dart';
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
  
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BoxEvent>? _territorySub;
  
  LatLng? _currentLocation;
  String? _currentHexId;
  List<String> _capturedHexes = [];
  bool _isRunActive = false;

  @override
  void initState() {
    super.initState();
    
    // Load existing territories
    _capturedHexes = _territoryService.getCapturedTerritories();
    
    // Listen for new captures
    _territorySub = _territoryService.territoryStream.listen((event) {
      if (mounted) {
        setState(() {
          _capturedHexes = _territoryService.getCapturedTerritories();
        });
      }
    });

    _initLocation();
  }

  void _initLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _updateHexagon();
        });
        _mapController.move(_currentLocation!, 17.0);
      }
    }

    _locationService.startTracking();
    _positionSub = _locationService.locationStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _updateHexagon();
        });
      }
    });
  }

  void _updateHexagon() {
    if (_currentLocation != null) {
      final newHexId = _h3Service.getHexagonForLocation(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      
      if (_currentHexId != newHexId) {
        _currentHexId = newHexId;
        
        // If run is active, attempt to capture this new hexagon
        if (_isRunActive && _currentHexId != null) {
          _territoryService.captureTerritory(_currentHexId!);
        }
      }
    }
  }

  void _toggleRun() {
    setState(() {
      _isRunActive = !_isRunActive;
      
      // If we just started a run, immediately capture the current hexagon
      if (_isRunActive && _currentHexId != null) {
        showRunStartAnimation(context);
        _territoryService.captureTerritory(_currentHexId!);
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _territorySub?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }

  void _recenter() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 17.0);
    }
  }

  List<Polygon> _buildPolygons() {
    List<Polygon> polygons = [];
    
    // Draw all permanently captured hexes
    for (String hexId in _capturedHexes) {
      polygons.add(
        Polygon(
          points: _h3Service.getHexagonVertices(hexId),
          color: AppColors.accent.withOpacity(0.4),
          borderColor: AppColors.accent,
          borderStrokeWidth: 2.5,
        )
      );
    }
    
    // Draw current outline if not already captured
    if (_currentHexId != null && !_capturedHexes.contains(_currentHexId!)) {
      polygons.add(
        Polygon(
          points: _h3Service.getHexagonVertices(_currentHexId!),
          color: AppColors.accent.withOpacity(0.1),
          borderColor: AppColors.accent.withOpacity(0.5),
          borderStrokeWidth: 2.0,
        )
      );
    }
    
    return polygons;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The actual Interactive Map
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
                    // Free Dark theme using OpenStreetMap + Color Inversion
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,  0,  0, 0, 255, // Red
                         0, -1,  0, 0, 255, // Green
                         0,  0, -1, 0, 255, // Blue
                         0,  0,  0, 1,   0, // Alpha
                      ]),
                      child: TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.territoryrunner.app',
                      ),
                    ),
                    
                    // Hexagon Territory Overlay
                    PolygonLayer(
                      polygons: _buildPolygons(),
                    ),
                      
                    // Current User Location Marker
                    MarkerLayer(
                      markers: [
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
                                  color: AppColors.accent.withOpacity(0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                          ),
                        ),
                      ],
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
                Text(
                  _isRunActive ? 'RUNNING...' : 'MAP (LIVE)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: _isRunActive ? AppColors.accent : Colors.white.withOpacity(0.85),
                  ),
                ),
                const Spacer(),
                _MapIconButton(
                  icon: Icons.my_location_rounded,
                  onPressed: _recenter,
                ),
              ],
            ),
          ),
          
          // Bottom Sheet
          Positioned(
            left: 20,
            right: 20,
            bottom: pad.bottom + 24,
            child: _MapBottomSheet(
              isActive: _isRunActive,
              onToggleRun: _toggleRun,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withOpacity(0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

class _MapBottomSheet extends StatelessWidget {
  const _MapBottomSheet({required this.isActive, required this.onToggleRun});
  
  final bool isActive;
  final VoidCallback onToggleRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isActive ? AppColors.accent : AppColors.border.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          if (isActive)
            BoxShadow(
              color: AppColors.accent.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 5,
            )
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
                  isActive ? 'RUN IN PROGRESS' : 'Territory outline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: isActive ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                'Live preview',
                style: TextStyle(
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
                      backgroundColor: isActive ? Colors.white : AppColors.accent,
                      foregroundColor: isActive ? AppColors.bgDeep : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onToggleRun,
                    child: Text(
                      isActive ? 'Stop Run' : 'Start Run',
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
