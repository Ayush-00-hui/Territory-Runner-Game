import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/sensors/motion_sensor_service.dart';

void main() {
  group('MotionSensorService Tests', () {
    late MotionSensorService service;

    setUp(() {
      service = MotionSensorService();
      service.startStreaming();
    });

    tearDown(() {
      service.stopStreaming();
    });

    test('Initial sensor values are defined and non-null', () {
      expect(service.ax, isNotNull);
      expect(service.ay, isNotNull);
      expect(service.az, isNotNull);
      expect(service.totalGForce, isNotNull);
      expect(service.history, isNotNull);
    });

    test('Manual telemetry ingestion updates waveform history', () {
      service.updateRawSensors(
        rawAx: 0.1,
        rawAy: 9.8,
        rawAz: 0.2,
        heading: 45.0,
        pitch: 12.0,
        roll: -5.0,
      );

      expect(service.ax, 0.1);
      expect(service.ay, 9.8);
      expect(service.az, 0.2);
      expect(service.alphaHeading, 45.0);
      expect(service.betaPitch, 12.0);
      expect(service.gammaRoll, -5.0);
      expect(service.history, isNotEmpty);
    });

    test('Kinematic Step Counter increments on peak spike > 1.2G', () {
      service.resetStepCount();
      expect(service.stepCount, 0);

      // Low baseline
      service.updateRawSensors(rawAx: 0, rawAy: 0, rawAz: 9.81, heading: 0, pitch: 0, roll: 0);
      
      // Ingest > 1.22G spike (e.g. 15 m/s² ~= 1.53G)
      service.updateRawSensors(rawAx: 0, rawAy: 15.0, rawAz: 0, heading: 0, pitch: 0, roll: 0);
      expect(service.stepCount, 1);
    });

    test('Freefall Detector triggers on low resultant G-force < 0.5G', () {
      service.updateRawSensors(rawAx: 0.5, rawAy: 0.5, rawAz: 0.5, heading: 0, pitch: 0, roll: 0);
      expect(service.isFreefall, isTrue);
      expect(service.totalGForce, lessThan(0.5));
    });

    test('Telemetry export to JSON contains required fields', () {
      service.updateRawSensors(rawAx: 0.1, rawAy: 0.2, rawAz: 9.8, heading: 10, pitch: 5, roll: 2);
      final jsonStr = service.exportTelemetryJson();
      expect(jsonStr, contains('timestamp'));
      expect(jsonStr, contains('totalGForce'));
      expect(jsonStr, contains('alphaHeading'));
    });

    test('Telemetry export to CSV contains valid header', () {
      service.updateRawSensors(rawAx: 0.1, rawAy: 0.2, rawAz: 9.8, heading: 10, pitch: 5, roll: 2);
      final csvStr = service.exportTelemetryCsv();
      expect(csvStr, startsWith('Timestamp,Ax(m/s2),Ay(m/s2),Az(m/s2)'));
    });
  });
}
