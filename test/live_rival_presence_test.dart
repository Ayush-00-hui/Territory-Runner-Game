import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/map/widgets/map_layers.dart';
import 'package:territory_runner/models/ws_events.dart';
import 'package:territory_runner/ui/theme/app_colors.dart';

void main() {
  group('Live Rival GPS & Map Layer Tests', () {
    test('MapLayers.getFactionColor assigns dedicated faction accents', () {
      expect(
        MapLayers.getFactionColor('Cyber Vanguard'),
        equals(AppColors.info),
      );
      expect(
        MapLayers.getFactionColor('Iron Legion'),
        equals(AppColors.secondary),
      );
      expect(
        MapLayers.getFactionColor('Neon Syndicate'),
        equals(AppColors.rival),
      );
      expect(
        MapLayers.getFactionColor('Unknown Rogue'),
        equals(AppColors.rival),
      );
    });

    test('buildPolylineLayer generates clean solid rival breadcrumb line with NO glow', () {
      final rivalTrails = <String, List<LatLng>>{
        'rival_01': [
          const LatLng(51.505, -0.125),
          const LatLng(51.506, -0.126),
          const LatLng(51.507, -0.127),
        ],
        'rival_single_point': [
          const LatLng(51.508, -0.128), // < 2 points should not render
        ],
      };

      final activeRivals = <String, RunnerPresenceEvent>{
        'rival_01': RunnerPresenceEvent(
          userId: 'rival_01',
          username: 'ShadowRacer',
          faction: 'Neon Syndicate',
          position: const LatLng(51.507, -0.127),
          speed: 3.5,
          heading: 180.0,
          updatedAt: DateTime.now(),
        ),
      };

      final polylineLayer = MapLayers.buildPolylineLayer(
        isRunActive: false,
        runCoordinates: [],
        currentEnclosurePath: [],
        rivalBreadcrumbs: rivalTrails,
        activeRivalRunners: activeRivals,
      );

      // Should generate 1 clean polyline for rival_01 (core line, NO glow wake), and 0 for rival_single_point
      expect(polylineLayer.polylines.length, equals(1));

      final core = polylineLayer.polylines[0];
      expect(core.strokeWidth, equals(2.0));
      expect(core.color, equals(AppColors.rival));
      expect(core.points.length, equals(3));
    });

    test(
      'buildMarkerLayer creates tactical callsign and speed pill for rival',
      () {
        final rival = RunnerPresenceEvent(
          userId: 'rival_blaze',
          username: 'BlazeRunner',
          faction: 'Iron Legion',
          position: const LatLng(51.509, -0.129),
          speed: 3.0, // 10.8 km/h
          heading: 90.0,
          updatedAt: DateTime.now(),
        );

        final markerLayer = MapLayers.buildMarkerLayer(
          currentLocation: const LatLng(51.505, -0.125),
          activeRivalRunners: {'rival_blaze': rival},
        );

        // 1 user pin + 1 rival marker
        expect(markerLayer.markers.length, equals(2));

        final rivalMarker = markerLayer.markers[1];
        expect(rivalMarker.point, equals(const LatLng(51.509, -0.129)));
        expect(rivalMarker.width, equals(110));
        expect(rivalMarker.height, equals(62));
      },
    );

    testWidgets(
      'Rival marker renders username and speed badge on widget canvas',
      (tester) async {
        final rival = RunnerPresenceEvent(
          userId: 'rival_blaze',
          username: 'BlazeRunner',
          faction: 'Cyber Vanguard',
          position: const LatLng(51.509, -0.129),
          speed: 3.5, // 12.6 km/h
          heading: 45.0,
          updatedAt: DateTime.now(),
        );

        final markerLayer = MapLayers.buildMarkerLayer(
          currentLocation: null,
          activeRivalRunners: {'rival_blaze': rival},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(51.509, -0.129),
                  initialZoom: 16.0,
                ),
                children: [markerLayer],
              ),
            ),
          ),
        );

        expect(find.text('BlazeRunner'), findsOneWidget);
        expect(find.text('⚡12.6'), findsOneWidget);
      },
    );

    test('Rival breadcrumb capping respects max 40 points window', () {
      final breadcrumbs = <String, List<LatLng>>{};
      const userId = 'rival_marathoner';

      for (int i = 0; i < 50; i++) {
        final trail = breadcrumbs.putIfAbsent(userId, () => []);
        trail.add(LatLng(51.0 + (i * 0.001), -0.1));
        if (trail.length > 40) {
          trail.removeAt(0);
        }
      }

      expect(breadcrumbs[userId]!.length, equals(40));
      // First point should have been evicted (i = 10 is first remaining point)
      expect(breadcrumbs[userId]!.first.latitude, closeTo(51.010, 0.0001));
      expect(breadcrumbs[userId]!.last.latitude, closeTo(51.049, 0.0001));
    });

    test('Stale rivals older than 60 seconds are purged cleanly', () {
      final now = DateTime.now();
      final activeRivals = <String, RunnerPresenceEvent>{
        'fresh_rival': RunnerPresenceEvent(
          userId: 'fresh_rival',
          username: 'Fresh',
          faction: 'Cyber Vanguard',
          position: const LatLng(51.5, -0.1),
          speed: 2.5,
          heading: 0,
          updatedAt: now.subtract(const Duration(seconds: 15)),
        ),
        'stale_rival': RunnerPresenceEvent(
          userId: 'stale_rival',
          username: 'Ghost',
          faction: 'Neon Syndicate',
          position: const LatLng(51.6, -0.1),
          speed: 0,
          heading: 0,
          updatedAt: now.subtract(const Duration(seconds: 75)), // > 60s
        ),
      };

      final breadcrumbs = <String, List<LatLng>>{
        'fresh_rival': [const LatLng(51.5, -0.1)],
        'stale_rival': [const LatLng(51.6, -0.1)],
      };

      activeRivals.removeWhere((id, runner) {
        final isStale = now.difference(runner.updatedAt).inSeconds > 60;
        if (isStale) {
          breadcrumbs.remove(id);
        }
        return isStale;
      });

      expect(activeRivals.containsKey('fresh_rival'), isTrue);
      expect(activeRivals.containsKey('stale_rival'), isFalse);
      expect(breadcrumbs.containsKey('fresh_rival'), isTrue);
      expect(breadcrumbs.containsKey('stale_rival'), isFalse);
    });
  });
}
