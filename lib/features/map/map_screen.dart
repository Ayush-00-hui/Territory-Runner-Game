import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../ui/ui.dart';
import '../../core/utils/constants.dart';
import '../../services/location_service.dart';
import '../../services/run_recovery_service.dart';
import '../../services/gps_quality_service.dart';
import '../gameplay/territory_service.dart';
import '../routing/route_service.dart';
import '../coach/llm_coach_service.dart';
import '../../services/app_preferences.dart';
import '../gameplay/polygon_enclosure_engine.dart';
import '../../services/sync_queue.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../core/utils/geohash_utils.dart';
import '../../models/ws_events.dart';
import '../../models/territory.dart';
import '../../models/run_goal.dart';
import '../../models/activity_type.dart';
import '../../services/auto_pause_engine.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../services/battery_saver_service.dart';
import 'widgets/map_controls_rail.dart';
import 'widgets/sos_shield_button.dart';
import 'widgets/map_tools_sheet.dart';
import 'widgets/gps_sync_chip.dart';
import 'widgets/run_go_cue.dart';
import 'widgets/map_layers_sheet.dart';
import '../profile/widgets/offline_maps_sheet.dart';
import 'widgets/run_hud.dart';
import 'widgets/run_goal_sheet.dart';
import 'widgets/map_layers.dart';
import 'widgets/pacer_sheet.dart';
import 'widgets/summary_sheet.dart';
import 'widgets/loop_celebration_overlay.dart';
import 'widgets/claim_planner_sheet.dart';
import 'widgets/sos_beacon_sheet.dart';
import 'widgets/amoled_battery_saver_overlay.dart';
import '../../profile_page.dart';
import 'models/run_telemetry.dart';
import 'notifiers/run_telemetry_notifier.dart';

class MapScreenFeature extends StatefulWidget {
  final bool isActive;

  /// Global notifier indicating whether a run is actively in progress
  static final ValueNotifier<bool> isRunActiveNotifier =
      ValueNotifier<bool>(false);

  const MapScreenFeature({super.key, this.isActive = true});

  @override
  State<MapScreenFeature> createState() => _MapScreenFeatureState();
}

