import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/map/controllers/map_run_controller.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/auto_pause_engine.dart';
import 'package:territory_runner/services/run_recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return '.';
  });

  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(geolocatorChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'isLocationServiceEnabled') return true;
    if (methodCall.method == 'checkPermission') return 3; // whileInUse
    return null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (ByteData? message) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();

    tempDir = Directory.systemTemp.createTempSync('hive_autopause_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(RunRecoveryService.boxName);
    await RunRecoveryService().init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Auto-Pause Start-Line Suppression & 2.5 km/h Threshold Tests', () {
    test('AutoPauseEngine defaults to 2.5 km/h ceiling and 3.0 km/h floor', () {
      expect(AutoPauseEngine.pauseSpeedCeilingKmh, equals(2.5));
      expect(AutoPauseEngine.resumeSpeedFloorKmh, equals(3.0));
      expect(AutoPauseEngine.pauseDelaySeconds, equals(3));
    });

    test('AutoPauseEngine suppresses auto-pause at start line while stationary', () {
      final engine = AutoPauseEngine();
      expect(engine.isAutoPaused, isFalse);
      expect(engine.hasInitialMovement, isFalse);

      // 20 consecutive seconds of 0.0 km/h at the starting line
      for (int i = 0; i < 20; i++) {
        final transition = engine.tick(0.0);
        expect(transition, equals(AutoPauseTransition.none));
        expect(engine.isAutoPaused, isFalse);
        expect(engine.consecutiveStationarySeconds, equals(0));
      }
    });

    test('AutoPauseEngine arms on crossing 2.5 km/h and pauses on subsequent stop', () {
      final engine = AutoPauseEngine();

      // Runner accelerates past 2.5 km/h
      expect(engine.tick(2.5), equals(AutoPauseTransition.none));
      expect(engine.hasInitialMovement, isTrue);

      // Active run continues at 8 km/h
      expect(engine.tick(8.0), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isFalse);

      // Runner stops (e.g. traffic signal): below 2.5 km/h
      expect(engine.tick(1.0), equals(AutoPauseTransition.none));
      expect(engine.consecutiveStationarySeconds, equals(1));
      expect(engine.tick(1.0), equals(AutoPauseTransition.none));
      expect(engine.consecutiveStationarySeconds, equals(2));
      expect(engine.tick(0.0), equals(AutoPauseTransition.paused));
      expect(engine.isAutoPaused, isTrue);

      // Speeds between 2.5 and 3.0 km/h remain paused (hysteresis)
      expect(engine.tick(2.8), equals(AutoPauseTransition.none));
      expect(engine.isAutoPaused, isTrue);

      // Resumes when crossing 3.0 km/h floor
      expect(engine.tick(3.0), equals(AutoPauseTransition.resumed));
      expect(engine.isAutoPaused, isFalse);
    });

    test('MapRunController startRun sets active run and does not pause during startup', () {
      final controller = MapRunController();
      controller.startRun();

      expect(controller.isRunActive, isTrue);
      expect(controller.isAutoPaused, isFalse);
      expect(controller.currentSpeedKmh, equals(0.0));

      // Simulate initial stationary position at start line
      final startPos = Position(
        latitude: 51.5074,
        longitude: -0.1278,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.5,
      );
      controller.processPosition(startPos);

      expect(controller.isAutoPaused, isFalse);
      expect(controller.isRunActive, isTrue);

      controller.stopRun();
    });

    test('MapRunController resumes auto-pause upon coordinate displacement', () {
      final engine = AutoPauseEngine(hasInitialMovement: true);
      // Force into paused state
      engine.tick(0.0);
      engine.tick(0.0);
      engine.tick(0.0);
      expect(engine.isAutoPaused, isTrue);

      final controller = MapRunController(autoPauseEngine: engine);
      controller.startRun();

      // Feed initial position
      final t0 = DateTime.now();
      controller.processPosition(Position(
        latitude: 51.5074,
        longitude: -0.1278,
        timestamp: t0,
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.5,
      ));

      // Simulate runner moving 15 meters in 2 seconds (speed ~ 27 km/h)
      final t1 = t0.add(const Duration(seconds: 2));
      controller.processPosition(Position(
        latitude: 51.50755,
        longitude: -0.1278,
        timestamp: t1,
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 7.5, // 27 km/h
        speedAccuracy: 0.5,
      ));

      expect(controller.isAutoPaused, isFalse);
      expect(controller.isRunActive, isTrue);

      controller.stopRun();
    });
  });
}
