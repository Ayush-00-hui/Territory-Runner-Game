import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/territory.dart';
import '../../../models/ws_events.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';
import '../../gameplay/territory_service.dart';
import '../controllers/map_run_controller.dart';
import 'map_layers.dart';

/// Helper coordinator for map demo scenarios, territory defense, and rival conflict simulations.
class MapDemoRunner {
  final BuildContext context;
  final MapController mapController;
  final MapRunController runController;
  final TerritoryService territoryService;
  final FirebaseService firebaseService;
  final ValueChanged<String?> onHighlightTerritory;

  MapDemoRunner({
    required this.context,
    required this.mapController,
    required this.runController,
    required this.territoryService,
    required this.firebaseService,
    required this.onHighlightTerritory,
  });

  void runAutomatedLoopDemo() {
    if (!runController.isRunActive) {
      runController.startRun();
    }

    final center =
        runController.currentLocation ?? const LatLng(37.7749, -122.4194);
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
      if (currentStep >= waypoints.length) {
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

      runController.processPosition(pos);
      try {
        mapController.move(pt, mapController.camera.zoom);
      } catch (_) {}

      currentStep++;
    });
  }

  void runRivalConflictDemo() async {
    final center =
        runController.currentLocation ?? const LatLng(37.7749, -122.4194);

    await territoryService.spawnMockRivalTerritory(center);
    if (!context.mounted) return;

    AppToast.show(
      context,
      'Rival territory simulated. Executing loop...',
      icon: Icons.play_arrow_rounded,
      type: AppToastType.info,
      duration: const Duration(seconds: 2),
    );

    if (!runController.isRunActive) {
      runController.startRun();
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
      if (step >= sliceWaypoints.length) {
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

      runController.processPosition(pos);
      step++;
    });
  }

  void simulateSpeedAnomaly() {
    AppToast.show(
      context,
      'Speed alert: 48.5 km/h exceeds running limit (25 km/h).',
      icon: Icons.shield_rounded,
      type: AppToastType.error,
      duration: const Duration(seconds: 4),
    );
  }

  void defendWeakestTerritory() {
    final myId = firebaseService.currentUserId;
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
      onHighlightTerritory(weakest.id);

      if (weakest.polygon.isNotEmpty) {
        final centroid = MapLayers.computeCentroid(weakest.polygon);
        mapController.move(centroid, 17.0);
      }

      if (!runController.isRunActive) {
        runController.startCountdown();
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

  void simulateDecayAndAttack() async {
    final myId = firebaseService.currentUserId;
    final decayed = await territoryService.simulateDecay(
      myId,
      targetStrength: 20.0,
      daysAgo: 5,
    );
    if (decayed != null) {
      onHighlightTerritory(decayed.id);
      if (decayed.polygon.isNotEmpty) {
        final centroid = MapLayers.computeCentroid(decayed.polygon);
        mapController.move(centroid, 17.0);
      }
    }
    if (!context.mounted) return;

    AppToast.show(
      context,
      'Territory alert: rival captured 3,500 m² (20% strength remaining)',
      icon: Icons.warning_amber_rounded,
      type: AppToastType.error,
      actionLabel: 'Defend',
      onAction: defendWeakestTerritory,
      duration: const Duration(seconds: 8),
    );
  }

  void panToNearestRival() {
    final rivals = runController.activeRivalRunners;
    if (rivals.isEmpty) return;

    RunnerPresenceEvent? nearest;
    double minDistance = double.infinity;
    const distanceCalc = Distance();
    final myLoc = runController.currentLocation ?? const LatLng(51.5074, -0.1278);

    for (final rival in rivals.values) {
      final dist = distanceCalc.as(LengthUnit.Meter, myLoc, rival.position);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = rival;
      }
    }

    if (nearest != null) {
      AppMotion.lightTick();
      try {
        mapController.move(nearest.position, 17.5);
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

  void focusOnAttackedTerritory(String territoryId) {
    final territories = territoryService.getCapturedTerritoryObjects();
    final match = territories.where((t) => t.id == territoryId).firstOrNull;

    onHighlightTerritory(territoryId);

    if (match != null && match.polygon.isNotEmpty) {
      final centroid = MapLayers.computeCentroid(match.polygon);
      mapController.move(centroid, 17.0);
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
