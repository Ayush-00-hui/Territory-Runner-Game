import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../models/activity_type.dart';
import '../../../models/run_goal.dart';
import '../../../services/app_preferences.dart';
import '../../../services/auto_pause_engine.dart';
import '../../../services/gps_quality_service.dart';
import '../../../services/location_service.dart';
import '../../../services/run_recovery_service.dart';
import '../../gameplay/polygon_enclosure_engine.dart';
import '../../gameplay/territory_service.dart';
import '../notifiers/run_telemetry_notifier.dart';

/// Decoupled, headless execution controller for an active or idle run.
///
/// Encapsulates:
/// - GPS position filtering and spatial enclosure evaluation
/// - Auto-pause hysteresis and timer management
/// - Run metrics accumulation (distance, moving time, area preview, pace)
/// - Crash/kill recovery snapshots
/// - High-performance Targeted ValueNotifiers for 60 fps rendering
class MapRunController extends ChangeNotifier {
  final LocationService _locationService;
  final PolygonEnclosureEngine _polygonEngine;
  final AutoPauseEngine _autoPauseEngine;
  final RunRecoveryService _runRecoveryService;
  final AppPreferences _appPrefs;
  final TerritoryService _territoryService;

  // Real-time Notifiers
  final RunTelemetryNotifier telemetryNotifier = RunTelemetryNotifier();
  final ValueNotifier<LatLng?> liveLocationNotifier = ValueNotifier<LatLng?>(
    null,
  );
  final ValueNotifier<int> runPathUpdateNotifier = ValueNotifier<int>(0);

  // Run State
  bool _isRunActive = false;
  bool _isAutoPaused = false;
  int _elapsedDurationSeconds = 0;
  int _movingDurationSeconds = 0;
  double _runDistanceKm = 0.0;
  int _territoriesClaimedThisRun = 0;
  double _accumulatedRunPreviewArea = 0.0;
  int _accumulatedRunPreviewXp = 0;
  double _currentSpeedKmh = 0.0;
  double? _satelliteAccuracyMeters;
  double? _distanceToClosureMeters;
  double? _proximityToClosure;
  RunGoal _activeGoal = const RunGoal(
    type: GoalType.distance,
    targetValue: 5.0,
  );
  bool _goalCompletedAnnounced = false;

  final List<LatLng> _runCoordinates = [];
  final List<Position> _recentPositions = [];
  final List<double> _rollingPaceWindow = [];
  DateTime? _lastGpsFixTime;
  Timer? _runTimer;
  ExerciseActivityType _selectedActivity = ExerciseActivityType.running;

  // Callbacks for UI presentation
  VoidCallback? onGoalCompleted;
  ValueChanged<String>? onSpeedAnomalyDetected;
  ValueChanged<String>? onLoopRejected;

  MapRunController({
    LocationService? locationService,
    PolygonEnclosureEngine? polygonEngine,
    AutoPauseEngine? autoPauseEngine,
    RunRecoveryService? runRecoveryService,
    AppPreferences? appPrefs,
    TerritoryService? territoryService,
  }) : _locationService = locationService ?? LocationService(),
       _polygonEngine = polygonEngine ?? PolygonEnclosureEngine(),
       _autoPauseEngine = autoPauseEngine ?? AutoPauseEngine(),
       _runRecoveryService = runRecoveryService ?? RunRecoveryService(),
       _appPrefs = appPrefs ?? AppPreferences(),
       _territoryService = territoryService ?? TerritoryService();

  // Getters
  bool get isRunActive => _isRunActive;
  bool get isAutoPaused => _isAutoPaused;
  int get elapsedDurationSeconds => _elapsedDurationSeconds;
  int get movingDurationSeconds => _movingDurationSeconds;
  double get runDistanceKm => _runDistanceKm;
  int get territoriesClaimedThisRun => _territoriesClaimedThisRun;
  double get accumulatedRunPreviewArea => _accumulatedRunPreviewArea;
  int get accumulatedRunPreviewXp => _accumulatedRunPreviewXp;
  double get currentSpeedKmh => _currentSpeedKmh;
  double? get satelliteAccuracyMeters => _satelliteAccuracyMeters;
  double? get distanceToClosureMeters => _distanceToClosureMeters;
  double? get proximityToClosure => _proximityToClosure;
  RunGoal get activeGoal => _activeGoal;
  List<LatLng> get runCoordinates => List.unmodifiable(_runCoordinates);
  List<Position> get recentPositions => List.unmodifiable(_recentPositions);
  ExerciseActivityType get selectedActivity => _selectedActivity;

