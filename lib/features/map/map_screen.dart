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
import '../../services/location_service.dart';
import '../../ui/ui.dart';
import '../gameplay/territory_service.dart';
import '../routing/route_service.dart';
import 'controllers/map_run_controller.dart';
import 'models/run_telemetry.dart';
import 'widgets/amoled_battery_saver_overlay.dart';
import 'widgets/claim_planner_sheet.dart';
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
import '../profile/widgets/offline_maps_sheet.dart';

export 'controllers/map_run_controller.dart';
export 'widgets/summary_sheet.dart';

/// Helper to estimate steps from distance based on exercise activity type.
int estimateSteps(
  double distanceKm, [
  ExerciseActivityType activity = ExerciseActivityType.running,
]) {
  if (activity == ExerciseActivityType.cycling) return 0;
  final meters = distanceKm * 1000.0;
  if (activity == ExerciseActivityType.walking) return (meters / 0.75).round();
  return (meters / 1.05).round();
}

/// Pure Layout Map Screen displaying real-time runner tracks and claimed sectors.
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

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final ValueNotifier<double> _hudHeightNotifier = ValueNotifier<double>(180.0);
  final ValueNotifier<List<Territory>> _territoriesNotifier =
      ValueNotifier<List<Territory>>([]);

  MapRunController? _localController;
  StreamSubscription<Position>? _positionSub;
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
              _mapController.move(snapshot.coordinates.last, 17.0);
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
        try {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            _mapController.camera.zoom,
          );
        } catch (_) {}
      }
    });
  }

  void _refreshTerritoryCache() {
    _territoriesNotifier.value =
        TerritoryService().getCapturedTerritoryObjects();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _hudHeightNotifier.dispose();
    _territoriesNotifier.dispose();
    _keyboardFocusNode.dispose();
    _localController?.dispose();
    super.dispose();
  }

  void _stopRun(MapRunController controller) {
    handleFinishRun(
      context: context,
      controller: controller,
      onTerritoriesUpdated: _refreshTerritoryCache,
    );
  }

  void _openToolsSheet(
    MapRunController controller,
    MapDemoRunner demoRunner,
  ) {
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
              controller.startCountdown();
            }
          },
        );
      },
      onToggleAmoled: () {
        AppMotion.mediumTick();
        BatterySaverService().setAmoledHudActive(true);
      },
      onOpenOfflineMaps: () => showOfflineMapsSheet(context),
      onTriggerSos: () => showSosBeaconSheet(
        context,
        controller.currentLocation,
      ),
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
    final athleteName =
        profile.username.isNotEmpty ? profile.username : 'Runner';
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
                        onOpenTools: () => _openToolsSheet(controller, demoRunner),
                        onOpenLayers: () => MapLayersSheet.show(context: context),
                        onRecenter: () {
                          if (controller.currentLocation != null) {
                            _mapController.move(controller.currentLocation!, 17.0);
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



              // 4. Strava-Grade Live Telemetry HUD
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
                      controller.startCountdown();
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
