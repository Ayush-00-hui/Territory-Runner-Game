import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/geohash_utils.dart';
import '../../models/activity_type.dart';
import '../../models/loot_crate.dart';
import '../../models/territory.dart';
import '../../models/ws_events.dart';
import '../../services/api_client.dart';
import '../../services/app_preferences.dart';
import '../../services/battery_saver_service.dart';
import '../../services/firebase_service.dart';
import '../../services/ghost_runner_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/run_log_service.dart';
import '../../services/websocket_service.dart';
import '../../ui/ui.dart';
import '../coach/llm_coach_service.dart';
import '../coach/pace_prediction_service.dart';
import '../gameplay/territory_service.dart';
import '../routing/route_service.dart';
import 'controllers/map_run_controller.dart';
import 'models/run_telemetry.dart';
import 'widgets/amoled_battery_saver_overlay.dart';
import 'widgets/claim_planner_sheet.dart';
import 'widgets/ghost_runner_picker_sheet.dart';
import 'widgets/interval_workout_picker_sheet.dart';
import 'widgets/loop_celebration_overlay.dart';
import 'widgets/map_demo_runner.dart';
import 'widgets/map_exit_dialog.dart';
import 'widgets/map_floating_controls.dart';
import 'widgets/map_hud_panel.dart';
import 'widgets/map_layers_sheet.dart';
import 'widgets/map_run_finisher.dart';
import 'widgets/map_tools_sheet.dart';
import 'widgets/map_top_bar.dart';
import 'widgets/map_viewport.dart';
import 'widgets/pacer_sheet.dart';
import 'widgets/run_countdown_overlay.dart';
import 'widgets/run_go_cue.dart';
import 'widgets/run_goal_sheet.dart';
import 'widgets/run_recovery_dialog.dart';
import 'widgets/saved_loops_sheet.dart';
import 'widgets/sos_beacon_sheet.dart';
import 'widgets/summary_sheet.dart';
import '../profile/widgets/body_details_sheet.dart';
import '../profile/widgets/offline_maps_sheet.dart';
import '../social/widgets/social_hub_sheet.dart';
import '../../services/arcade_audio_service.dart';
import '../../services/citadel_service.dart';
import '../../services/drone_companion_service.dart';
import '../../services/fog_of_war_service.dart';
import '../../services/tactical_ai_engine.dart';
import '../gameplay/guardian_challenge_service.dart';
import '../gameplay/incursion_service.dart';
import '../gameplay/loot_crate_service.dart';
import 'widgets/loot_collected_sheet.dart';
import 'widgets/sector_guardian_chip.dart';
import 'widgets/sprint_incursion_banner.dart';

export 'controllers/map_run_controller.dart';
export 'widgets/summary_sheet.dart';

/// Helper to estimate steps from distance based on exercise activity type.
/// Returns null for cycling where step counts are not applicable.
int? estimateSteps(
  double distanceKm, [
  ExerciseActivityType activity = ExerciseActivityType.running,
]) {
  if (activity == ExerciseActivityType.cycling) return null;
  final meters = distanceKm * 1000.0;
  if (activity == ExerciseActivityType.walking) return (meters / 0.75).round();
  return (meters / 1.05).round();
}

/// Pure Layout Map Screen displaying real-time runner tracks and claimed territories.
class MapScreen extends StatefulWidget {
  final bool isActive;

  /// Global notifier indicating whether a run is actively in progress
  static final ValueNotifier<bool> isRunActiveNotifier = ValueNotifier<bool>(
    false,
  );

  const MapScreen({super.key, this.isActive = true});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Backward compatibility alias for MapScreenFeature
typedef MapScreenFeature = MapScreen;

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final ValueNotifier<double> _hudHeightNotifier = ValueNotifier<double>(180.0);
  final ValueNotifier<List<Territory>> _territoriesNotifier =
      ValueNotifier<List<Territory>>([]);

  late final AnimationController _cameraAnimationController;
  Animation<double>? _cameraCurvedAnimation;
  VoidCallback? _cameraListener;

  MapRunController? _localController;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<String>? _territoryFocusSub;
  StreamSubscription<RunnerPresenceEvent>? _wsPresenceSub;
  StreamSubscription<String>? _wsRunnerLeftSub;
  StreamSubscription<TerritoryAlertEvent>? _wsAlertSub;
  StreamSubscription<LootCrate>? _crateSub;
  DateTime? _lastBBoxFetchAt;
  LatLng? _lastBBoxCenter;
  bool _showGoCue = false;

