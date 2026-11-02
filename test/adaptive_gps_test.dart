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

    test(
      'Tracking mode switches dynamically and updates currentTrackingMode',
      () async {
        await locationService.setTrackingMode(GpsTrackingMode.activeRun);
        expect(
          locationService.currentTrackingMode,
          equals(GpsTrackingMode.activeRun),
        );

        await locationService.setTrackingMode(GpsTrackingMode.paused);
        expect(
          locationService.currentTrackingMode,
          equals(GpsTrackingMode.paused),
        );

        await locationService.setTrackingMode(GpsTrackingMode.idle);
        expect(
          locationService.currentTrackingMode,
          equals(GpsTrackingMode.idle),
        );
      },
    );

    test(
      'isValidFix accepts initial coarse fix up to 50m when lastPos is null',
      () {
        final initialFix = Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          accuracy: 45.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 1.0,
        );

        // When lastPos is null, initial coarse lock <= 50m is accepted to eliminate lock delays
        expect(locationService.isValidFix(initialFix, null), isTrue);

        // Beyond 50m is still rejected
        final tooCoarse = Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          accuracy: 55.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 1.0,
        );
        expect(locationService.isValidFix(tooCoarse, null), isFalse);
      },
    );

    test(
      'isValidFix strictly enforces 30m threshold once position is established',
      () {
        final established = Position(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 3.0,
          speedAccuracy: 1.0,
        );

        final nextCoarse = Position(
          latitude: 37.7750,
          longitude: -122.4194,
          timestamp: DateTime.now().add(const Duration(seconds: 3)),
          accuracy: 35.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 3.0,
          speedAccuracy: 1.0,
        );

        // Once established, 35m fix is rejected to protect polygon enclosure
        expect(locationService.isValidFix(nextCoarse, established), isFalse);
      },
    );

    test(
      'warmUpLocation runs without exception in testing environment',
      () async {
        await expectLater(locationService.warmUpLocation(), completes);
      },
    );
  });
}
