import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simulation modes for desktop, browser, and indoor development
enum VirtualPacerMode {
  none, // Real GNSS Hardware Stream
  walking, // 5.0 km/h (~1.39 m/s)
  running, // 10.0 km/h (~2.78 m/s)
  sprinting, // 15.0 km/h (~4.17 m/s)
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  
  bool isSimulationMode = false;
  VirtualPacerMode _pacerMode = VirtualPacerMode.none;
  Timer? _simulationTimer;
  
  // Default simulation start point (e.g., San Francisco)
  double _simLat = 37.7749;
  double _simLng = -122.4194;
  double _simHeading = 45.0; // Moving North-East
  Position? _lastValidPosition;

  Stream<Position> get locationStream => _locationController.stream;
  VirtualPacerMode get pacerMode => _pacerMode;
  double get simHeading => _simHeading;

  /// Checks local storage for first-time permission grant
  Future<bool> isFirstTimePermissionRequest() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('has_requested_location_permission') ?? false);
  }

  /// Mark that we have requested permission to avoid showing the pre-modal again
  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_requested_location_permission', true);
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      isSimulationMode = true;
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        isSimulationMode = true;
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      isSimulationMode = true;
      return false;
    }
    
    isSimulationMode = false;
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    if (_pacerMode != VirtualPacerMode.none) {
      return _generateSimulatedPosition();
    }

    final hasPermission = await requestPermission();
    
    if (!hasPermission || isSimulationMode) {
      isSimulationMode = true;
      return _generateSimulatedPosition();
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      if (isValidFix(pos, _lastValidPosition)) {
        _lastValidPosition = pos;
        return pos;
      }
      return _lastValidPosition ?? pos;
    } catch (e) {
      isSimulationMode = true;
      return _generateSimulatedPosition();
    }
  }

  /// High-Precision Jitter & Multipath Outlier Filtering:
  /// 1. Reject fixes with satellite accuracy dilution > 30 meters.
  /// 2. Suppress stationary GPS wandering (displacement < 1.8m when velocity < 2.0 km/h).
  /// 3. Discard satellite multipath outliers > 35 km/h (unless Zero-G mode is active).
  bool isValidFix(Position newPos, Position? lastPos, {bool isZeroG = false}) {
    // 1. Accuracy dilution gate
    if (newPos.accuracy > 30.0) {
      return false;
    }

    if (lastPos == null) {
      return true;
    }

    final double distanceMeters = Geolocator.distanceBetween(
      lastPos.latitude,
      lastPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    final double timeDeltaSeconds = (newPos.timestamp.difference(lastPos.timestamp).inMilliseconds / 1000.0).abs();
    final double calculatedSpeedKmh = timeDeltaSeconds > 0 ? (distanceMeters / timeDeltaSeconds) * 3.6 : 0.0;

    // 2. Stationary jitter gate: ignore small wandering < 1.8m if speed < 2.0 km/h
    if (distanceMeters < 1.8 && (newPos.speed * 3.6 < 2.0 || calculatedSpeedKmh < 2.0)) {
      return false;
    }

    // 3. Satellite multipath outlier gate: discard impossible spikes > 35 km/h unless Zero-G is active
    if (!isZeroG && (calculatedSpeedKmh > 35.0 || (newPos.speed * 3.6 > 35.0 && timeDeltaSeconds < 5.0))) {
      return false;
    }

    return true;
  }

  void startTracking({bool isZeroG = false}) async {
    if (_pacerMode != VirtualPacerMode.none) {
      _startSimulation();
      return;
    }

    final hasPermission = await requestPermission();
    
    if (!hasPermission || isSimulationMode) {
      isSimulationMode = true;
      _startSimulation();
      return;
    }

    try {
      // 5m distance filter for battery-friendly, high-accuracy GPS streams
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        if (isValidFix(position, _lastValidPosition, isZeroG: isZeroG)) {
          _lastValidPosition = position;
          _locationController.add(position);
        }
      }, onError: (e) {
        isSimulationMode = true;
        _startSimulation();
      });
    } catch (e) {
      isSimulationMode = true;
      _startSimulation();
    }
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void setVirtualPacer(VirtualPacerMode mode) {
    _pacerMode = mode;
    if (mode == VirtualPacerMode.none) {
      isSimulationMode = false;
      _simulationTimer?.cancel();
      startTracking();
    } else {
      isSimulationMode = true;
      _positionStreamSubscription?.cancel();
      _startSimulation();
    }
  }

  /// Interactive keyboard simulation movement (W/A/S/D and Arrow keys)
  void moveSimulatedRunner({double forwardMeters = 0.0, double turnDegrees = 0.0}) {
    _simHeading = (_simHeading + turnDegrees) % 360.0;
    if (_simHeading < 0) _simHeading += 360.0;

    if (forwardMeters != 0.0) {
      final double deltaLat = (forwardMeters / 111139.0) * math.cos(_simHeading * math.pi / 180.0);
      final double deltaLng = (forwardMeters / (111139.0 * math.cos(_simLat * math.pi / 180.0))) * math.sin(_simHeading * math.pi / 180.0);
      
      _simLat += deltaLat;
      _simLng += deltaLng;

      final double speed = (forwardMeters.abs() / 0.5).clamp(1.0, 6.0);
      final simPos = _generateSimulatedPosition(speedMps: speed);
      _lastValidPosition = simPos;
      _locationController.add(simPos);
    }
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }

  // --- VIRTUAL PACER & SATELLITE GNSS SIMULATION ENGINE ---

  void _startSimulation() {
    _simulationTimer?.cancel();
    // 1Hz simulation clock
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      double targetSpeedMps = 2.78; // Default 10 km/h
      switch (_pacerMode) {
        case VirtualPacerMode.walking:
          targetSpeedMps = 1.39; // 5 km/h
          break;
        case VirtualPacerMode.running:
          targetSpeedMps = 2.78; // 10 km/h
          break;
        case VirtualPacerMode.sprinting:
          targetSpeedMps = 4.17; // 15 km/h
          break;
        case VirtualPacerMode.none:
          targetSpeedMps = 2.78;
          break;
      }

      // Natural micro-oscillation heading drift for lifelike athletic curves
      _simHeading += (math.Random.secure().nextDouble() - 0.5) * 8.0;
      
      // 1 deg lat ~= 111,139 meters
      final double distanceMeters = targetSpeedMps;
      final double deltaLat = (distanceMeters / 111139.0) * math.cos(_simHeading * math.pi / 180.0);
      final double deltaLng = (distanceMeters / (111139.0 * math.cos(_simLat * math.pi / 180.0))) * math.sin(_simHeading * math.pi / 180.0);
      
      _simLat += deltaLat;
      _simLng += deltaLng;
      
      final simPos = _generateSimulatedPosition(speedMps: targetSpeedMps);
      _lastValidPosition = simPos;
      _locationController.add(simPos);
    });
  }

  Position _generateSimulatedPosition({double speedMps = 2.78}) {
    return Position(
      latitude: _simLat,
      longitude: _simLng,
      timestamp: DateTime.now(),
      accuracy: 3.5,
      altitude: 12.0,
      altitudeAccuracy: 1.0,
      heading: _simHeading,
      headingAccuracy: 2.0,
      speed: speedMps,
      speedAccuracy: 0.2,
      isMocked: true,
    );
  }
}