  void setGoal(RunGoal goal) {
    _activeGoal = goal;
    _goalCompletedAnnounced = false;
    telemetryNotifier.setGoal(goal);
    notifyListeners();
  }

  void setActivity(ExerciseActivityType activity) {
    _selectedActivity = activity;
    _polygonEngine.setActivityType(activity);
    notifyListeners();
  }

  /// Starts an active running session immediately without blocking modals
  void startRun() {
    if (_isRunActive) return;

    _polygonEngine.clear();
    _polygonEngine.setActivityType(_selectedActivity);
    _runCoordinates.clear();
    _recentPositions.clear();
    _rollingPaceWindow.clear();
    runPathUpdateNotifier.value++;

    telemetryNotifier.reset();
    telemetryNotifier.setRunActive(true);
    _locationService.setTrackingMode(
      GpsTrackingMode.activeRun,
      liveStatusText: "${_selectedActivity.displayName} in progress...",
      activityType: _selectedActivity,
    );

    _isRunActive = true;
    _isAutoPaused = false;
    _territoriesClaimedThisRun = 0;
    _accumulatedRunPreviewArea = 0.0;
    _accumulatedRunPreviewXp = 0;
    _runDistanceKm = 0.0;
    _elapsedDurationSeconds = 0;
    _movingDurationSeconds = 0;
    _goalCompletedAnnounced = false;
    _autoPauseEngine.reset();

    _startRunTimer();
    WakelockPlus.enable();
    _appPrefs.triggerRunStartHaptic();
    notifyListeners();
  }

  /// Completes an active running session and returns summary data
  Map<String, dynamic> stopRun() {
    _runTimer?.cancel();
    WakelockPlus.disable();
    _runRecoveryService.clearRecovery();
    _autoPauseEngine.reset();
    _locationService.setTrackingMode(GpsTrackingMode.idle);
    telemetryNotifier.setRunActive(false);

    final finalSeconds = _movingDurationSeconds > 0
        ? _movingDurationSeconds
        : _elapsedDurationSeconds;
    final finalDistance = _runDistanceKm;
    final finalTerritories = _territoriesClaimedThisRun;
    final finalArea = _accumulatedRunPreviewArea;
    final finalXp = _accumulatedRunPreviewXp;

    _isRunActive = false;
    notifyListeners();

    return {
      'durationSeconds': finalSeconds,
      'distanceKm': finalDistance,
      'territories': finalTerritories,
      'areaSqm': finalArea,
      'xp': finalXp,
      'points': List<LatLng>.from(_runCoordinates),
    };
  }

  /// Processes kinematic updates from GPS stream
  void processPosition(Position pos) {
    final now = pos.timestamp;
    _satelliteAccuracyMeters = pos.accuracy;
    _currentSpeedKmh = pos.speed * 3.6;

    // Signal gap check & jump suppression
    if (_lastGpsFixTime != null &&
        GpsQualityService.isSignalGap(_lastGpsFixTime!, now)) {
      if (_runCoordinates.isNotEmpty) {
        final lastCoord = _runCoordinates.last;
        final newCoord = LatLng(pos.latitude, pos.longitude);
        final gapSec =
            (now.difference(_lastGpsFixTime!).inMilliseconds / 1000.0).abs();
        if (GpsQualityService.isUnrealisticJump(lastCoord, newCoord, gapSec)) {
          _lastGpsFixTime = now;
          return;
        }
      }
    }
    _lastGpsFixTime = now;

    final latLng = LatLng(pos.latitude, pos.longitude);
    liveLocationNotifier.value = latLng;

    if (_isRunActive && !_isAutoPaused) {
      if (_runCoordinates.isNotEmpty) {
        const dist = Distance();
        final deltaMeters = dist(_runCoordinates.last, latLng);
        if (deltaMeters >= 2.0) {
          _runDistanceKm += (deltaMeters / 1000.0);
          _runCoordinates.add(latLng);
          _recentPositions.add(pos);
          runPathUpdateNotifier.value++;

          // Closure proximity calculation
          if (_polygonEngine.currentPath.length >= 3) {
            final start = _polygonEngine.currentPath.first;
            final distToStart = Geolocator.distanceBetween(
              latLng.latitude,
              latLng.longitude,
              start.latitude,
              start.longitude,
            );
            _distanceToClosureMeters = distToStart;
            _proximityToClosure =
                (1.0 - ((distToStart - 35.0) / (120.0 - 35.0))).clamp(0.0, 1.0);
          } else {
            _distanceToClosureMeters = null;
            _proximityToClosure = null;
          }

          final loopEvent = _polygonEngine.addPosition(latLng);
          if (loopEvent != null) {
            _handleEnclosedLoop(loopEvent);
          } else if (_polygonEngine.lastInvalidReason != null) {
            onLoopRejected?.call(_polygonEngine.lastInvalidReason!);
          }
        }
      } else {
        _runCoordinates.add(latLng);
        _recentPositions.add(pos);
        _polygonEngine.addPosition(latLng);
        runPathUpdateNotifier.value++;
      }
    }

    _updateTelemetryMetrics();
  }

