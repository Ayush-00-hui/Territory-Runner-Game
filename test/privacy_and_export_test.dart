import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/models/privacy_zone.dart';
import 'package:territory_runner/models/territory.dart';
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

    test('PrivacyZoneService adds, filters and toggles exclusion zones', () async {
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
    });

    test('ExportService generates valid GPX 1.1 XML and redacts privacy points', () async {
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
      expect(gpx.contains('<gpx version="1.1" creator="Territory Runner"'), isTrue);
      expect(gpx.contains('<name>Golden Gate Sprint</name>'), isTrue);
      expect(gpx.contains('<type>running</type>'), isTrue);

      // Verify privacy point was redacted
      expect(gpx.contains('lat="37.7749000"'), isFalse);
      expect(gpx.contains('lat="37.7700000"'), isTrue);
      expect(gpx.contains('lat="37.7800000"'), isTrue);

      await privacyService.deleteZone('pz_1');
    });

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
        runTrack: const [
          LatLng(37.77, -122.41),
          LatLng(37.78, -122.41),
        ],
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

    test('SafetyService persists emergency contact details and formats SMS URL', () async {
      final safetyService = SafetyService();
      await safetyService.saveSettings(
        name: 'Alex Rivera',
        phone: '+14155552671',
        message: 'EMERGENCY: Need assistance on running route.',
      );

      expect(safetyService.contactName, equals('Alex Rivera'));
      expect(safetyService.contactPhone, equals('+14155552671'));
      expect(safetyService.hasContactConfigured, isTrue);
    });

    testWidgets('PrivacyZonesSheet renders list and allows adding a zone', (tester) async {
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

      expect(find.text('PRIVACY ZONES'), findsOneWidget);
      expect(find.text('GEO-MASKING EXCLUSION RADAR'), findsOneWidget);
      expect(find.text('NO PRIVACY ZONES DEFINED'), findsOneWidget);

      // Tap add icon
      await tester.tap(find.byIcon(Icons.add_circle_rounded));
      await tester.pumpAndSettle();

      expect(find.text('NEW PRIVACY ZONE'), findsOneWidget);
      expect(find.text('SAVE ZONE'), findsOneWidget);

      // Save zone
      await tester.tap(find.text('SAVE ZONE'));
      await tester.pumpAndSettle();

      expect(find.text('Home Base'), findsOneWidget);
      expect(find.text('200m exclusion radius • Lat: 37.775, Lng: -122.419'), findsOneWidget);
    });

    testWidgets('SosBeaconSheet renders emergency dialer, contact SMS, and siren toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showSosBeaconSheet(context, const LatLng(37.7749, -122.4194)),
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

      expect(find.text('TACTICAL SOS BEACON'), findsOneWidget);
      expect(find.text('GPS: 37.774900, -122.419400'), findsOneWidget);
      expect(find.text('CALL EMERGENCY (911)'), findsOneWidget);
      expect(find.text('SET UP EMERGENCY CONTACT SMS'), findsOneWidget);
      expect(find.text('SHARE GPS'), findsOneWidget);
      expect(find.text('SIREN ALARM'), findsOneWidget);

      // Tap siren button to toggle
      await tester.tap(find.text('SIREN ALARM'));
      await tester.pumpAndSettle();

      expect(find.text('STOP SIREN'), findsOneWidget);
    });
  });
}
