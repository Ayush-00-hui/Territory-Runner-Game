import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/models/privacy_zone.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/export_service.dart';
import 'package:territory_runner/services/privacy_zone_service.dart';
import 'package:territory_runner/services/safety_service.dart';
import 'package:territory_runner/features/profile/widgets/privacy_zones_sheet.dart';
import 'package:territory_runner/features/map/widgets/sos_beacon_sheet.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: Privacy Zones, Data Export & Tactical Safety Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SafetyService().resetForTesting();
    });

    test(
      'PrivacyZoneService adds, filters and toggles exclusion zones',
      () async {
        final service = PrivacyZoneService();
        await service.loadZones();

        final homeZone = PrivacyZone(
          id: 'zone_home_1',
          name: 'Home Sanctuary',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 200.0,
          isEnabled: true,
          createdAt: DateTime.now(),
        );

        await service.addZone(homeZone);
        expect(service.zones.length, equals(1));
        expect(service.zones.first.name, equals('Home Sanctuary'));

        // Coordinate directly at home (0m distance)
        final atHome = const LatLng(37.7749, -122.4194);
        expect(service.isPointInPrivacyZone(atHome), isTrue);

        // Coordinate 500m away (outside 200m radius)
        final outside = const LatLng(37.7795, -122.4194);
        expect(service.isPointInPrivacyZone(outside), isFalse);

        // Filter GPS track: points inside zone are redacted
        final track = [
          const LatLng(37.7700, -122.4194), // outside
          const LatLng(37.7749, -122.4194), // inside home (must be removed)
          const LatLng(37.7800, -122.4194), // outside
        ];
        final filteredTrack = service.filterGpsTrack(track);
        expect(filteredTrack.length, equals(2));
        expect(filteredTrack.contains(atHome), isFalse);

        // Toggle zone off
        await service.toggleZone('zone_home_1', false);
        expect(service.isPointInPrivacyZone(atHome), isFalse);

        // Delete zone
        await service.deleteZone('zone_home_1');
        expect(service.zones.isEmpty, isTrue);
      },
    );

    test(
      'ExportService generates valid GPX 1.1 XML and redacts privacy points',
      () async {
        final privacyService = PrivacyZoneService();
        await privacyService.loadZones();

        // Configure a privacy zone
        await privacyService.addZone(
          PrivacyZone(
            id: 'pz_1',
            name: 'Home',
            latitude: 37.7749,
            longitude: -122.4194,
            radiusMeters: 200.0,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );

        final exportService = ExportService();
        final track = [
          const LatLng(37.7700, -122.4194),
          const LatLng(37.7749, -122.4194), // inside privacy zone
          const LatLng(37.7800, -122.4194),
        ];

        final gpx = exportService.generateGpx(
          runTitle: 'Golden Gate Sprint',
          coordinates: track,
          timestamps: [
            DateTime.utc(2026, 10, 17, 8, 0, 0),
            DateTime.utc(2026, 10, 17, 8, 5, 0),
            DateTime.utc(2026, 10, 17, 8, 10, 0),
          ],
          applyPrivacyRedaction: true,
        );

        // Verify GPX structure
        expect(gpx.contains('<?xml version="1.0" encoding="UTF-8"?>'), isTrue);
        expect(
          gpx.contains('<gpx version="1.1" creator="Territory Runner"'),
          isTrue,
        );
        expect(gpx.contains('<name>Golden Gate Sprint</name>'), isTrue);
        expect(gpx.contains('<type>running</type>'), isTrue);

        // Verify privacy point was redacted
        expect(gpx.contains('lat="37.7749000"'), isFalse);
        expect(gpx.contains('lat="37.7700000"'), isTrue);
        expect(gpx.contains('lat="37.7800000"'), isTrue);

        await privacyService.deleteZone('pz_1');
      },
    );

    test('ExportService generates valid GeoJSON FeatureCollection', () async {
      final exportService = ExportService();
      final territory = Territory(
        id: 'poly_test_001',
        ownerId: 'runner_1',
        polygon: const [
          LatLng(37.77, -122.41),
          LatLng(37.78, -122.41),
          LatLng(37.78, -122.42),
          LatLng(37.77, -122.42),
        ],
        capturedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        color: const Color(0xFF00E676),
        areaSqMeters: 45000.0,
      );

      final geoJsonStr = exportService.generateGeoJson(
        territories: [territory],
        runTrack: const [LatLng(37.77, -122.41), LatLng(37.78, -122.41)],
        applyPrivacyRedaction: false,
      );

      final decoded = jsonDecode(geoJsonStr) as Map<String, dynamic>;
      expect(decoded['type'], equals('FeatureCollection'));
      expect(decoded['generator'], equals('Territory Runner'));

      final features = decoded['features'] as List<dynamic>;
      expect(features.length, equals(2));

      // First feature: Territory polygon
      final polyFeature = features[0] as Map<String, dynamic>;
      expect(polyFeature['type'], equals('Feature'));
      expect(polyFeature['geometry']['type'], equals('Polygon'));
      expect(polyFeature['properties']['id'], equals('poly_test_001'));
      expect(polyFeature['properties']['area_sq_meters'], equals(45000.0));

      // Second feature: Run track line
      final lineFeature = features[1] as Map<String, dynamic>;
      expect(lineFeature['geometry']['type'], equals('LineString'));
      expect(lineFeature['properties']['type'], equals('run_track'));
    });

    test(
      'SafetyService persists emergency contact details and formats SMS URL',
      () async {
        final safetyService = SafetyService();
        await safetyService.saveSettings(
          name: 'Alex Rivera',
          phone: '+14155552671',
          message: 'EMERGENCY: Need assistance on running route.',
        );

        expect(safetyService.contactName, equals('Alex Rivera'));
        expect(safetyService.contactPhone, equals('+14155552671'));
        expect(safetyService.hasContactConfigured, isTrue);
      },
    );

    test(
      'SafetyService tracks siren state and handles stop gracefully',
      () async {
        final safetyService = SafetyService();
        expect(safetyService.isSirenPlaying, isFalse);
        await safetyService.stopTacticalSiren();
        expect(safetyService.isSirenPlaying, isFalse);
      },
    );

    testWidgets('PrivacyZonesSheet renders list and allows adding a zone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showPrivacyZonesSheet(context),
                    child: const Text('OPEN ZONES'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('OPEN ZONES'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy zones'), findsOneWidget);
      expect(find.text('Privacy exclusion radius'), findsOneWidget);
      expect(find.text('No privacy zones yet'), findsOneWidget);

      // Tap add icon
      await tester.tap(find.byIcon(Icons.add_circle_rounded));
      await tester.pumpAndSettle();

      expect(find.text('New privacy zone'), findsOneWidget);
      expect(find.text('Save zone'), findsOneWidget);

      // Save zone
      await tester.tap(find.text('Save zone'));
      await tester.pumpAndSettle();

      expect(find.text('Home Base'), findsOneWidget);
      expect(
        find.text('200m exclusion radius • Lat: 37.775, Lng: -122.419'),
        findsOneWidget,
      );
    });

    testWidgets(
      'SosBeaconSheet renders emergency dialer, contact SMS, and siren toggle',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showSosBeaconSheet(
                        context,
                        const LatLng(37.7749, -122.4194),
                      ),
                      child: const Text('OPEN SOS'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('OPEN SOS'));
        await tester.pumpAndSettle();

        expect(find.text('Tactical SOS beacon'), findsOneWidget);
        expect(find.text('GPS: 37.774900, -122.419400'), findsOneWidget);
        expect(find.text('Call emergency (911)'), findsOneWidget);
        expect(find.text('Set up emergency contact SMS'), findsOneWidget);
        expect(find.text('Share GPS'), findsOneWidget);
        expect(find.text('Siren alarm'), findsOneWidget);

        // Tap siren button to toggle
        await tester.tap(find.text('Siren alarm'));
        await tester.pumpAndSettle();

        expect(find.text('Stop siren'), findsOneWidget);
      },
    );

    test('PrivacyZoneService limits max zones to 5 and enforces StateError on 6th zone', () async {
      final service = PrivacyZoneService();
      await service.loadZones();

      expect(PrivacyZoneService.maxZones, equals(5));
      expect(PrivacyZoneService.minRadius, equals(50.0));
      expect(PrivacyZoneService.maxRadius, equals(2000.0));

      for (int i = 1; i <= 5; i++) {
        await service.addZone(
          PrivacyZone(
            id: 'zone_$i',
            name: 'Zone $i',
            latitude: 37.77 + (i * 0.01),
            longitude: -122.41,
            radiusMeters: 100.0,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
      }
      expect(service.zones.length, equals(5));

      // Attempting to add 6th zone should throw StateError
      expect(
        () => service.addZone(
          PrivacyZone(
            id: 'zone_6',
            name: 'Zone 6',
            latitude: 37.83,
            longitude: -122.41,
            radiusMeters: 100.0,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('PrivacyZoneService keeps territory polygons public in filterTerritories and GeoJSON export', () async {
      final service = PrivacyZoneService();
      await service.loadZones();

      // Configure a privacy zone
      await service.addZone(
        PrivacyZone(
          id: 'pz_public_check',
          name: 'Home Zone',
          latitude: 37.7749,
          longitude: -122.4194,
          radiusMeters: 500.0,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );

      final territoryInsideZone = Territory(
        id: 'poly_inside_zone',
        ownerId: 'runner_1',
        polygon: const [
          LatLng(37.7748, -122.4193),
          LatLng(37.7750, -122.4193),
          LatLng(37.7750, -122.4195),
          LatLng(37.7748, -122.4195),
        ],
        capturedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        color: const Color(0xFF00E676),
        areaSqMeters: 1200.0,
      );

      // filterTerritories must never redact or filter out territory polygons (they remain sovereign arena)
      final filteredTerritories = service.filterTerritories([
        territoryInsideZone,
      ]);
      expect(filteredTerritories.length, equals(1));
      expect(filteredTerritories.first.id, equals('poly_inside_zone'));

      // In GeoJSON export with privacy redaction enabled, territory polygon is preserved
      final exportService = ExportService();
      final geoJsonStr = exportService.generateGeoJson(
        territories: [territoryInsideZone],
        runTrack: const [
          LatLng(
            37.7749,
            -122.4194,
          ), // inside privacy zone -> should be redacted from run track
          LatLng(37.7850, -122.4194), // outside privacy zone -> kept
        ],
        applyPrivacyRedaction: true,
      );

      final decoded = jsonDecode(geoJsonStr) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>;

      // Territory feature is intact
      final polyFeature = features.firstWhere(
        (f) => f['geometry']['type'] == 'Polygon',
      );
      expect(polyFeature['properties']['id'], equals('poly_inside_zone'));

      // Run track feature has the inside point redacted
      final lineFeature = features.firstWhere(
        (f) => f['geometry']['type'] == 'LineString',
      );
      final lineCoords =
          lineFeature['geometry']['coordinates'] as List<dynamic>;
      expect(lineCoords.length, equals(1));
      expect(lineCoords[0][1], closeTo(37.7850, 0.0001));
    });

    test('PrivacyZoneService syncWithServer succeeds with ApiClient and handles offline gracefully', () async {
      final service = PrivacyZoneService();
      await service.loadZones();

      final zone1 = PrivacyZone(
        id: 'sync_z1',
        name: 'Safe Zone',
        latitude: 37.7749,
        longitude: -122.4194,
        radiusMeters: 150.0,
        isEnabled: true,
        createdAt: DateTime.now(),
      );
      await service.addZone(zone1);

      // Test successful sync with mock client
      bool putCalled = false;
      final successHttp = MockClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path == '/v1/me/privacy-zones') {
          putCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['privacy_zones'], isNotEmpty);
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final successApi = ApiClient(
        httpClient: successHttp,
        baseUrl: 'http://mock',
      );
      final syncResult = await service.syncWithServer(successApi);
      expect(syncResult, isTrue);
      expect(putCalled, isTrue);

      // Test offline failure handles gracefully without throwing
      final offlineHttp = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });
      final offlineApi = ApiClient(
        httpClient: offlineHttp,
        baseUrl: 'http://offline',
      );
      final offlineResult = await service.syncWithServer(offlineApi);
      expect(offlineResult, isFalse);
      // Local state is preserved
      expect(service.zones.length, equals(1));
      expect(service.zones.first.id, equals('sync_z1'));
    });

    test(
      'PrivacyZoneService fetchAndSyncFromServer loads zones from backend',
      () async {
        final service = PrivacyZoneService();
        await service.loadZones();

        final mockHttp = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/v1/me/privacy-zones') {
            return http.Response(
              jsonEncode({
                'privacy_zones': [
                  {
                    'id': 'remote_z1',
                    'name': 'Remote Haven',
                    'latitude': 37.7800,
                    'longitude': -122.4200,
                    'radius_meters': 300.0,
                    'is_enabled': true,
                    'created_at': '2026-10-17T12:00:00Z',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('Error', 500);
        });

        final mockApi = ApiClient(httpClient: mockHttp, baseUrl: 'http://mock');
        await service.fetchAndSyncFromServer(mockApi);

        expect(service.zones.length, equals(1));
        expect(service.zones.first.id, equals('remote_z1'));
        expect(service.zones.first.name, equals('Remote Haven'));
        expect(service.zones.first.radiusMeters, equals(300.0));
      },
    );
  });
}
