import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/user_body_profile.dart';
import 'package:territory_runner/services/calorie_engine_service.dart';

void main() {
  group('PhysiologicalCalorieEngine Reference Cases (Hand Arithmetic)', () {
    test('Case 1: ACSM Level Running (70 kg, 10 km/h, 0% grade, 30 min = 5 km)', () {
      // Hand Arithmetic:
      // s = 10 km/h * (1000 / 60) = 166.667 m/min
      // VO2 = 0.2 * 166.667 + 0.9 * 166.667 * 0.0 + 3.5 = 33.333 + 3.5 = 36.833 mL/kg/min
      // Burn rate = (36.833 / 1000) * 70.0 kg * 4.86 kcal/L = 12.5307 kcal/min
      // Gross kcal (30 min) = 12.5307 * 30.0 = 375.92 kcal (~376 kcal)
      // Net VO2 = 33.333 mL/kg/min => Net burn rate = 11.340 kcal/min => Net kcal = 340.2 kcal
      // METs = 36.833 / 3.5 = 10.52
      final result = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 1800.0, // 30 minutes
        speedKmh: 10.0,
        grade: 0.0,
        activityType: 'running',
        profile: UserBodyProfile.referenceAdult(weightKg: 70.0),
      );

      expect(result.grossKcal, closeTo(375.92, 0.5));
      expect(result.netKcal, closeTo(340.20, 0.5));
      expect(result.burnRateKcalPerMin, closeTo(12.53, 0.05));
      expect(result.mets, closeTo(10.52, 0.1));
      expect(result.displayCalories, equals(376));
      expect(result.legacyFlatKcal, closeTo(362.6, 0.1));
    });

    test(
      'Case 2: ACSM Uphill Running (70 kg, 10 km/h, +5% grade, 30 min = 5 km)',
      () {
        // Hand Arithmetic:
        // s = 166.667 m/min, G = 0.05
        // Horizontal VO2 = 0.2 * 166.667 = 33.333 mL/kg/min
        // Vertical VO2 = 0.9 * 166.667 * 0.05 = 7.500 mL/kg/min
        // Gross VO2 = 33.333 + 7.500 + 3.5 = 44.333 mL/kg/min
        // Burn rate = (44.333 / 1000) * 70.0 * 4.86 = 15.0822 kcal/min
        // Gross kcal (30 min) = 15.0822 * 30.0 = 452.47 kcal (~452 kcal)
        final result = PhysiologicalCalorieEngine.estimateSegment(
          distanceKm: 5.0,
          durationSeconds: 1800.0,
          speedKmh: 10.0,
          grade: 0.05, // +5% grade
          activityType: 'running',
          profile: UserBodyProfile.referenceAdult(weightKg: 70.0),
        );

        expect(result.grossKcal, closeTo(452.47, 0.5));
        expect(result.burnRateKcalPerMin, closeTo(15.08, 0.05));
        expect(result.displayCalories, equals(452));
        // Uphill at +5% burns ~20.3% more than flat running (452 vs 376 kcal)
        expect(result.grossKcal, greaterThan(375.92));
      },
    );

    test('Case 3: Minetti Steep Uphill Running (70 kg, 10 km/h, +10% grade, 30 min)', () {
      // Hand Arithmetic via Minetti et al. (2002):
      // i = 0.10 => Cr(0.10) = 5.9527 J/kg/m
      // Net VO2 = (5.9527 * 166.667) / 20.33424 = 48.79 mL/kg/min
      // Gross VO2 = 48.79 + 3.5 = 52.29 mL/kg/min
      // Burn rate = (52.29 / 1000) * 70.0 * 4.86 = 17.789 kcal/min
      // Gross kcal = 17.789 * 30.0 = 533.68 kcal (~534 kcal)
      final result = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 1800.0,
        speedKmh: 10.0,
        grade: 0.10, // +10% grade (> 0.06 invokes Minetti polynomial)
        activityType: 'running',
        profile: UserBodyProfile.referenceAdult(weightKg: 70.0),
      );

      expect(result.grossKcal, closeTo(533.68, 1.5));
      expect(result.burnRateKcalPerMin, closeTo(17.79, 0.1));
      expect(result.displayCalories, equals(534));
    });

    test('Case 4: ACSM Walking (70 kg, 5 km/h, 0% grade, 60 min = 5 km)', () {
      // Hand Arithmetic:
      // s = 5 km/h * (1000 / 60) = 83.333 m/min
      // VO2 = 0.1 * 83.333 + 0 + 3.5 = 11.833 mL/kg/min
      // Burn rate = (11.833 / 1000) * 70.0 * 4.86 = 4.0257 kcal/min
      // Gross kcal = 4.0257 * 60.0 = 241.54 kcal (~242 kcal)
      final result = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 3600.0, // 60 minutes
        speedKmh: 5.0,
        grade: 0.0,
        activityType: 'walking',
        profile: UserBodyProfile.referenceAdult(weightKg: 70.0),
      );

      expect(result.grossKcal, closeTo(241.54, 0.5));
      expect(result.burnRateKcalPerMin, closeTo(4.03, 0.05));
      expect(result.displayCalories, equals(242));
    });

    test('Case 5: Mifflin-St Jeor Resting Energy Expenditure (Male, Female, Neutral)', () {
      // 70 kg, 170 cm, 30 years old
      // Base: 10*(70) + 6.25*(170) - 5*(30) = 700 + 1062.5 - 150 = 1612.5 kcal/day
      // Male (s = +5): 1612.5 + 5 = 1617.5 kcal/day (1.123 kcal/min)
      final maleRmr = PhysiologicalCalorieEngine.computeRMRKcalPerDay(
        weightKg: 70.0,
        heightCm: 170.0,
        ageYears: 30,
        gender: Gender.male,
      );
      expect(maleRmr, equals(1617.5));

      // Female (s = -161): 1612.5 - 161 = 1451.5 kcal/day (1.008 kcal/min)
      final femaleRmr = PhysiologicalCalorieEngine.computeRMRKcalPerDay(
        weightKg: 70.0,
        heightCm: 170.0,
        ageYears: 30,
        gender: Gender.female,
      );
      expect(femaleRmr, equals(1451.5));

      // Neutral / Prefer not to say (s = -78 midpoint): 1612.5 - 78 = 1534.5 kcal/day (1.066 kcal/min)
      final neutralRmr = PhysiologicalCalorieEngine.computeRMRKcalPerDay(
        weightKg: 70.0,
        heightCm: 170.0,
        ageYears: 30,
        gender: Gender.preferNotToSay,
      );
      expect(neutralRmr, equals(1534.5));
      expect(neutralRmr, equals((maleRmr + femaleRmr) / 2.0));
    });

    test('Case 6: Cycling Power-Balance (70 kg rider + 10 kg bike, 20 km/h, 60 min = 20 km)', () {
      // Hand Arithmetic:
      // m_tot = 80 kg, v = 5.556 m/s
      // P_roll = 0.005 * 80 * 9.80665 * 5.556 = 21.79 W
      // P_drag = 0.5 * 1.225 * 0.38 * (5.556)^3 = 39.91 W
      // P_pedal = (21.79 + 39.91) / 0.96 = 64.27 W
      // P_metabolic = 64.27 / 0.22 = 292.14 W
      // Net burn rate = 292.14 * (60 / 4184) = 4.189 kcal/min
      // Gross burn rate = 4.189 + 1.066 (RMR) = 5.255 kcal/min
      // Gross kcal (60 min) = 5.255 * 60 = 315.3 kcal (~315 kcal)
      final result = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 20.0,
        durationSeconds: 3600.0,
        speedKmh: 20.0,
        grade: 0.0,
        activityType: 'cycling',
        profile: UserBodyProfile.referenceAdult(weightKg: 70.0),
      );

      expect(result.grossKcal, closeTo(315.3, 2.0));
      expect(result.burnRateKcalPerMin, closeTo(5.25, 0.1));
      expect(result.displayCalories, equals(315));
    });
  });

  group('PhysiologicalCalorieEngine Monotonicity Guarantees', () {
    test('Heavier runner burns strictly more calories at identical speed and grade', () {
      final light = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 1800.0,
        speedKmh: 10.0,
        grade: 0.0,
        profile: UserBodyProfile.referenceAdult(weightKg: 60.0),
      );
      final heavy = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 1800.0,
        speedKmh: 10.0,
        grade: 0.0,
        profile: UserBodyProfile.referenceAdult(weightKg: 90.0),
      );

      expect(heavy.grossKcal, greaterThan(light.grossKcal));
      expect(heavy.burnRateKcalPerMin, greaterThan(light.burnRateKcalPerMin));
      // Proportional mass scaling: 90 kg / 60 kg = 1.5x
      expect(heavy.netKcal / light.netKcal, closeTo(1.5, 0.01));
    });

    test('Faster running burns strictly more calories per minute', () {
      final slow = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 4.5,
        durationSeconds: 1800.0,
        speedKmh: 9.0,
        grade: 0.0,
      );
      final fast = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 6.0,
        durationSeconds: 1800.0,
        speedKmh: 12.0,
        grade: 0.0,
      );

      expect(fast.burnRateKcalPerMin, greaterThan(slow.burnRateKcalPerMin));
      expect(fast.grossKcal, greaterThan(slow.grossKcal));
    });

    test(
      'Uphill terrain burns strictly more calories than flat or downhill',
      () {
        final downhill = PhysiologicalCalorieEngine.estimateSegment(
          distanceKm: 5.0,
          durationSeconds: 1800.0,
          speedKmh: 10.0,
          grade: -0.04, // -4% descent
        );
        final flat = PhysiologicalCalorieEngine.estimateSegment(
          distanceKm: 5.0,
          durationSeconds: 1800.0,
          speedKmh: 10.0,
          grade: 0.0,
        );
        final uphill = PhysiologicalCalorieEngine.estimateSegment(
          distanceKm: 5.0,
          durationSeconds: 1800.0,
          speedKmh: 10.0,
          grade: 0.05, // +5% ascent
        );

        expect(uphill.grossKcal, greaterThan(flat.grossKcal));
        expect(flat.grossKcal, greaterThan(downhill.grossKcal));
      },
    );

    test('Downhill energy cost is never negative and bounded by eccentric braking minimum', () {
      // Steepest descent allowed by sensing clamp (-20% grade)
      final extremeDownhill = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 5.0,
        durationSeconds: 1800.0,
        speedKmh: 10.0,
        grade: -0.20,
      );

      // Must be strictly positive
      expect(extremeDownhill.grossKcal, greaterThan(0.0));
      expect(extremeDownhill.burnRateKcalPerMin, greaterThan(0.0));
      // Even in free fall or steep descent, gross energy cannot be lower than resting metabolism
      final rmr = PhysiologicalCalorieEngine.computeRMRKcalPerMin();
      expect(extremeDownhill.burnRateKcalPerMin, greaterThanOrEqualTo(rmr));
    });

    test('Stationary / Paused time burns resting metabolism with zero net locomotor cost', () {
      final paused = PhysiologicalCalorieEngine.estimateSegment(
        distanceKm: 0.0,
        durationSeconds: 300.0, // 5 minutes stopped at red light
        speedKmh: 0.0,
      );

      expect(paused.netKcal, equals(0.0));
      expect(paused.grossKcal, greaterThan(0.0));
      // 5 minutes * ~1.066 kcal/min = ~5.33 kcal
      expect(paused.grossKcal, closeTo(5.33, 0.2));
      expect(paused.mets, equals(1.0));
    });
  });
}
