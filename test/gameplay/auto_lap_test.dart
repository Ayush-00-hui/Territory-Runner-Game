import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/lap_split.dart';
import 'package:territory_runner/models/pace_target.dart';
import 'package:territory_runner/services/auto_lap_service.dart';

void main() {
  group('AutoLapService & LapSplit Tests', () {
    test('LapSplit pace formatting and duration calculation', () {
      const split = LapSplit(
        lapNumber: 1,
        distanceMeters: 1000.0,
        durationSeconds: 300, // 5:00/km
        paceSecondsPerKm: 300.0,
        elevationGainMeters: 12.5,
      );

      expect(split.formattedPace, '5:00');
      expect(split.formattedDuration, '5:00');
      expect(split.paceSecondsPerKm, 300.0);
    });

    test('AutoLapService records splits precisely on 1000m thresholds', () {
      final service = AutoLapService(lapDistanceMeters: 1000.0);

      // Fix at 500m (half km) -> no split yet
      final split0 = service.processFix(
        totalDistanceMeters: 500.0,
        movingDurationSeconds: 150,
      );
      expect(split0, isNull);
      expect(service.completedLaps.isEmpty, isTrue);

      // Fix at 1005m -> triggers Lap 1 split
      final split1 = service.processFix(
        totalDistanceMeters: 1005.0,
        movingDurationSeconds: 300,
        totalElevationGainMeters: 10.0,
      );
      expect(split1, isNotNull);
      expect(service.completedLaps.length, 1);
      final lap1 = service.completedLaps.first;
      expect(lap1.lapNumber, 1);
      expect(lap1.distanceMeters, 1005.0);
      expect(lap1.durationSeconds, 300);

      // Fix at 2010m -> triggers Lap 2 split
      final split2 = service.processFix(
        totalDistanceMeters: 2010.0,
        movingDurationSeconds: 620,
        totalElevationGainMeters: 25.0,
      );
      expect(split2, isNotNull);
      expect(service.completedLaps.length, 2);
      final lap2 = service.completedLaps[1];
      expect(lap2.lapNumber, 2);
      expect(lap2.distanceMeters, 1005.0);
      expect(lap2.durationSeconds, 320); // 620 - 300
    });

    test('AutoLapService reset clears completed laps and state', () {
      final service = AutoLapService(lapDistanceMeters: 1000.0);

      service.processFix(
        totalDistanceMeters: 1000.0,
        movingDurationSeconds: 300,
      );
      expect(service.completedLaps.length, 1);

      service.reset();
      expect(service.completedLaps.isEmpty, isTrue);
    });
  });

  group('PaceTarget Band Evaluation Tests', () {
    test('PaceTarget evaluates onPace within ±15s tolerance', () {
      const target = PaceTarget(
        targetSecondsPerKm: 300, // 5:00/km
        toleranceSeconds: 15, // 285 to 315
      );

      expect(target.formattedTarget, '5:00 /km');

      // Running at 12.0 km/h -> 3600 / 12 = 300s -> exact onPace
      final evalOnPace = target.evaluateSpeed(12.0);
      expect(evalOnPace.status, PaceBandStatus.onPace);

      // Running at 14.0 km/h -> ~257s -> too fast by >15s
      final evalFast = target.evaluateSpeed(14.0);
      expect(evalFast.status, PaceBandStatus.tooFast);

      // Running at 9.0 km/h -> 400s -> too slow by >15s
      final evalSlow = target.evaluateSpeed(9.0);
      expect(evalSlow.status, PaceBandStatus.tooSlow);
    });
  });
}
