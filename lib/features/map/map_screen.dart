import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/activity_type.dart';
import '../../models/territory.dart';
import '../../services/app_preferences.dart';
import '../../services/battery_saver_service.dart';
import '../../services/firebase_service.dart';
import '../../services/ghost_runner_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../ui/ui.dart';
import '../gameplay/territory_service.dart';
import '../routing/route_service.dart';
import 'controllers/map_run_controller.dart';
import 'models/run_telemetry.dart';
import 'widgets/amoled_battery_saver_overlay.dart';
import 'widgets/claim_planner_sheet.dart';
import 'widgets/ghost_runner_picker_sheet.dart';
import 'widgets/interval_workout_picker_sheet.dart';
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
import 'widgets/sos_beacon_sheet.dart';
import '../profile/widgets/body_details_sheet.dart';
import '../profile/widgets/offline_maps_sheet.dart';

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

    _positionSub = LocationService().locationStream.listen((pos) {
      if (!mounted) return;
      controller.processPosition(pos);
      if (controller.isCameraFollowLocked) {
        final target =
            controller.currentLocation ?? LatLng(pos.latitude, pos.longitude);
        _animateCameraMove(target, _mapController.camera.zoom);
      }
    });

    LocationService().warmUpLocation();

    _territoryFocusSub = NotificationService().onAttackedTerritoryTapped.listen(
      (territoryId) {
        if (!mounted) return;
        _focusOnTerritory(territoryId);
      },
    );
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

  void _refreshTerritoryCache() {
    _territoriesNotifier.value = TerritoryService()
        .getCapturedTerritoryObjects();
  }

  @override
  void dispose() {
    if (_cameraCurvedAnimation != null && _cameraListener != null) {
      _cameraCurvedAnimation!.removeListener(_cameraListener!);
    }
    _cameraAnimationController.dispose();
    _positionSub?.cancel();
    _territoryFocusSub?.cancel();
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
        onSimulateCoachDebrief: () {},
        onSimulateDecayAndAttack: demoRunner.simulateDecayAndAttack,
        isRivalSimulating: controller.isRivalSimulating,
        onToggleRivalSimulation: () {
          if (controller.currentLocation != null) {
            controller.toggleRivalSimulation(controller.currentLocation!);
          }
        },
      ),
      onOpenGoals: () async {
        final goal = await RunGoalSheet.show(
          context,
          currentGoal: controller.activeGoal,
        );
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
      activeGhostLabel: controller.ghostMode != GhostMode.off
          ? controller.ghostMode.label
          : null,
      activeWorkoutLabel: controller.activeWorkoutPlan?.name,
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
                        onOpenLayers: () =>
                            MapLayersSheet.show(context: context),
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
                      _stopRun(controller);
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
            ],
          ),
        ),
      ),
    );
  }
}