  MapRunController _resolveController() {
    try {
      return Provider.of<MapRunController>(context, listen: false);
    } catch (_) {
      return _localController ??= MapRunController();
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMapState();
    });
  }

  void _initMapState() {
    final controller = _resolveController();
    _refreshTerritoryCache();

    unawaited(TacticalAiEngine().init());
    unawaited(FogOfWarService().init());
    _crateSub = LootCrateService().onCrateCollected.listen((crate) {
      if (mounted) {
        LootCollectedSheet.show(context, crate);
      }
    });

    controller.onLoopCaptured = (loop, netArea, xp) {
      if (!mounted) return;
      CitadelService().checkPolygonEnclosure(
        loop.polygon,
        'Athlete',
        'Apex Vanguard',
      );
      ArcadeAudioService().playLoopVictoryChime();
      DroneCompanionService().onLoopClosed();
      LoopCelebrationOverlay.show(
        context,
        areaSqMeters: netArea,
        xpAwarded: xp,
      );
    };

    controller.onLoopRejected = (reason) {
      if (!mounted) return;
      AppToast.show(
        context,
        reason,
        icon: Icons.info_outline,
        type: AppToastType.warning,
      );
    };

    controller.onGpsSignalRestored = () {
      if (!mounted) return;
      AppToast.show(context, 'GPS signal restored', type: AppToastType.success);
    };

    LocationService().gpsStatusNotifier.addListener(_onGpsStatusChanged);

    if (controller.hasRecoverableRun()) {
      final snapshot = controller.getRecoverableRun();
      if (snapshot != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => RunRecoveryDialog(
            snapshot: snapshot,
            onResume: () {
              Navigator.pop(ctx);
              controller.resumeRecoveredRun(snapshot);
              _animateCameraMove(snapshot.coordinates.last, 17.0);
            },
            onDiscard: () {
              Navigator.pop(ctx);
              controller.clearRecovery();
            },
          ),
        );
      }
    }

    final bool isTestEnv = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');

    if (!isTestEnv) {
      final ws = WebSocketService();
      _wsPresenceSub = ws.presenceStream.listen((event) {
        if (!mounted) return;
        controller.upsertLiveRival(event);
      });
      _wsRunnerLeftSub = ws.runnerLeftStream.listen((userId) {
        if (!mounted) return;
        controller.removeLiveRival(userId);
      });
      _wsAlertSub = ws.alertStream.listen((alert) {
        if (!mounted) return;
        AppToast.show(
          context,
          '${alert.attackerName} entered your territory zone',
          icon: Icons.shield_outlined,
          type: AppToastType.warning,
        );
      });
      unawaited(ws.connect());
      if (controller.currentLocation != null) {
        ws.sendViewportSubscription(
          GeohashUtils.computeViewportCells(controller.currentLocation!),
        );
        unawaited(_syncNearbyTerritories(controller.currentLocation!));
      }
    }

    _positionSub = LocationService().locationStream.listen((pos) {
      if (!mounted) return;
      controller.processPosition(pos);
      final target =
          controller.currentLocation ?? LatLng(pos.latitude, pos.longitude);
      if (controller.isCameraFollowLocked) {
        _animateCameraMove(target, _mapController.camera.zoom);
      }
      if (!isTestEnv) {
        final ws = WebSocketService();
        ws.sendViewportSubscription(GeohashUtils.computeViewportCells(target));
        ws.sendPresenceUpdate(
          latitude: pos.latitude,
          longitude: pos.longitude,
          speed: pos.speed,
          heading: pos.heading,
        );
        if (_shouldRefreshBBox(target)) {
          unawaited(_syncNearbyTerritories(target));
        }
      }

      // Live gameplay services update
      FogOfWarService().revealFogAt(target);
      LootCrateService().updateRunnerLocation(target, pos.speed, 5.0);
      IncursionService().updateRunnerSpeed(pos.speed);
      GuardianChallengeService().updateAthleteProgress(
        controller.runDistanceKm * 1000.0,
        target,
      );
      if (controller.isRunActive && LootCrateService().activeCrates.isEmpty) {
        LootCrateService().spawnProceduralCrate(
          runnerPos: target,
          headingDeg: pos.heading,
        );
      }
      CitadelService().seedCitadelsNear(target);
    });

    LocationService().warmUpLocation();

    _territoryFocusSub = NotificationService().onAttackedTerritoryTapped.listen(
      (territoryId) {
        if (!mounted) return;
        _focusOnTerritory(territoryId);
      },
    );

    final pendingTerritoryId = NotificationService()
        .consumePendingTerritoryId();
    if (pendingTerritoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusOnTerritory(pendingTerritoryId);
        }
      });
    }
  }

  /// Smoothly glides the map camera to [destLocation] and [destZoom] over [AppMotion.standard] (220ms).
  /// Falls back to instant move when reduced motion is preferred or during headless testing.
  void _animateCameraMove(LatLng destLocation, double destZoom) {
    final bool isTestEnv = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    if (AppMotion.isReducedMotion(context) || isTestEnv) {
      try {
        _mapController.move(destLocation, destZoom);
      } catch (_) {}
      return;
    }

    try {
      final startCenter = _mapController.camera.center;
      final startZoom = _mapController.camera.zoom;
      final latTween = Tween<double>(
        begin: startCenter.latitude,
        end: destLocation.latitude,
      );
      final lngTween = Tween<double>(
        begin: startCenter.longitude,
        end: destLocation.longitude,
      );
      final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

      if (_cameraCurvedAnimation != null && _cameraListener != null) {
        _cameraCurvedAnimation!.removeListener(_cameraListener!);
      }
      _cameraAnimationController.stop();
      _cameraAnimationController.reset();

      final curved = CurvedAnimation(
        parent: _cameraAnimationController,
        curve: AppMotion.easeOut,
      );
      _cameraCurvedAnimation = curved;

      _cameraListener = () {
        if (!mounted) return;
        try {
          _mapController.move(
            LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
            zoomTween.evaluate(curved),
          );
        } catch (_) {}
      };

      curved.addListener(_cameraListener!);
      _cameraAnimationController.forward();
    } catch (_) {
      try {
        _mapController.move(destLocation, destZoom);
      } catch (_) {}
    }
  }

  void _focusOnTerritory(String territoryId) {
    _refreshTerritoryCache();
    final territories = _territoriesNotifier.value;
    Territory? target;
    for (final t in territories) {
      if (t.id == territoryId) {
        target = t;
        break;
      }
    }
    // Fallback: if not found by id, pick weakest territory
    if (target == null && territories.isNotEmpty) {
      target = territories.reduce(
        (a, b) =>
            a.computeCurrentStrength() < b.computeCurrentStrength() ? a : b,
      );
    }
    if (target != null && target.polygon.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      for (final p in target.polygon) {
        sumLat += p.latitude;
        sumLng += p.longitude;
      }
      final centroid = LatLng(
        sumLat / target.polygon.length,
        sumLng / target.polygon.length,
      );
      _animateCameraMove(centroid, 17.0);
    }
  }

  bool _shouldRefreshBBox(LatLng center) {
    final now = DateTime.now();
    if (_lastBBoxFetchAt == null || _lastBBoxCenter == null) {
      return true;
    }
    if (now.difference(_lastBBoxFetchAt!).inSeconds >= 90) {
      return true;
    }
    const distance = Distance();
    return distance.as(LengthUnit.Meter, _lastBBoxCenter!, center) >= 400.0;
  }

  Future<void> _syncNearbyTerritories(LatLng center) async {
    _lastBBoxFetchAt = DateTime.now();
    _lastBBoxCenter = center;
    try {
      const double delta = 0.025; // ~2.8 km viewport radius
      final remote = await ApiClient()
          .getTerritoriesInBBox(
            minLng: center.longitude - delta,
            minLat: center.latitude - delta,
            maxLng: center.longitude + delta,
            maxLat: center.latitude + delta,
          )
          .timeout(const Duration(seconds: 5));
      final merged = await TerritoryService().mergeRemoteTerritories(remote);
      if (merged > 0 && mounted) {
        _refreshTerritoryCache();
      }
    } catch (_) {
      // Offline or unauthenticated; retain local Hive territory cache silently.
    }
  }

  void _refreshTerritoryCache() {
    _territoriesNotifier.value = TerritoryService()
        .getCapturedTerritoryObjects();
  }

  void _onGpsStatusChanged() {
    if (!mounted) return;
    final status = LocationService().gpsStatusNotifier.value;
    final controller = _resolveController();
    if (controller.isRunActive &&
        (status == GpsStatus.permissionDenied ||
            status == GpsStatus.permissionDeniedForever ||
            status == GpsStatus.serviceDisabled)) {
      AppToast.show(
        context,
        'Location access interrupted. Active run coordinates preserved.',
        type: AppToastType.warning,
      );
    }
  }

  @override
  void dispose() {
    LocationService().gpsStatusNotifier.removeListener(_onGpsStatusChanged);
    if (_cameraCurvedAnimation != null && _cameraListener != null) {
      _cameraCurvedAnimation!.removeListener(_cameraListener!);
    }
    _cameraAnimationController.dispose();
    _crateSub?.cancel();
    _positionSub?.cancel();
    _territoryFocusSub?.cancel();
    _wsPresenceSub?.cancel();
    _wsRunnerLeftSub?.cancel();
    _wsAlertSub?.cancel();
    _hudHeightNotifier.dispose();
    _territoriesNotifier.dispose();
    _keyboardFocusNode.dispose();
    _localController?.dispose();
    super.dispose();
  }

  Future<void> _showGpsAlertDialog({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.br16,
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          title,
          style: AppText.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            isFullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          PrimaryButton(
            label: actionLabel,
            isFullWidth: false,
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startRunSequence(MapRunController controller) async {
    if (controller.isRunActive) return;

    if (!controller.isSimulated) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _showGpsAlertDialog(
          title: 'Location is off',
          message: 'Please turn on device location services to track your run and claim territories.',
          actionLabel: 'Open settings',
          onAction: () => Geolocator.openLocationSettings(),
        );
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (perm == LocationPermission.deniedForever) {
        _showGpsAlertDialog(
          title: 'Location permission needed',
          message: 'Territory Runner requires location access to map your runs. Please enable it in device settings.',
          actionLabel: 'Open settings',
          onAction: () => Geolocator.openAppSettings(),
        );
        return;
      } else if (perm == LocationPermission.denied) {
        _showGpsAlertDialog(
          title: 'Location permission needed',
          message: 'Location access was denied. Enable permission to start tracking your run.',
          actionLabel: 'Retry',
          onAction: () => _startRunSequence(controller),
        );
        return;
      }
    }

    final prefs = AppPreferences();
    if (!prefs.hasBodyProfile && !prefs.hasSkippedBodyDetails) {
      BodyDetailsSheet.show(
        context: context,
        isFirstRun: true,
        onSaved: () {
          if (mounted && !controller.isRunActive) {
            controller.startCountdown();
          }
        },
        onSkipped: () {
          if (mounted && !controller.isRunActive) {
            controller.startCountdown();
          }
        },
      );
    } else {
      controller.startCountdown();
    }
  }

  void _stopRun(MapRunController controller) {
    handleFinishRun(
      context: context,
      controller: controller,
      onTerritoriesUpdated: _refreshTerritoryCache,
    );
  }

  void _openToolsSheet(MapRunController controller, MapDemoRunner demoRunner) {
    MapToolsSheet.show(
      context: context,
      onOpenPacer: () => VirtualPacerSheet.show(
        context: context,
        locationService: LocationService(),
        onSimulateLoop: demoRunner.runAutomatedLoopDemo,
        onSimulateRivalCut: demoRunner.runRivalConflictDemo,
        onSimulateAnomaly: demoRunner.simulateSpeedAnomaly,
        onSimulateCoachDebrief: () {
          SummarySheet.show(
            context: context,
            distanceKm: 3.52,
            durationSeconds: 1085,
            territoriesClaimed: 1,
            areaSqMeters: 1840.0,
            elevationGainMeters: 42.0,
            profile: TerritoryService().getProfile(),
            coachService: LLMCoachService(),
            isSimulated: true,
          );
        },
        onSimulateDecayAndAttack: demoRunner.simulateDecayAndAttack,
        isRivalSimulating: controller.isRivalSimulating,
        onToggleRivalSimulation: () {
          if (controller.currentLocation != null) {
            controller.toggleRivalSimulation(controller.currentLocation!);
          }
        },
      ),
      onOpenGoals: () async {
        final recentRuns = RunLogService().isBoxOpen
            ? PacePredictionService.pastRunsFromLog(
                RunLogService().getAllRuns(),
              )
            : null;
        final goal = await RunGoalSheet.show(
          context,
          currentGoal: controller.activeGoal,
          profile: TerritoryService().getProfile(),
          recentRuns: recentRuns,
        );
        if (!mounted || controller.isDisposed) return;
        if (goal != null) {
          controller.setGoal(goal);
        }
      },
      onOpenRoutePlanner: () {
        ClaimPlannerSheet.show(
          context: context,
          currentLocation:
              controller.currentLocation ?? const LatLng(51.5074, -0.1278),
          routeService: RouteService(),
          onRouteGenerated: (route) => controller.setSuggestedRoute(route),
          onStartRun: (route) {
            controller.setSuggestedRoute(route);
            if (!controller.isRunActive) {
              _startRunSequence(controller);
            }
          },
        );
      },
      onToggleAmoled: () {
        BatterySaverService().setAmoledHudActive(true);
      },
      onOpenOfflineMaps: () => showOfflineMapsSheet(context),
      onTriggerSos: () =>
          showSosBeaconSheet(context, controller.currentLocation),
      onOpenGhostRunner: () {
        GhostRunnerPickerSheet.show(
          context: context,
          initialMode: controller.ghostMode,
          currentLocation: controller.currentLocation,
          activityType: controller.selectedActivity.id,
          onGhostSelected: (result) {
            controller.setGhostSelection(result);
          },
        );
      },
      onOpenIntervalWorkouts: () {
        IntervalWorkoutPickerSheet.show(
          context: context,
          currentPlan: controller.activeWorkoutPlan,
          onPlanSelected: (plan) {
            controller.setWorkoutPlan(plan);
          },
        );
      },
      onOpenSavedLoops: () {
        SavedLoopsSheet.show(
          context: context,
          onStartLoop: (loop) {
            controller.setActiveSavedLoop(loop);
            if (!controller.isRunActive) {
              _startRunSequence(controller);
            }
          },
        );
      },
      onOpenSocialHub: () => showSocialHubSheet(context),
      activePacerLabel: controller.activePaceTarget != null
          ? '${controller.activePaceTarget!.targetSecondsPerKm ~/ 60}:${(controller.activePaceTarget!.targetSecondsPerKm % 60).toString().padLeft(2, '0')}/km'
          : null,
      activeGoalLabel: controller.activeGoal.isActive
          ? controller.activeGoal.title
          : null,
      activeGhostLabel: controller.ghostMode != GhostMode.off
          ? controller.ghostMode.label
          : null,
      activeWorkoutLabel: controller.activeWorkoutPlan?.name,
      isAmoledActive: BatterySaverService().isAmoledHudActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MapRunController controller;
    MapRunController? watched;
    try {
      watched = context.watch<MapRunController>();
    } catch (_) {}
    controller = watched ?? (_localController ??= MapRunController());

    final pad = MediaQuery.paddingOf(context);
    final profile = TerritoryService().getProfile();
    final athleteName = profile.username.isNotEmpty
        ? profile.username
        : 'Runner';
    final demoRunner = MapDemoRunner(
      context: context,
      mapController: _mapController,
      runController: controller,
      territoryService: TerritoryService(),
      firebaseService: FirebaseService(),
      onHighlightTerritory: (_) => setState(() {}),
    );

    return PopScope(
      canPop: !controller.isRunActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showExitRunConfirmation(context);
        if (shouldExit && mounted) {
          _stopRun(controller);
        }
      },
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.keyW) {
              LocationService().moveSimulatedRunner(forwardMeters: 4.0);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.keyA) {
              LocationService().moveSimulatedRunner(turnDegrees: -15.0);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.keyD) {
              LocationService().moveSimulatedRunner(turnDegrees: 15.0);
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.bgDeep,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Interactive Fullscreen Map Viewport
              MapViewport(
                mapController: _mapController,
                controller: controller,
                territoriesNotifier: _territoriesNotifier,
              ),

              // 2. Minimal Athletic Top Bar
              Positioned(
                top: pad.top + 10,
                left: 16,
                right: 16,
                child: MapTopBar(
                  athleteName: athleteName,
                  satelliteAccuracyMeters: controller.satelliteAccuracyMeters,
                  isGpsSearching: controller.currentLocation == null,
                ),
              ),

              // Incursion Alert & Sector Guardian HUD
              Positioned(
                top: pad.top + 68,
                left: 16,
                right: 16,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SprintIncursionBanner(),
                    SizedBox(height: 4),
                    SectorGuardianChip(),
                  ],
                ),
              ),

              // 3. Ergonomic Floating Controls
              ValueListenableBuilder<bool>(
                valueListenable: AppPreferences().leftHandedModeNotifier,
                builder: (context, isLeftHanded, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _hudHeightNotifier,
                    builder: (context, hudHeight, _) {
                      final bottomOffset = pad.bottom + 12 + hudHeight + 12;
                      return MapFloatingControls(
                        isLeftHanded: isLeftHanded,
                        bottomOffset: bottomOffset,
                        isCameraLocked: controller.isCameraFollowLocked,
                        onOpenTools: () =>
                            _openToolsSheet(controller, demoRunner),
                        onOpenLayers: () => MapLayersSheet.show(
                          context: context,
                          onLocateNearestRival: () {
                            final rivals = controller.activeRivalRunners.values;
                            if (rivals.isEmpty) {
                              AppToast.show(
                                context,
                                'No nearby runners active right now.',
                              );
                              return;
                            }
                            final origin = controller.currentLocation;
                            var nearest = rivals.first;
                            if (origin != null) {
                              double bestDist = double.infinity;
                              for (final r in rivals) {
                                final d = const Distance().as(
                                  LengthUnit.Meter,
                                  origin,
                                  r.position,
                                );
                                if (d < bestDist) {
                                  bestDist = d;
                                  nearest = r;
                                }
                              }
                            }
                            controller.setCameraFollow(false);
                            _animateCameraMove(nearest.position, 16.5);
                          },
                        ),
                        onRecenter: () {
                          if (controller.currentLocation != null) {
                            _mapController.move(
                              controller.currentLocation!,
                              17.0,
                            );
                            controller.setCameraFollow(true);
                          }
                        },
                        onTriggerSos: () => showSosBeaconSheet(
                          context,
                          controller.currentLocation,
                        ),
                      );
                    },
                  );
                },
              ),

              // 4. Strava-Grade Live Metrics HUD
              Positioned(
                left: 16,
                right: 16,
                bottom: pad.bottom + 12,
                child: MapHudPanel(
                  controller: controller,
                  hudHeightNotifier: _hudHeightNotifier,
                  onToggleRun: () {
                    if (controller.isRunActive) {
                      controller.togglePauseResume();
                    } else {
                      _startRunSequence(controller);
                    }
                  },
                  onFinishRun: () => _stopRun(controller),
                ),
              ),

              // 5. Non-blocking Go Cue
              if (_showGoCue)
                Positioned.fill(
                  child: RunGoCue(
                    onDismissed: () {
                      if (mounted) setState(() => _showGoCue = false);
                    },
                  ),
                ),

              // 5b. Run Countdown Overlay
              if (controller.isCountingDown)
                Positioned.fill(
                  child: RunCountdownOverlay(
                    onComplete: () {
                      controller.completeCountdown();
                      setState(() => _showGoCue = true);
                    },
                    onCancel: controller.cancelCountdown,
                  ),
                ),

              // 6. AMOLED Pure Black Low-Power Screen Overlay
              ValueListenableBuilder<bool>(
                valueListenable:
                    BatterySaverService().isAmoledHudActiveNotifier,
                builder: (context, isAmoledActive, _) {
                  if (!isAmoledActive || !controller.isRunActive) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<RunTelemetry>(
                    valueListenable: controller.telemetryNotifier,
                    builder: (context, telemetry, _) {
                      return AmoledBatterySaverOverlay(
                        distanceKm: telemetry.distanceKm,
                        elapsedSeconds: telemetry.elapsedSeconds,
                        splitPace: telemetry.splitPace,
                        currentSpeedKmh: telemetry.currentSpeedKmh,
                        runGoal: telemetry.activeGoal ?? controller.activeGoal,
                        onWake: () =>
                            BatterySaverService().setAmoledHudActive(false),
                      );
                    },
                  );
                },
              ),

              // 7. Low Battery Endurance Prompt
              ValueListenableBuilder<bool>(
                valueListenable: controller.lowBatteryPromptNotifier,
                builder: (context, showPrompt, _) {
                  if (!showPrompt || !controller.isRunActive) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    top: MediaQuery.paddingOf(context).top + 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s14,
                        vertical: AppSpacing.s10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius: AppSpacing.br16,
                        border: Border.all(
                          color: AppColors.warning,
                          width: 1.5,
                        ),
                        boxShadow: AppElevation.floating,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.battery_alert_rounded,
                            color: AppColors.warning,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Battery below 15%',
                                  style: AppText.labelLarge.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Enable Endurance Saver to extend tracking?',
                                  style: AppText.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: controller.dismissLowBatteryPrompt,
                            child: Text(
                              'Dismiss',
                              style: AppText.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          PrimaryButton(
                            label: 'Enable',
                            isFullWidth: false,
                            onPressed: controller.enableEnduranceFromPrompt,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