  void _handleEnclosedLoop(EnclosedLoopEvent loopEvent) {
    _distanceToClosureMeters = null;
    _proximityToClosure = null;
    final area = loopEvent.areaSqMeters;
    final int xp = (area / 10.0).round().clamp(50, 1000);

    _territoriesClaimedThisRun++;
    _accumulatedRunPreviewArea += area;
    _accumulatedRunPreviewXp += xp;

    _territoryService.capturePolygonTerritory(
      polygon: loopEvent.polygon,
      areaSqMeters: area,
    );

    _appPrefs.triggerLoopClosedHaptic();
  }

  void _startRunTimer() {
    _runTimer?.cancel();
    _runTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunActive) return;
      _elapsedDurationSeconds++;

      final transition = _autoPauseEngine.tick(_currentSpeedKmh);
      if (transition == AutoPauseTransition.paused) {
        _isAutoPaused = true;
        _locationService.setTrackingMode(GpsTrackingMode.paused);
        telemetryNotifier.setAutoPaused(true);
      } else if (transition == AutoPauseTransition.resumed) {
        _isAutoPaused = false;
        _locationService.setTrackingMode(GpsTrackingMode.activeRun);
        telemetryNotifier.setAutoPaused(false);
      }

      if (!_autoPauseEngine.isAutoPaused) {
        _movingDurationSeconds++;
      }

      telemetryNotifier.tick(isAutoPaused: _isAutoPaused);
      _checkGoalCompletion();

      // Crash recovery persistence every 5 seconds
      if (_elapsedDurationSeconds % 5 == 0 && _runCoordinates.length >= 2) {
        _runRecoveryService.saveActiveRun(
          positions: List<Position>.from(_recentPositions),
          coordinates: List<LatLng>.from(_runCoordinates),
          startTime: DateTime.now().subtract(
            Duration(seconds: _elapsedDurationSeconds),
          ),
          elapsedDurationSeconds: _elapsedDurationSeconds,
          movingDurationSeconds: _movingDurationSeconds,
          distanceKm: _runDistanceKm,
          territoriesClaimed: _territoriesClaimedThisRun,
          accumulatedPreviewArea: _accumulatedRunPreviewArea,
          accumulatedPreviewXp: _accumulatedRunPreviewXp,
        );
      }
    });
  }

  void _checkGoalCompletion() {
    if (!_goalCompletedAnnounced && _activeGoal.isActive) {
      final progress = _activeGoal.computeProgress(
        currentDistanceKm: _runDistanceKm,
        currentDurationSeconds: _movingDurationSeconds > 0
            ? _movingDurationSeconds
            : _elapsedDurationSeconds,
        currentAreaSqm: _accumulatedRunPreviewArea,
      );
      if (progress >= 1.0) {
        _goalCompletedAnnounced = true;
        _appPrefs.triggerMilestoneHaptic();
        onGoalCompleted?.call();
      }
    }
  }

  void _updateTelemetryMetrics() {
    telemetryNotifier.updateGps(
      speedKmh: _currentSpeedKmh,
      accuracyMeters: _satelliteAccuracyMeters ?? 10.0,
      distanceKm: _runDistanceKm,
      splitPace: _computeSplitPace(),
      distanceToClosure: _distanceToClosureMeters,
      proximityToClosure: _proximityToClosure,
      currentAreaSqm: _accumulatedRunPreviewArea,
    );
  }

  String _computeSplitPace() {
    if (_currentSpeedKmh <= 0.5) return '--:--';
    final paceSecPerKm = (3600.0 / _currentSpeedKmh).round();
    final mins = paceSecPerKm ~/ 60;
    final secs = paceSecPerKm % 60;
    return "$mins'${secs.toString().padLeft(2, '0')}\"";
  }

  @override
  void dispose() {
    _runTimer?.cancel();
    telemetryNotifier.dispose();
    liveLocationNotifier.dispose();
    runPathUpdateNotifier.dispose();
    super.dispose();
  }
}
