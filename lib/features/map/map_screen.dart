import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/location_service.dart';
import '../../services/run_recovery_service.dart';
import '../../services/gps_quality_service.dart';
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
import '../../models/territory.dart';
import '../../services/firebase_service.dart';
import 'widgets/mode_tabs.dart';
import 'widgets/run_hud.dart';
import 'widgets/map_layers.dart';
import 'widgets/pacer_sheet.dart';
import 'widgets/summary_sheet.dart';
import 'widgets/leaderboard_sheet.dart';
import 'widgets/loop_celebration_overlay.dart';
import 'widgets/claim_planner_sheet.dart';

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
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _rivalPollingTimer;

  // Real-time WebSocket presence and alert state
  final Map<String, RunnerPresenceEvent> _activeRivalRunners = {};
  final Map<String, List<LatLng>> _rivalBreadcrumbs = {};
  Timer? _rivalSimulationTimer;
  bool _isRivalSimulating = false;
  double _rivalSimAngle = 0.0;
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

  // Real-time Client Preview Accumulation across all loops in run
  double _accumulatedRunPreviewArea = 0.0;
  int _accumulatedRunPreviewXp = 0;

  // Territory Defense & Fortification State
  String? _highlightedTerritoryId;

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

  // Crash/Kill recovery & GPS signal health state
  final RunRecoveryService _runRecoveryService = RunRecoveryService();
  GpsQuality _gpsQuality = GpsQuality.optimal;
  DateTime? _lastGpsFixTime;
  Timer? _gpsLivenessTimer;
  final bool _isScreenAwakeEnabled = true;

  @override
  void initState() {
    super.initState();

    // Listen to sync queue reconciliation delta toasts and authoritative rejections
    SyncQueueService().reconciliationToastNotifier.addListener(_onReconciliationToast);
    SyncQueueService().lastRejectionNotifier.addListener(_onRunRejected);
    
    // Listen for new territory captures
    _territorySub = _territoryService.territoryStream.listen((event) {
      if (mounted) {
        setState(() {});
      }
    });

    // Poll rival territories every 20 seconds while map screen is open
    _rivalPollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _fetchVisibleRivals();
      // Prune inactive rivals older than 60s
      final now = DateTime.now();
      _activeRivalRunners.removeWhere((id, runner) {
        final isStale = now.difference(runner.updatedAt).inSeconds > 60;
        if (isStale) {
          _rivalBreadcrumbs.remove(id);
        }
        return isStale;
      });
    });

    // Real-time WebSocket: Connect and listen for live rival runners and territory alerts
    _wsService.connect();
    _wsPresenceSub = _wsService.presenceStream.listen((presence) {
      if (mounted) {
        setState(() {
          _activeRivalRunners[presence.userId] = presence;
          final trail = _rivalBreadcrumbs.putIfAbsent(presence.userId, () => []);
          trail.add(presence.position);
          if (trail.length > 40) {
            trail.removeAt(0);
          }
        });
      }
    });

    _wsRunnerLeftSub = _wsService.runnerLeftStream.listen((userId) {
      if (mounted) {
        setState(() {
          _activeRivalRunners.remove(userId);
          _rivalBreadcrumbs.remove(userId);
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
                      'TERRITORY UNDER ATTACK!',
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
          action: SnackBarAction(
            label: 'DEFEND',
            textColor: const Color(0xFFFF3366),
            onPressed: _defendWeakestTerritory,
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      _fetchVisibleRivals();
    });

    _wsBroadcastSub = _wsService.broadcastStream.listen((_) {
      if (mounted) {
        _fetchVisibleRivals();
      }
    });

    _runRecoveryService.init();

    _gpsLivenessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _lastGpsFixTime != null) {
        final quality = GpsQualityService.evaluateQuality(
          accuracyMeters: _satelliteAccuracyMeters,
          lastFixTimestamp: _lastGpsFixTime!,
        );
        if (quality != _gpsQuality) {
          setState(() {
            _gpsQuality = quality;
            if (quality == GpsQuality.lost) {
              _satelliteAccuracyMeters = 99.0;
            }
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndInitLocation();
      _checkRecoverableRun();
    });
  }

  @override
  void dispose() {
    _gpsLivenessTimer?.cancel();
    WakelockPlus.disable();
    _rivalSimulationTimer?.cancel();
    SyncQueueService().reconciliationToastNotifier.removeListener(_onReconciliationToast);
    SyncQueueService().lastRejectionNotifier.removeListener(_onRunRejected);
    _runTimer?.cancel();
    _rivalPollingTimer?.cancel();
    _positionSub?.cancel();
    _territorySub?.cancel();
    _wsPresenceSub?.cancel();
    _wsRunnerLeftSub?.cancel();
    _wsAlertSub?.cancel();
    _wsBroadcastSub?.cancel();
    _wsService.disconnect();
    _locationService.stopTracking();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onReconciliationToast() {
    final msg = SyncQueueService().reconciliationToastNotifier.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.accent, width: 1.2),
          ),
          content: Text(
            msg,
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      );
    }
  }

  void _onRunRejected() {
    final rejection = SyncQueueService().lastRejectionNotifier.value;
    if (rejection != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E212B),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
          ),
          content: Text(
            '❌ ${rejection.humanReason}',
            style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          action: SnackBarAction(
            label: 'VIEW RUN',
            textColor: AppColors.accent,
            onPressed: () {
              SummarySheet.show(
                context: context,
                distanceKm: rejection.run.distanceMeters / 1000.0,
                durationSeconds: rejection.run.durationSeconds,
                territoriesClaimed: 0,
                profile: _territoryService.getProfile(),
                coachService: _coachService,
                routePoints: rejection.run.points,
                areaSqMeters: rejection.run.clientPreviewArea,
                rejectionReason: rejection.humanReason,
              );
            },
          ),
        ),
      );
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

  void _checkRecoverableRun() {
    if (_runRecoveryService.hasRecoverableRun()) {
      final snapshot = _runRecoveryService.getRecoverableRun();
      if (snapshot != null && mounted) {
        _showResumeRunDialog(snapshot);
      }
    }
  }

  void _showResumeRunDialog(ActiveRunSnapshot snapshot) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text(
              'RESUME RUN?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An interrupted run with ${snapshot.distanceKm.toStringAsFixed(2)} km recorded was recovered from local cache.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Distance: ${snapshot.distanceKm.toStringAsFixed(2)} km', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${snapshot.coordinates.length} GPS Points', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _runRecoveryService.clearRecovery();
            },
            child: const Text('DISCARD', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resumeRun(snapshot);
            },
            child: const Text('RESUME RUN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _resumeRun(ActiveRunSnapshot snapshot) {
    setState(() {
      _isRunActive = true;
      _runCoordinates.clear();
      _runCoordinates.addAll(snapshot.coordinates);
      _recentPositions.clear();
      _recentPositions.addAll(snapshot.positions);
      _runDistanceKm = snapshot.distanceKm;
      _elapsedDurationSeconds = snapshot.elapsedDurationSeconds;
      _movingDurationSeconds = snapshot.movingDurationSeconds;
      _territoriesClaimedThisRun = snapshot.territoriesClaimed;
      _accumulatedRunPreviewArea = snapshot.accumulatedPreviewArea;
      _accumulatedRunPreviewXp = snapshot.accumulatedPreviewXp;

      _polygonEngine.clear();
      for (final pt in snapshot.coordinates) {
        _polygonEngine.addPosition(pt);
      }
    });

    _startRunTimer();
    if (_isScreenAwakeEnabled) {
      WakelockPlus.enable();
    }
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
      // Check for signal gaps & suppress unrealistic jumps across tunnels/indoor areas
      final now = pos.timestamp;
      if (_lastGpsFixTime != null && GpsQualityService.isSignalGap(_lastGpsFixTime!, now)) {
        if (_runCoordinates.isNotEmpty) {
          final lastCoord = _runCoordinates.last;
          final newCoord = LatLng(pos.latitude, pos.longitude);
          final deltaSec = (now.difference(_lastGpsFixTime!).inMilliseconds / 1000.0).abs();
          if (GpsQualityService.isUnrealisticJump(lastCoord, newCoord, deltaSec)) {
            debugPrint('[GPS] Suppressed unrealistic gap jump across signal loss');
            _lastGpsFixTime = now;
            return;
          }
        }
      }
      _lastGpsFixTime = now;
      _gpsQuality = GpsQualityService.evaluateQuality(
        accuracyMeters: pos.accuracy,
        lastFixTimestamp: _lastGpsFixTime!,
      );

      // Track positions for anti-cheat & telemetry
      _recentPositions.add(pos);
      if (_recentPositions.length > 20) {
        _recentPositions.removeAt(0);
      }

      // Rolling window for instantaneous split pace calculation
      _rollingPaceWindow.add(pos);
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

    _accumulatedRunPreviewArea += claimed;
    _accumulatedRunPreviewXp += xp;

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

  void _startRunTimer() {
    _runTimer?.cancel();
    _runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRunActive) {
        setState(() {
          _elapsedDurationSeconds++;

          // Strava Auto-Pause Check using GpsQualityService stationary threshold
          if (GpsQualityService.isStationary(_currentSpeedKmh)) {
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

        // Persist active run to Hive every 5 seconds for crash/kill recovery
        if (_elapsedDurationSeconds % 5 == 0 && _runCoordinates.length >= 2) {
          _runRecoveryService.saveActiveRun(
            positions: List<Position>.from(_recentPositions),
            coordinates: List<LatLng>.from(_runCoordinates),
            startTime: DateTime.now().subtract(Duration(seconds: _elapsedDurationSeconds)),
            elapsedDurationSeconds: _elapsedDurationSeconds,
            movingDurationSeconds: _movingDurationSeconds,
            distanceKm: _runDistanceKm,
            territoriesClaimed: _territoriesClaimedThisRun,
            accumulatedPreviewArea: _accumulatedRunPreviewArea,
            accumulatedPreviewXp: _accumulatedRunPreviewXp,
          );
        }
      }
    });
  }

  void _toggleRun() {
    if (!_isRunActive) {
      // START RUN
      _polygonEngine.clear();
      setState(() {
        _isRunActive = true;
        _territoriesClaimedThisRun = 0;
        _accumulatedRunPreviewArea = 0.0;
        _accumulatedRunPreviewXp = 0;
        _runDistanceKm = 0.0;
        _elapsedDurationSeconds = 0;
        _movingDurationSeconds = 0;
        _lowSpeedDurationSeconds = 0;
        _isAutoPaused = false;
        _lastAnnouncedKm = 0;
        _runCoordinates.clear();
        _rollingPaceWindow.clear();
      });

      _startRunTimer();
      if (_isScreenAwakeEnabled) {
        WakelockPlus.enable();
      }

      showRunStartAnimation(context);
      _voiceCoach.announceRunStart();
    } else {
      // STOP RUN & TRIGGER SUMMARY
      _runTimer?.cancel();
      WakelockPlus.disable();
      _runRecoveryService.clearRecovery();
      final int finalSeconds = _movingDurationSeconds > 0 ? _movingDurationSeconds : _elapsedDurationSeconds;
      final double finalDistance = _runDistanceKm;
      final int finalTerritories = _territoriesClaimedThisRun;

      _territoryService.defendTerritory(_firebaseService.currentUserId);
      setState(() {
        _isRunActive = false;
        _isAutoPaused = false;
        _highlightedTerritoryId = null;
        _activeSuggestedRoute = null;
      });

      _voiceCoach.announceRunComplete(finalDistance, finalTerritories);
      _territoryService.addRunDistance(finalDistance);

      if (_runCoordinates.length >= 3) {
        SyncQueueService().enqueueRun(
          points: List<LatLng>.from(_runCoordinates),
          durationSeconds: finalSeconds,
          distanceMeters: finalDistance * 1000.0,
          clientPreviewArea: _accumulatedRunPreviewArea,
          clientPreviewXp: _accumulatedRunPreviewXp,
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
        areaSqMeters: _accumulatedRunPreviewArea > 0 ? _accumulatedRunPreviewArea : null,
      );
    }
  }

  void _openClaimPlanner() {
    final location = _currentLocation ?? const LatLng(37.7749, -122.4194);
    ClaimPlannerSheet.show(
      context: context,
      currentLocation: location,
      routeService: _routeService,
      initialTargetAreaSqM: 5000.0,
      onRouteGenerated: (route) {
        setState(() {
          _activeSuggestedRoute = route;
        });
        if (route.polyline.length >= 2) {
          try {
            _mapController.fitCamera(
              CameraFit.coordinates(
                coordinates: route.polyline,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
              ),
            );
          } catch (_) {}
        }
      },
      onStartRun: (route) {
        _startRunWithSuggestedRoute(route);
      },
    );
  }

  void _startRunWithSuggestedRoute(SuggestedRoute route) {
    setState(() {
      _activeSuggestedRoute = route;
      _selectedModeTab = 0; // Switch to Run mode tab
    });

    if (!_isRunActive) {
      _toggleRun();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.secondary, width: 1.2),
        ),
        content: Row(
          children: [
            const Icon(Icons.navigation_rounded, color: AppColors.secondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Active Guidance: Follow the Solar Orange path (${route.totalDistanceKm.toStringAsFixed(2)} km, ~${route.estimatedNewTerritoryAreaSqM.toStringAsFixed(0)} m² new land)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    if (route.polyline.length >= 2) {
      try {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: route.polyline,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
          ),
        );
      } catch (_) {}
    }

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
                        MapLayers.buildPolygonLayer(
                          territories,
                          highlightedTerritoryId: _highlightedTerritoryId,
                        ),
                        MapLayers.buildTerritoryBadgesLayer(territories),
                        MapLayers.buildPolylineLayer(
                          isRunActive: _isRunActive,
                          runCoordinates: _runCoordinates,
                          currentEnclosurePath: _polygonEngine.currentPath,
                          suggestedRouteCoordinates: _activeSuggestedRoute?.polyline,
                          rivalBreadcrumbs: _rivalBreadcrumbs,
                          activeRivalRunners: _activeRivalRunners,
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
                      if (index == 1) {
                        _openClaimPlanner();
                      } else if (index == 2) {
                        LeaderboardSheet.show(
                          context: context,
                          apiClient: _apiClient,
                          currentUserId: _territoryService.getProfile().id,
                        );
                      }
                    },
                  ),

                  // Live Rival Sector Radar Pill
                  if (_activeRivalRunners.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _panToNearestRival,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.rival.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.rival.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.rival,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_activeRivalRunners.length} RIVAL${_activeRivalRunners.length > 1 ? 'S' : ''} IN SECTOR',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.gps_fixed_rounded, color: AppColors.rival, size: 13),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                    onSimulateDecayAndAttack: _simulateDecayAndAttack,
                    isRivalSimulating: _isRivalSimulating,
                    onToggleRivalSimulation: _toggleRivalSimulation,
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
                        onSimulateDecayAndAttack: _simulateDecayAndAttack,
                        isRivalSimulating: _isRivalSimulating,
                        onToggleRivalSimulation: _toggleRivalSimulation,
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

            // Floating Defend CTA for Weak Territories
            if (!_isRunActive &&
                territories.any((t) =>
                    t.ownerId == _firebaseService.currentUserId && t.isWeak()))
              Positioned(
                bottom: pad.bottom + 175,
                right: 20,
                child: GestureDetector(
                  onTap: _defendWeakestTerritory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: AppSpacing.br16,
                      border: Border.all(color: AppColors.rival, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.rival.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.rival, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'DEFEND',
                          style: TextStyle(
                            color: AppColors.rival,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  void _defendWeakestTerritory() {
    final myId = _firebaseService.currentUserId;
    final box = Hive.isBoxOpen('territories_v3') ? Hive.box<Territory>('territories_v3') : null;
    final all = box?.values.whereType<Territory>().toList() ?? [];
    final myTerritories = all.where((t) => t.ownerId == myId).toList();

    Territory? weakest;
    double minStrength = 101.0;
    for (final t in myTerritories) {
      final s = t.computeCurrentStrength();
      if (s < minStrength) {
        minStrength = s;
        weakest = t;
      }
    }

    if (weakest != null) {
      setState(() {
        _highlightedTerritoryId = weakest!.id;
      });

      if (weakest.polygon.isNotEmpty) {
        final centroid = MapLayers.computeCentroid(weakest.polygon);
        _mapController.move(centroid, 17.0);
      }

      if (!_isRunActive) {
        _toggleRun();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Text(
            '🛡️ DEFENSE ENGAGED: Run through your territory to restore 100% strength (${minStrength.round()}% active)',
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _simulateDecayAndAttack() async {
    final myId = _firebaseService.currentUserId;
    final decayed = await _territoryService.simulateDecay(myId, targetStrength: 20.0, daysAgo: 5);
    if (decayed != null && mounted) {
      setState(() {
        _highlightedTerritoryId = decayed.id;
      });
      if (decayed.polygon.isNotEmpty) {
        final centroid = MapLayers.computeCentroid(decayed.polygon);
        _mapController.move(centroid, 17.0);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E1015),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
          ),
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3366), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TERRITORY UNDER ATTACK!',
                      style: TextStyle(
                        color: Color(0xFFFF3366),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '⚠️ Rival ShadowRunner captured 3,500 m²! Defenses compromised (20% strength).',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'DEFEND',
            textColor: const Color(0xFFFF3366),
            onPressed: _defendWeakestTerritory,
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _panToNearestRival() {
    if (_activeRivalRunners.isEmpty) return;

    RunnerPresenceEvent? nearest;
    double minDistance = double.infinity;
    const distanceCalc = Distance();
    final myLoc = _currentLocation ?? const LatLng(51.5074, -0.1278);

    for (final rival in _activeRivalRunners.values) {
      final dist = distanceCalc.as(LengthUnit.Meter, myLoc, rival.position);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = rival;
      }
    }

    if (nearest != null) {
      AppMotion.lightTick();
      try {
        _mapController.move(nearest.position, 17.5);
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 2),
          content: Text(
            '🎯 Tracking ${nearest.username} (${minDistance.round()}m away)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _toggleRivalSimulation() {
    if (_isRivalSimulating) {
      _rivalSimulationTimer?.cancel();
      _rivalSimulationTimer = null;
      setState(() {
        _isRivalSimulating = false;
        _activeRivalRunners.remove('sim_rival_phantom');
        _rivalBreadcrumbs.remove('sim_rival_phantom');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('⏹️ Live Rival Simulation stopped.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final center = _currentLocation ?? const LatLng(51.5074, -0.1278);
    _isRivalSimulating = true;
    _rivalSimAngle = 0.0;
    const double radiusMeters = 180.0;
    const double earthRadius = 6378137.0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rival,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('🔴 Live Rival active: ⚡ Phantom_Vanguard is running near you!'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    _rivalSimulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted || !_isRivalSimulating) {
        timer.cancel();
        return;
      }

      _rivalSimAngle += 0.12;
      if (_rivalSimAngle > 2 * math.pi) {
        _rivalSimAngle -= 2 * math.pi;
      }

      // Circular displacement around player's center
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
        speed: 3.2, // ~11.5 km/h
        heading: headingDeg,
        updatedAt: DateTime.now(),
      );

      setState(() {
        _activeRivalRunners['sim_rival_phantom'] = event;
        final trail = _rivalBreadcrumbs.putIfAbsent('sim_rival_phantom', () => []);
        trail.add(rivalPos);
        if (trail.length > 40) {
          trail.removeAt(0);
        }
      });
    });
  }
}
