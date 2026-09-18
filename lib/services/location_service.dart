import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  
  bool isSimulationMode = false;
  Timer? _simulationTimer;
  
  // Default simulation start point (e.g., San Francisco)
  double _simLat = 37.7749;
  double _simLng = -122.4194;
  double _simHeading = 45.0; // Moving North-East

  Stream<Position> get locationStream => _locationController.stream;

  /// Checks if this is the first time the app is asking for location.
  Future<bool> isFirstTimePermissionRequest() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('has_requested_location_permission') ?? false);
  }

  /// Mark that we have requested permission to avoid showing the pre-modal again.
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
    final hasPermission = await requestPermission();
    
    if (!hasPermission || isSimulationMode) {
      isSimulationMode = true;
      return _generateSimulatedPosition();
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      // Fallback if real GPS throws an exception (e.g. in some emulators/desktops)
      isSimulationMode = true;
      return _generateSimulatedPosition();
    }
  }

  void startTracking() async {
    final hasPermission = await requestPermission();
    
    if (!hasPermission || isSimulationMode) {
      isSimulationMode = true;
      _startSimulation();
      return;
    }

    try {
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Updates every 5 meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        _locationController.add(position);
      }, onError: (e) {
        // Fallback to simulation on error
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

  void dispose() {
    stopTracking();
    _locationController.close();
  }

  // --- INTERACTIVE SIMULATION MODE ---

  void _startSimulation() {
    _simulationTimer?.cancel();
    // Simulate movement every 1 second
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Move slightly (approx 5 meters per second = ~18 km/h running pace)
      // 1 degree latitude is approx 111km.
      // 5 meters is approx 0.000045 degrees.
      
      // Randomly drift the heading for realistic pathing
      _simHeading += (math.Random().nextDouble() - 0.5) * 10;
      
      final double distance = 0.000045;
      final double rad = _simHeading * math.pi / 180;
      
      _simLat += distance * math.cos(rad);
      _simLng += distance * math.sin(rad);
      
      _locationController.add(_generateSimulatedPosition());
    });
  }

  Position _generateSimulatedPosition() {
    return Position(
      latitude: _simLat,
      longitude: _simLng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: _simHeading,
      headingAccuracy: 0.0,
      speed: 5.0,
      speedAccuracy: 0.0,
      isMocked: true,
    );
  }
}