class _MapScreenFeatureState extends State<MapScreenFeature> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final TerritoryService _territoryService = TerritoryService();
  final RouteService _routeService = RouteService();
  final LLMCoachService _coachService = LLMCoachService();
  final AppPreferences _appPrefs = AppPreferences();
  final PolygonEnclosureEngine _polygonEngine = PolygonEnclosureEngine();
  final ApiClient _apiClient = ApiClient();
  final WebSocketService _wsService = WebSocketService();
  final FirebaseService _firebaseService = FirebaseService();
  final BatterySaverService _batterySaverService = BatterySaverService();
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
  StreamSubscription<bool>? _wsConnectionSub;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BoxEvent>? _territorySub;
  StreamSubscription<String>? _notificationSub;

  LatLng? _currentLocation;
  bool _isRunActive = false;
  int _lastAnnouncedKm = 0;
  final ExerciseActivityType _selectedActivity = ExerciseActivityType.running;

  // Phase 3 High-Performance State Notifiers
  final RunTelemetryNotifier _telemetryNotifier = RunTelemetryNotifier();
  final ValueNotifier<LatLng?> _liveLocationNotifier = ValueNotifier<LatLng?>(
    null,
  );
  final ValueNotifier<int> _runPathUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _hudHeightNotifier = ValueNotifier<double>(180.0);
  bool _showGoCue = false;

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
  bool _isAutoPaused = false;
  final AutoPauseEngine _autoPauseEngine = AutoPauseEngine();
  RunGoal _activeGoal = RunGoal.none;
  bool _goalCompletedAnnounced = false;
  double _currentSpeedKmh = 0.0;
  double _satelliteAccuracyMeters = 3.5;
  bool _isCameraFollowLocked = true;
  double? _distanceToClosureMeters;
  double? _proximityToClosure;
  String? _lastShownRejectionReason;
  final FocusNode _keyboardFocusNode = FocusNode();

  // Crash/Kill recovery & GPS signal health state
  final RunRecoveryService _runRecoveryService = RunRecoveryService();
  GpsQuality _gpsQuality = GpsQuality.optimal;
  DateTime? _lastGpsFixTime;
  Timer? _gpsLivenessTimer;
  final bool _isScreenAwakeEnabled = true;

  // Cached territory list & total area notifiers (zero Hive reads in build())
  bool _hasInitializedLocation = false;
  late final ValueNotifier<List<Territory>> _territoriesNotifier;
  late final ValueNotifier<double> _totalAreaSqKmNotifier;

  void _refreshTerritoryCache() {
    final list = _territoryService.getCapturedTerritoryObjects();
    final double totalArea = list.fold(0.0, (s, t) => s + t.areaSqMeters);
    _territoriesNotifier.value = list;
    _totalAreaSqKmNotifier.value = totalArea / 1000000.0;
  }

  void _startGpsLivenessTimer() {
    _gpsLivenessTimer?.cancel();
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
  }

  void _startRivalPolling() {
    _rivalPollingTimer?.cancel();
    _rivalPollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        _fetchVisibleRivals();
        final now = DateTime.now();
        _activeRivalRunners.removeWhere((id, runner) {
          final isStale = now.difference(runner.updatedAt).inSeconds > 60;
          if (isStale) {
            _rivalBreadcrumbs.remove(id);
          }
          return isStale;
        });
      }
    });
  }

  void _pauseIdleServices() {
    if (!_isRunActive) {
      _gpsLivenessTimer?.cancel();
      _gpsLivenessTimer = null;
      _rivalPollingTimer?.cancel();
      _rivalPollingTimer = null;
    }
  }

  void _resumeIdleServices() {
    if (!_isRunActive && mounted) {
      _startGpsLivenessTimer();
      _startRivalPolling();
    }
  }

  @override
  void initState() {
    super.initState();

    final initialTerritories = _territoryService.getCapturedTerritoryObjects();
    final double initialArea = initialTerritories.fold(
      0.0,
      (s, t) => s + t.areaSqMeters,
    );
    _territoriesNotifier = ValueNotifier<List<Territory>>(initialTerritories);
    _totalAreaSqKmNotifier = ValueNotifier<double>(initialArea / 1000000.0);

    // Listen to sync queue reconciliation delta toasts and authoritative rejections
    SyncQueueService().reconciliationToastNotifier.addListener(
      _onReconciliationToast,
    );
    SyncQueueService().lastRejectionNotifier.addListener(_onRunRejected);

    // Listen for new territory captures
    _territorySub = _territoryService.territoryStream.listen((event) {
      if (mounted) {
        _refreshTerritoryCache();
        setState(() {});
      }
    });

    // Listen for FCM notification deep links (e.g. attacked sector tapped)
    _notificationSub = NotificationService().onAttackedTerritoryTapped.listen((
      territoryId,
    ) {
      _focusOnAttackedTerritory(territoryId);
    });

    if (widget.isActive) {
      _startRivalPolling();
    }

    // Real-time WebSocket: Connect and listen for live rival runners and territory alerts
    _wsService.connect();
    _wsPresenceSub = _wsService.presenceStream.listen((presence) {
      if (mounted) {
        setState(() {
          _activeRivalRunners[presence.userId] = presence;
          final trail = _rivalBreadcrumbs.putIfAbsent(
            presence.userId,
            () => [],
          );
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
      _appPrefs.triggerAttackHaptic();
      AppToast.show(
        context,
        'Territory alert: ${alert.message}',
        icon: Icons.warning_amber_rounded,
        type: AppToastType.error,
        actionLabel: 'Defend',
        onAction: _defendWeakestTerritory,
        duration: const Duration(seconds: 8),
      );
      _fetchVisibleRivals();
    });

    _wsBroadcastSub = _wsService.broadcastStream.listen((_) {
      if (mounted) {
        _fetchVisibleRivals();
      }
    });

    _wsConnectionSub = _wsService.isConnectedStream.listen((isConnected) {
      if (!mounted) return;
      if (!isConnected) {
        // Live features stay off while disconnected
        setState(() {
          _activeRivalRunners.clear();
          _rivalBreadcrumbs.clear();
        });
      } else {
        // Rival markers and attack alerts resume automatically on reconnect
        if (_currentLocation != null) {
          final viewportCells = GeohashUtils.computeViewportCells(
            _currentLocation!,
          );
          _wsService.sendViewportSubscription(viewportCells, force: true);
          _wsService.sendPresenceUpdate(
            latitude: _currentLocation!.latitude,
            longitude: _currentLocation!.longitude,
            speed: _currentSpeedKmh / 3.6,
            heading: 0,
          );
        }
        _fetchVisibleRivals();
      }
    });

    _runRecoveryService.init();

    if (widget.isActive) {
      _startGpsLivenessTimer();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) {
        _checkPermissionsAndInitLocation();
        _checkRecoverableRun();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapScreenFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _resumeIdleServices();
        if (!_hasInitializedLocation) {
          _checkPermissionsAndInitLocation();
          _checkRecoverableRun();
        }
      } else {
        _pauseIdleServices();
      }
    }
  }

  @override
  void dispose() {
    _territoriesNotifier.dispose();
    _totalAreaSqKmNotifier.dispose();
    _notificationSub?.cancel();
    _gpsLivenessTimer?.cancel();
    WakelockPlus.disable();
    _rivalSimulationTimer?.cancel();
    SyncQueueService().reconciliationToastNotifier.removeListener(
      _onReconciliationToast,
    );
    SyncQueueService().lastRejectionNotifier.removeListener(_onRunRejected);
    _runTimer?.cancel();
    _rivalPollingTimer?.cancel();
    _positionSub?.cancel();
    _territorySub?.cancel();
    _wsPresenceSub?.cancel();
    _wsRunnerLeftSub?.cancel();
    _wsAlertSub?.cancel();
    _wsBroadcastSub?.cancel();
    _wsConnectionSub?.cancel();
    _wsService.disconnect();
    _locationService.stopTracking();
    _keyboardFocusNode.dispose();
    _telemetryNotifier.dispose();
    _liveLocationNotifier.dispose();
    _runPathUpdateNotifier.dispose();
    _hudHeightNotifier.dispose();
    MapScreenFeature.isRunActiveNotifier.value = false;
    super.dispose();
  }

  void _onReconciliationToast() {
    final msg = SyncQueueService().reconciliationToastNotifier.value;
    if (msg != null && mounted) {
      AppToast.show(
        context,
        msg,
        icon: Icons.sync_rounded,
        type: AppToastType.info,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _onRunRejected() {
    final rejection = SyncQueueService().lastRejectionNotifier.value;
    if (rejection != null && mounted) {
      AppToast.show(
        context,
        rejection.humanReason,
        icon: Icons.error_rounded,
        type: AppToastType.error,
        duration: const Duration(seconds: 8),
        actionLabel: 'View run',
        onAction: () {
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
      );
    }
  }

  Future<void> _checkPermissionsAndInitLocation() async {
    if (_hasInitializedLocation) return;
    _hasInitializedLocation = true;
    final isFirstTime = await _locationService.isFirstTimePermissionRequest();
    if (isFirstTime) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.accent, width: 1.2),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  'Location access',
                  style: AppText.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Territory Runner requires location access to track your running path and map claimed territories.',
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSpacing.s14),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppSpacing.br12,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.gps_fixed_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Precise GPS (meters)',
                        style: AppText.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s10),
              Text(
                'If location is unavailable or denied, you can use simulator mode.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            PrimaryButton(
              label: 'Enable location',
              onPressed: () => Navigator.of(ctx).pop(),
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
            Icon(
              Icons.history_toggle_off_rounded,
              color: AppColors.accent,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'RESUME RUN?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An interrupted run with ${snapshot.distanceKm.toStringAsFixed(2)} km recorded was recovered from local cache.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
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
                  Text(
                    'Distance: ${snapshot.distanceKm.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${snapshot.coordinates.length} GPS Points',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
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
            child: const Text(
              'Discard',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.br10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resumeRun(snapshot);
            },
            child: const Text(
              'Resume run',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _resumeRun(ActiveRunSnapshot snapshot) {
    setState(() {
      _isRunActive = true;
      MapScreenFeature.isRunActiveNotifier.value = true;
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

    _locationService.setTrackingMode(GpsTrackingMode.idle);
    _positionSub = _locationService.locationStream.listen((pos) {
      if (mounted) {
        final wasInitial = _currentLocation == null;
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _liveLocationNotifier.value = _currentLocation;
        _satelliteAccuracyMeters = pos.accuracy;
        _currentSpeedKmh = pos.speed * 3.6;
        _updatePosition(pos);

        if (_isCameraFollowLocked && _currentLocation != null) {
          try {
            _mapController.move(_currentLocation!, _mapController.camera.zoom);
          } catch (_) {}
        }

        // Update targeted telemetry notifier without full-screen rebuild
        _telemetryNotifier.updateGps(
          speedKmh: _currentSpeedKmh,
          accuracyMeters: _satelliteAccuracyMeters,
          distanceKm: _runDistanceKm,
          splitPace: _computeCurrentSplitPace(),
          distanceToClosure: _distanceToClosureMeters,
          proximityToClosure: _proximityToClosure,
          currentAreaSqm: _accumulatedRunPreviewArea,
        );

        if (wasInitial) {
          setState(() {});
        }

        // Subscribe to spatial viewport cells for targeted real-time rival presence
        final viewportCells = GeohashUtils.computeViewportCells(
          LatLng(pos.latitude, pos.longitude),
        );
        _wsService.sendViewportSubscription(viewportCells);

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
      if (_lastGpsFixTime != null &&
          GpsQualityService.isSignalGap(_lastGpsFixTime!, now)) {
        if (_runCoordinates.isNotEmpty) {
          final lastCoord = _runCoordinates.last;
          final newCoord = LatLng(pos.latitude, pos.longitude);
          final deltaSec =
              (now.difference(_lastGpsFixTime!).inMilliseconds / 1000.0).abs();
          if (GpsQualityService.isUnrealisticJump(
            lastCoord,
            newCoord,
            deltaSec,
          )) {
            AppLogger.info(
              'Suppressed unrealistic gap jump across signal loss',
              tag: 'MapScreen',
            );
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
      _rollingPaceWindow.removeWhere(
        (p) => now.difference(p.timestamp).inSeconds > 15,
      );

      if (_isRunActive) {
        _runCoordinates.add(_currentLocation!);
        _runPathUpdateNotifier.value++;

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
          _proximityToClosure = (1.0 - ((dist - 35.0) / (120.0 - 35.0))).clamp(
            0.0,
            1.0,
          );
        } else {
          _distanceToClosureMeters = null;
          _proximityToClosure = null;
        }

        // 1. Arbitrary Polygon Enclosure Tracking (Automatic)
        final loopEvent = _polygonEngine.addPosition(_currentLocation!);
        if (loopEvent != null) {
          _distanceToClosureMeters = null;
          _proximityToClosure = null;
          _lastShownRejectionReason = null;
          _territoryService
              .capturePolygonTerritory(
                polygon: loopEvent.polygon,
                areaSqMeters: loopEvent.areaSqMeters,
              )
              .then((_) {
                if (mounted) {
                  setState(() {});
                  _showCaptureOutcome();
                }
              });
        } else if (_polygonEngine.lastInvalidReason != null) {
          if (_lastShownRejectionReason != _polygonEngine.lastInvalidReason) {
            _lastShownRejectionReason = _polygonEngine.lastInvalidReason;
            AppToast.show(
              context,
              _polygonEngine.lastInvalidReason!,
              type: AppToastType.warning,
            );
          }
        } else {
          _lastShownRejectionReason = null;
        }

        // High-Precision Geodesic Metric Accumulation on WGS84
        if (_runCoordinates.length >= 2) {
          final p1 = _runCoordinates[_runCoordinates.length - 2];
          final p2 = _runCoordinates.last;
          final double segmentMeters = Geolocator.distanceBetween(
            p1.latitude,
            p1.longitude,
            p2.latitude,
            p2.longitude,
          );

          _runDistanceKm += (segmentMeters / 1000.0);
          _checkGoalCompletion();

          final int currentKmFloor = _runDistanceKm.floor();
          if (currentKmFloor > _lastAnnouncedKm && currentKmFloor >= 1) {
            _lastAnnouncedKm = currentKmFloor;
            HapticFeedback.heavyImpact();
            _appPrefs.triggerMilestoneHaptic();
            AppToast.show(
              context,
              'Milestone: $currentKmFloor.0 km completed • Split: ${_computeCurrentSplitPace()}',
              icon: Icons.flag_rounded,
              type: AppToastType.success,
              duration: const Duration(seconds: 4),
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
      final double deltaSec =
          (pLast.timestamp.difference(pFirst.timestamp).inMilliseconds / 1000.0)
              .abs();
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
      AppToast.show(
        context,
        'Already your territory — loop around new ground to claim more land.',
        type: AppToastType.info,
      );
      return;
    }

    _accumulatedRunPreviewArea += claimed;
    _accumulatedRunPreviewXp += xp;
    _checkGoalCompletion();

    setState(() {
      _territoriesClaimedThisRun++;
    });
    AppMotion.mediumTick();
    LoopCelebrationOverlay.show(context, areaSqMeters: claimed, xpAwarded: xp);
  }

  void _sealCurrentShape() {
    if (!_isRunActive) {
      AppToast.show(
        context,
        'Start a run first to claim territory',
        type: AppToastType.warning,
      );
      return;
    }

    final loopEvent = _polygonEngine.sealCurrentPath();
    if (loopEvent != null) {
      _territoryService
          .capturePolygonTerritory(
            polygon: loopEvent.polygon,
            areaSqMeters: loopEvent.areaSqMeters,
          )
          .then((_) {
            if (mounted) {
              setState(() {
                _distanceToClosureMeters = null;
                _proximityToClosure = null;
              });
              _showCaptureOutcome();
            }
          });
    } else {
      final errorMsg =
          _polygonEngine.lastInvalidReason ??
          'Need at least 3 GPS path points to seal a domain shape';
      AppToast.show(context, errorMsg, type: AppToastType.warning);
    }
  }

  Future<void> _openGoalSelector() async {
    AppMotion.lightTick();
    final goal = await RunGoalSheet.show(context, currentGoal: _activeGoal);
    if (goal != null && mounted) {
      setState(() {
        _activeGoal = goal;
        _goalCompletedAnnounced = false;
      });
      AppToast.show(
        context,
        goal.isActive
            ? 'Target set: ${goal.title}'
            : 'Exploration mode: Open run',
        icon: Icons.track_changes_rounded,
        type: AppToastType.info,
      );
    }
  }

  void _checkGoalCompletion() {
    if (_isRunActive && _activeGoal.isActive && !_goalCompletedAnnounced) {
      final currentMoving = _movingDurationSeconds > 0
          ? _movingDurationSeconds
          : _elapsedDurationSeconds;
      final progress = _activeGoal.computeProgress(
        currentDistanceKm: _runDistanceKm,
        currentDurationSeconds: currentMoving,
        currentAreaSqm: _accumulatedRunPreviewArea,
      );
      if (progress >= 1.0) {
        _goalCompletedAnnounced = true;
        _appPrefs.triggerGoalAchievedHaptic();
        HapticFeedback.heavyImpact();
        AppMotion.heavyBurst();
        AppToast.show(
          context,
          'Target completed: ${_activeGoal.title}',
          icon: Icons.emoji_events_rounded,
          type: AppToastType.success,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  void _startRunTimer() {
    _runTimer?.cancel();
    _runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRunActive) {
        _elapsedDurationSeconds++;

        // Smart Auto-Pause with Hysteresis (< 1.8 km/h for 3s to pause, >= 3.0 km/h to resume)
        final transition = _autoPauseEngine.tick(_currentSpeedKmh);
        if (transition == AutoPauseTransition.paused) {
          _isAutoPaused = true;
          _locationService.setTrackingMode(GpsTrackingMode.paused);
          _telemetryNotifier.setAutoPaused(true);
          _appPrefs.triggerAutoPauseHaptic();
          HapticFeedback.mediumImpact();
        } else if (transition == AutoPauseTransition.resumed) {
          _isAutoPaused = false;
          _locationService.setTrackingMode(GpsTrackingMode.activeRun);
          _telemetryNotifier.setAutoPaused(false);
          _appPrefs.triggerAutoResumeHaptic();
          HapticFeedback.lightImpact();
        }

        if (!_autoPauseEngine.isAutoPaused) {
          _movingDurationSeconds++;
        }

        _telemetryNotifier.tick(isAutoPaused: _isAutoPaused);
        _checkGoalCompletion();

        // Persist active run to Hive every 5 seconds for crash/kill recovery
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
      }
    });
  }

  void _toggleRun() {
    if (!_isRunActive) {
      // START RUN
      _polygonEngine.clear();
      _lastShownRejectionReason = null;
      _polygonEngine.setActivityType(_selectedActivity);
      _runCoordinates.clear();
      _rollingPaceWindow.clear();
      _runPathUpdateNotifier.value++;
      _telemetryNotifier.reset();
      _telemetryNotifier.setRunActive(true);
      _locationService.setTrackingMode(
        GpsTrackingMode.activeRun,
        liveStatusText: "${_selectedActivity.displayName} in progress...",
        activityType: _selectedActivity,
      );

      setState(() {
        _isRunActive = true;
        MapScreenFeature.isRunActiveNotifier.value = true;
        _showGoCue = true;
        _territoriesClaimedThisRun = 0;
        _accumulatedRunPreviewArea = 0.0;
        _accumulatedRunPreviewXp = 0;
        _runDistanceKm = 0.0;
        _elapsedDurationSeconds = 0;
        _movingDurationSeconds = 0;
        _isAutoPaused = false;
        _goalCompletedAnnounced = false;
        _autoPauseEngine.reset();
        _lastAnnouncedKm = 0;
      });

      _startRunTimer();
      if (_isScreenAwakeEnabled) {
        WakelockPlus.enable();
      }

      _appPrefs.triggerRunStartHaptic();
    } else {
      // STOP RUN & TRIGGER SUMMARY
      _runTimer?.cancel();
      WakelockPlus.disable();
      _runRecoveryService.clearRecovery();
      _autoPauseEngine.reset();
      _locationService.setTrackingMode(GpsTrackingMode.idle);
      _telemetryNotifier.setRunActive(false);

      final int finalSeconds = _movingDurationSeconds > 0
          ? _movingDurationSeconds
          : _elapsedDurationSeconds;
      final double finalDistance = _runDistanceKm;
      final int finalTerritories = _territoriesClaimedThisRun;

      _territoryService.defendTerritory(_firebaseService.currentUserId);
      _refreshTerritoryCache();
      setState(() {
        _isRunActive = false;
        MapScreenFeature.isRunActiveNotifier.value = false;
        _isAutoPaused = false;
        _lastShownRejectionReason = null;
        _highlightedTerritoryId = null;
        _activeSuggestedRoute = null;
      });

      _appPrefs.triggerRunCompleteHaptic();
      _territoryService.addRunDistance(finalDistance);

      if (_runCoordinates.length >= 3) {
        SyncQueueService().enqueueRun(
          points: List<LatLng>.from(_runCoordinates),
          durationSeconds: finalSeconds,
          distanceMeters: finalDistance * 1000.0,
          activityType: _selectedActivity.id,
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
        areaSqMeters: _accumulatedRunPreviewArea > 0
            ? _accumulatedRunPreviewArea
            : null,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 80,
                ),
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
    });

    if (!_isRunActive) {
      _toggleRun();
    }

    AppToast.show(
      context,
      'Route guidance active: ${route.totalDistanceKm.toStringAsFixed(2)} km, ~${route.estimatedNewTerritoryAreaSqM.toStringAsFixed(0)} m²',
      icon: Icons.navigation_rounded,
      type: AppToastType.info,
      duration: const Duration(seconds: 5),
    );
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
      AppLogger.warning(
        'Error polling rival territories: $e',
        tag: 'MapScreen',
      );
    }
  }

  void _inspectSectorAt(LatLng point) {
    HapticFeedback.selectionClick();
    final territories = _territoryService.getCapturedTerritoryObjects();
    final double area = territories.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    AppToast.show(
      context,
      'Location: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)} (${area.toStringAsFixed(0)} m² owned)',
      icon: Icons.place_outlined,
      type: AppToastType.info,
      duration: const Duration(seconds: 2),
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
      if (event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _locationService.moveSimulatedRunner(forwardMeters: 6.0);
      } else if (event.logicalKey == LogicalKeyboardKey.keyS ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _locationService.moveSimulatedRunner(forwardMeters: -4.0);
      } else if (event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _locationService.moveSimulatedRunner(turnDegrees: -15.0);
      } else if (event.logicalKey == LogicalKeyboardKey.keyD ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
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

    AppToast.show(
      context,
      'Streaming 400m automated GPS loop scenario',
      icon: Icons.play_arrow_rounded,
      type: AppToastType.info,
      duration: const Duration(seconds: 2),
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

    AppToast.show(
      context,
      'Rival territory simulated. Executing loop...',
      icon: Icons.play_arrow_rounded,
      type: AppToastType.info,
      duration: const Duration(seconds: 2),
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
    AppToast.show(
      context,
      'Speed alert: 48.5 km/h exceeds running limit (25 km/h).',
      icon: Icons.shield_rounded,
      type: AppToastType.error,
      duration: const Duration(seconds: 4),
    );
    HapticFeedback.heavyImpact();
  }

  void _openToolsSheet() {
    MapToolsSheet.show(
      context: context,
      onOpenPacer: () {
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
      onOpenGoals: _openGoalSelector,
      onOpenRoutePlanner: _openClaimPlanner,
      onToggleAmoled: () {
        AppMotion.mediumTick();
        _batterySaverService.setAmoledHudActive(true);
      },
      onOpenOfflineMaps: () {
        showOfflineMapsSheet(context);
      },
      onTriggerSos: () {
        showSosBeaconSheet(context, _currentLocation);
      },
      activePacerLabel: _locationService.pacerMode != VirtualPacerMode.none
          ? 'Pacer ${_locationService.pacerMode.name.replaceAll('sub', '')}:00'
          : 'Pacer off',
      activeGoalLabel: _activeGoal.isActive
          ? _activeGoal.formatRemaining(
              currentDistanceKm: _runDistanceKm,
              currentDurationSeconds: _movingDurationSeconds,
              currentAreaSqm: _accumulatedRunPreviewArea,
            )
          : 'No target set',
      isAmoledActive: _batterySaverService.isBatterySaverEnabled,
    );
  }

  void _openLayersSheet() {
    MapLayersSheet.show(
      context: context,
      onStyleChanged: () {
        if (mounted) setState(() {});
      },
      onLocateNearestRival: _panToNearestRival,
    );
  }

  void _onRecenterTapped() {
    setState(() {
      _isCameraFollowLocked = true;
    });
    _recenter();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final profile = _territoryService.getProfile();
    final String athleteName = profile.username.isNotEmpty
        ? profile.username
        : 'Runner';
    return PopScope(
      canPop: !_isRunActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitRunConfirmation();
      },
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: AppColors.bgDeep,
          body: Stack(
            fit: StackFit.expand,
          children: [
            // 1. The Interactive Fullscreen Map wrapped in RepaintBoundary
            _currentLocation == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
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
                        ValueListenableBuilder<List<Territory>>(
                          valueListenable: _territoriesNotifier,
                          builder: (context, territories, _) =>
                              MapLayers.buildPolygonLayer(
                                territories,
                                highlightedTerritoryId: _highlightedTerritoryId,
                              ),
                        ),
                        ValueListenableBuilder<List<Territory>>(
                          valueListenable: _territoriesNotifier,
                          builder: (context, territories, _) =>
                              MapLayers.buildTerritoryBadgesLayer(territories),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _runPathUpdateNotifier,
                          builder: (context, _, child) =>
                              MapLayers.buildPolylineLayer(
                                isRunActive: _isRunActive,
                                runCoordinates: _runCoordinates,
                                currentEnclosurePath:
                                    _polygonEngine.currentPath,
                                suggestedRouteCoordinates:
                                    _activeSuggestedRoute?.polyline,
                                rivalBreadcrumbs: _rivalBreadcrumbs,
                                activeRivalRunners: _activeRivalRunners,
                              ),
                        ),
                        ValueListenableBuilder<LatLng?>(
                          valueListenable: _liveLocationNotifier,
                          builder: (context, loc, child) =>
                              MapLayers.buildMarkerLayer(
                                currentLocation: loc ?? _currentLocation,
                                activeRivalRunners: _activeRivalRunners,
                              ),
                        ),
                        if (AppConstants.tileAttribution.isNotEmpty)
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                AppConstants.tileAttribution,
                                prependCopyright: false,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
            // 2. Minimal Athletic Top Bar: Avatar (opens Profile) + Faction chip (left), GpsSyncChip (right)
            Positioned(
              top: pad.top + 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label:
                            'Runner profile for $athleteName. Tap to view profile.',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            AppMotion.selectionTick();
                            Navigator.push(
                              context,
                              AppMotion.pageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.surfaceGlass,
                              child: Text(
                                athleteName.isNotEmpty
                                    ? athleteName[0].toUpperCase()
                                    : 'R',
                                style: AppText.headingSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  GpsSyncChip(
                    accuracyMeters: _satelliteAccuracyMeters,
                    isGpsSearching: _currentLocation == null,
                  ),
                ],
              ),
            ),

            // 3. Ergonomic Floating Controls (Dynamically anchored above measured HUD height)
            ValueListenableBuilder<bool>(
              valueListenable: _appPrefs.leftHandedModeNotifier,
              builder: (context, isLeftHanded, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: _hudHeightNotifier,
                  builder: (context, hudHeight, _) {
                    final bottomOffset = pad.bottom + 12 + hudHeight + 12;

                    return Stack(
                      children: [
                        // Thumb Controls Rail (Tools, Layers, Recenter)
                        Positioned(
                          left: isLeftHanded ? 16 : null,
                          right: isLeftHanded ? null : 16,
                          bottom: bottomOffset,
                          child: MapControlsRail(
                            isCameraLocked: _isCameraFollowLocked,
                            onOpenTools: _openToolsSheet,
                            onOpenLayers: _openLayersSheet,
                            onRecenter: _onRecenterTapped,
                          ),
                        ),

                        // Isolated Safety SOS Shield Button (Mirrored away from thumb rail)
                        Positioned(
                          left: isLeftHanded ? null : 16,
                          right: isLeftHanded ? 16 : null,
                          bottom: bottomOffset,
                          child: SosShieldButton(
                            onTriggerSos: () {
                              showSosBeaconSheet(context, _currentLocation);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            // 4. Strava-Grade Live Telemetry HUD Obsidian Glass Card
            Positioned(
              left: 16,
              right: 16,
              bottom: pad.bottom + 12,
              child: MeasureSize(
                onChange: (size) {
                  if (_hudHeightNotifier.value != size.height) {
                    _hudHeightNotifier.value = size.height;
                  }
                },
                child: ValueListenableBuilder<RunTelemetry>(
                  valueListenable: _telemetryNotifier,
                  builder: (context, telemetry, _) {
                    return RunHud(
                      isRunActive: _isRunActive,
                      isSearchingGps: _currentLocation == null,
                      isAutoPaused: telemetry.isAutoPaused,
                      distanceKm: telemetry.distanceKm,
                      elapsedSeconds: telemetry.elapsedSeconds,
                      movingSeconds: telemetry.movingSeconds,
                      splitPace: telemetry.splitPace,
                      currentSpeedKmh: telemetry.currentSpeedKmh,
                      satelliteAccuracyMeters:
                          telemetry.satelliteAccuracyMeters,
                      territoriesClaimed: telemetry.territoriesClaimed,
                      distanceToClosureMeters:
                          telemetry.distanceToClosureMeters,
                      proximityToClosure: telemetry.proximityToClosure,
                      targetPace:
                          _locationService.pacerMode != VirtualPacerMode.none
                          ? '${_locationService.pacerMode.name.replaceAll('sub', '')}:00'
                          : null,
                      runGoal: telemetry.activeGoal ?? _activeGoal,
                      currentAreaSqm: telemetry.currentAreaSqm,
                      onOpenGoalSelector: _openGoalSelector,
                      isBatterySaverActive:
                          _batterySaverService.isBatterySaverEnabled,
                      onToggleAmoledSaver: () {
                        AppMotion.mediumTick();
                        _batterySaverService.setAmoledHudActive(true);
                      },
                      onToggleRun: _toggleRun,
                      onSealShape: _sealCurrentShape,
                      onFinishRun: () {
                        if (_isRunActive) {
                          _toggleRun();
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // 5. Non-blocking Go Cue (<= 400 ms)
            if (_showGoCue)
              Positioned.fill(
                child: RunGoCue(
                  onDismissed: () {
                    if (mounted) setState(() => _showGoCue = false);
                  },
                ),
              ),

            // 6. AMOLED Pure Black Low-Power Screen Overlay (when active)
            ValueListenableBuilder<bool>(
              valueListenable: _batterySaverService.isAmoledHudActiveNotifier,
              builder: (context, isAmoledActive, _) {
                if (!isAmoledActive || !_isRunActive) {
                  return const SizedBox.shrink();
                }
                return ValueListenableBuilder<RunTelemetry>(
                  valueListenable: _telemetryNotifier,
                  builder: (context, telemetry, _) {
                    return AmoledBatterySaverOverlay(
                      distanceKm: telemetry.distanceKm,
                      elapsedSeconds: telemetry.elapsedSeconds,
                      splitPace: telemetry.splitPace,
                      currentSpeedKmh: telemetry.currentSpeedKmh,
                      runGoal: telemetry.activeGoal ?? _activeGoal,
                      onWake: () =>
                          _batterySaverService.setAmoledHudActive(false),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<void> _showExitRunConfirmation() async {
    AppMotion.lightTick();
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.br24,
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
        title: Text(
          'Pause or keep running?',
          style: AppText.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Your run is currently active. Do you want to pause your run and exit, or keep running?',
          style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Pause run',
              style: AppText.labelMedium.copyWith(color: AppColors.textMuted),
            ),
          ),
          PrimaryButton(
            label: 'Keep running',
            icon: Icons.directions_run_rounded,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      if (_isRunActive) {
        _toggleRun();
      }
    }
  }

  void _defendWeakestTerritory() {
    final myId = _firebaseService.currentUserId;
    final box = Hive.isBoxOpen('territories_v3')
        ? Hive.box<Territory>('territories_v3')
        : null;
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

      AppToast.show(
        context,
        'Defense active: run through territory to restore strength (${minStrength.round()}% remaining)',
        icon: Icons.shield_outlined,
        type: AppToastType.warning,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _simulateDecayAndAttack() async {
    final myId = _firebaseService.currentUserId;
    final decayed = await _territoryService.simulateDecay(
      myId,
      targetStrength: 20.0,
      daysAgo: 5,
    );
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
      AppToast.show(
        context,
        'Territory alert: rival captured 3,500 m² (20% strength remaining)',
        icon: Icons.warning_amber_rounded,
        type: AppToastType.error,
        actionLabel: 'Defend',
        onAction: _defendWeakestTerritory,
        duration: const Duration(seconds: 8),
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

      AppToast.show(
        context,
        'Tracking ${nearest.username} (${minDistance.round()}m away)',
        icon: Icons.radar_rounded,
        type: AppToastType.info,
        duration: const Duration(seconds: 2),
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
      AppToast.show(
        context,
        'Live rival simulation stopped',
        icon: Icons.stop_circle_outlined,
        type: AppToastType.info,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final center = _currentLocation ?? const LatLng(51.5074, -0.1278);
    _isRivalSimulating = true;
    _rivalSimAngle = 0.0;
    const double radiusMeters = 180.0;
    const double earthRadius = 6378137.0;

    AppToast.show(
      context,
      'Live rival active: Phantom_Vanguard is running nearby',
      icon: Icons.person_pin_circle_outlined,
      type: AppToastType.warning,
      duration: const Duration(seconds: 3),
    );

    _rivalSimulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) {
      if (!mounted || !_isRivalSimulating) {
        timer.cancel();
        return;
      }

      _rivalSimAngle += 0.12;
      if (_rivalSimAngle > 2 * math.pi) {
        _rivalSimAngle -= 2 * math.pi;
      }

      // Circular displacement around player's center
      final dLat =
          (radiusMeters * math.cos(_rivalSimAngle)) /
          earthRadius *
          (180.0 / math.pi);
      final dLng =
          (radiusMeters * math.sin(_rivalSimAngle)) /
          (earthRadius * math.cos(center.latitude * (math.pi / 180.0))) *
          (180.0 / math.pi);
      final rivalPos = LatLng(center.latitude + dLat, center.longitude + dLng);
      final headingDeg =
          ((_rivalSimAngle + math.pi / 2) * (180.0 / math.pi)) % 360.0;

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
        final trail = _rivalBreadcrumbs.putIfAbsent(
          'sim_rival_phantom',
          () => [],
        );
        trail.add(rivalPos);
        if (trail.length > 40) {
          trail.removeAt(0);
        }
      });
    });
  }

  void _focusOnAttackedTerritory(String territoryId) {
    if (!mounted) return;
    final territories = _territoryService.getCapturedTerritoryObjects();
    final match = territories.where((t) => t.id == territoryId).firstOrNull;

    setState(() {
      _highlightedTerritoryId = territoryId;
    });

    if (match != null && match.polygon.isNotEmpty) {
      final centroid = MapLayers.computeCentroid(match.polygon);
      _mapController.move(centroid, 17.0);
    }

    AppToast.show(
      context,
      'Territory alert: focused on $territoryId',
      icon: Icons.center_focus_strong_rounded,
      type: AppToastType.info,
      duration: const Duration(seconds: 4),
    );
  }
}
