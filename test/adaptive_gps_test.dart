import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:territory_runner/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adaptive GPS & LocationService Phase 3 Tests', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
    });

    tearDown(() {
      locationService.stopTracking();
    });

    test('Initial tracking mode is idle to conserve battery', () {
      expect(locationService.currentTrackingMode, equals(GpsTrackingMode.idle));
    });

    test('createLocationSettings creates low-power settings for GpsTrackingMode.idle', () {
      final settings = locationService.createLocationSettings(
        mode: GpsTrackingMode.idle,
      );

      expect(settings.accuracy, equals(LocationAccuracy.medium));
      expect(settings.distanceFilter, equals(15));
    });

    test('createLocationSettings creates high-precision settings for GpsTrackingMode.activeRun', () {
      final settings = locationService.createLocationSettings(
        mode: GpsTrackingMode.activeRun,
        notificationTitle: 'Territory Runner - Run Active',
        notificationText: 'Tracking your running route in the background...',
      );

      expect(settings.accuracy, equals(LocationAccuracy.bestForNavigation));
      expect(settings.distanceFilter, equals(2));
    });

    test('createLocationSettings creates duty-cycled settings when battery saver is active', () {
      final settings = locationService.createLocationSettings(
        mode: GpsTrackingMode.activeRun,
        isBatterySaverActive: true,
      );

      expect(settings.accuracy, equals(LocationAccuracy.high));
      expect(settings.distanceFilter, equals(8));
    });

    test('createLocationSettings creates throttled battery-saving settings for GpsTrackingMode.paused', () {
      final settings = locationService.createLocationSettings(
        mode: GpsTrackingMode.paused,
        notificationTitle: 'Territory Runner - Paused',
        notificationText: 'Run paused — GPS throttled to conserve battery',
      );

      expect(settings.accuracy, equals(LocationAccuracy.medium));
      expect(settings.distanceFilter, equals(10));
    });

    test('Tracking mode switches dynamically and updates currentTrackingMode', () async {
      await locationService.setTrackingMode(GpsTrackingMode.activeRun);
      expect(locationService.currentTrackingMode, equals(GpsTrackingMode.activeRun));

      await locationService.setTrackingMode(GpsTrackingMode.paused);
      expect(locationService.currentTrackingMode, equals(GpsTrackingMode.paused));

      await locationService.setTrackingMode(GpsTrackingMode.idle);
      expect(locationService.currentTrackingMode, equals(GpsTrackingMode.idle));
    });
  });
}
