import 'dart:math' as math;

import '../models/user_body_profile.dart';

/// Result of a physiological calorie expenditure calculation.
class CalorieEstimateResult {
  /// Total gross energy expenditure including resting metabolic rate (kcal).
  final double grossKcal;

  /// Net energy expenditure above resting metabolic rate (kcal).
  final double netKcal;

  /// Instantaneous or segment energy expenditure rate (kcal / minute).
  final double burnRateKcalPerMin;

  /// Metabolic Equivalent of Task (1 MET = 3.5 mL O2 / kg / min ~= 1 kcal / kg / hr).
  final double mets;

  /// Comparison baseline using legacy flat-factor model (kcal).
  final double legacyFlatKcal;

  const CalorieEstimateResult({
    required this.grossKcal,
    required this.netKcal,
    required this.burnRateKcalPerMin,
    required this.mets,
    required this.legacyFlatKcal,
  });

  /// Rounded integer gross calories for UI display.
  int get displayCalories => grossKcal.round();
}

/// Offline physiological energy expenditure estimator based on published, peer-reviewed
/// biomechanical and metabolic equations.
///
/// Sources:
/// 1. ACSM (2021): Guidelines for Exercise Testing and Prescription, 11th Edition.
///    - Walking: VO2 (mL/kg/min) = 0.1 * s + 1.8 * s * G + 3.5
///    - Running: VO2 (mL/kg/min) = 0.2 * s + 0.9 * s * G + 3.5
///      where s = speed in m/min, G = fractional grade (e.g. +0.05).
/// 2. Minetti et al. (2002): Energy cost of walking and running at extreme uphill and downhill slopes.
///    - Cost of running Cr(i) = 155.4*i^5 - 30.4*i^4 - 32.8*i^3 + 43.7*i^2 + 19.5*i + 3.6 (J/kg/m).
///    - Used for steep inclines/declines (|grade| > 0.06).
/// 3. Mifflin, St Jeor et al. (1990): Resting Metabolic Rate (RMR).
///    - RMR (kcal/day) = 10*weight(kg) + 6.25*height(cm) - 5*age(yr) + s
///    - s = +5 (male), -161 (female), -78 (neutral average for "Prefer not to say").
/// 4. Martin et al. (1998): Road cycling power-balance model.
///    - P_total = P_rolling + P_gravity + P_drag, with human gross efficiency ~22%.
/// 5. Caloric oxygen equivalent: 4.86 kcal / Liter O2 (at respiratory exchange ratio RER = 0.85).
class PhysiologicalCalorieEngine {
  /// Caloric equivalent of 1 liter of oxygen consumed at RER = 0.85 (kcal / L).
  static const double kcalPerLiterO2 = 4.86;

  /// Resting oxygen consumption: 1 MET = 3.5 mL / kg / min.
  static const double restingVO2mLPerKgMin = 3.5;

  /// Joules per kilocalorie.
  static const double joulesPerKcal = 4184.0;

  /// Standard reference adult defaults if profile is omitted.
  static const double defaultWeightKg = 70.0;
  static const double defaultHeightCm = 170.0;
  static const int defaultAgeYears = 30;

  /// Computes daily resting metabolic rate (RMR) in kcal/day via Mifflin-St Jeor.
  static double computeRMRKcalPerDay({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required Gender gender,
  }) {
    // Offset s: male +5, female -161, neutral midpoint = (+5 - 161)/2 = -78
    final double s;
    switch (gender) {
      case Gender.male:
        s = 5.0;
        break;
      case Gender.female:
        s = -161.0;
        break;
      case Gender.preferNotToSay:
        s = -78.0;
        break;
    }

    final rmr = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * ageYears) + s;
    return math.max(800.0, rmr); // Physiological lower bound
  }

  /// Computes resting energy expenditure per minute in kcal/min.
  static double computeRMRKcalPerMin({
    double? weightKg,
    double? heightCm,
    int? ageYears,
    Gender? gender,
    UserBodyProfile? profile,
  }) {
    final w = weightKg ?? profile?.weightKg ?? defaultWeightKg;
    final h = heightCm ?? profile?.heightCm ?? defaultHeightCm;
    final a = ageYears ?? profile?.ageYears ?? defaultAgeYears;
    final g = gender ?? profile?.gender ?? Gender.preferNotToSay;

    final rmrDay = computeRMRKcalPerDay(
      weightKg: w,
      heightCm: h,
      ageYears: a,
      gender: g,
    );
    return rmrDay / 1440.0; // 1440 minutes in a day
  }

  /// Estimates energy expenditure for a discrete movement segment.
  ///
  /// [distanceKm]: Segment horizontal distance in kilometers.
  /// [durationSeconds]: Duration of active movement in seconds.
  /// [speedKmh]: Instantaneous or average speed in km/h.
  /// [grade]: Incline slope (e.g. 0.05 for +5%).
  /// [activityType]: 'running', 'walking', or 'cycling'.
  /// [profile]: User body profile (weight, height, age, gender).
  static CalorieEstimateResult estimateSegment({
    required double distanceKm,
    required double durationSeconds,
    required double speedKmh,
    double grade = 0.0,
    String activityType = 'running',
    UserBodyProfile? profile,
  }) {
    final weightKg = profile?.weightKg ?? defaultWeightKg;
    final durationMin = durationSeconds / 60.0;
    final clampedGrade = grade.clamp(-0.20, 0.20);

    // Compute legacy flat-factor baseline for comparison
    final legacyKcal = computeLegacyFlatCalories(
      distanceKm: distanceKm,
      weightKg: weightKg,
      activityType: activityType,
    );

    if (distanceKm <= 0 && durationSeconds <= 0) {
      return CalorieEstimateResult(
        grossKcal: 0.0,
        netKcal: 0.0,
        burnRateKcalPerMin: 0.0,
        mets: 1.0,
        legacyFlatKcal: legacyKcal,
      );
    }

    // When stationary (speed < 0.5 km/h): only resting metabolic rate applies
    final restingKcalPerMin = computeRMRKcalPerMin(profile: profile);
    if (speedKmh < 0.5 || distanceKm <= 0.001) {
      final gross = restingKcalPerMin * durationMin;
      return CalorieEstimateResult(
        grossKcal: gross,
        netKcal: 0.0,
        burnRateKcalPerMin: restingKcalPerMin,
        mets: 1.0,
        legacyFlatKcal: 0.0,
      );
    }

    final act = activityType.toLowerCase();
    if (act == 'cycling' ||
        act == 'cycle' ||
        act == 'bike' ||
        act == 'biking') {
      return _estimateCycling(
        distanceKm: distanceKm,
        durationMin: durationMin,
        speedKmh: speedKmh,
        grade: clampedGrade,
        weightKg: weightKg,
        restingKcalPerMin: restingKcalPerMin,
        legacyKcal: legacyKcal,
      );
    } else if (act == 'walking' || act == 'walk') {
      return _estimateWalking(
        distanceKm: distanceKm,
        durationMin: durationMin,
        speedKmh: speedKmh,
        grade: clampedGrade,
        weightKg: weightKg,
        restingKcalPerMin: restingKcalPerMin,
        legacyKcal: legacyKcal,
      );
    } else {
      // Running / Jogging
      return _estimateRunning(
        distanceKm: distanceKm,
        durationMin: durationMin,
        speedKmh: speedKmh,
        grade: clampedGrade,
        weightKg: weightKg,
        restingKcalPerMin: restingKcalPerMin,
        legacyKcal: legacyKcal,
      );
    }
  }

  /// Running energy expenditure model combining ACSM and Minetti gradient cost.
  static CalorieEstimateResult _estimateRunning({
    required double distanceKm,
    required double durationMin,
    required double speedKmh,
    required double grade,
    required double weightKg,
    required double restingKcalPerMin,
    required double legacyKcal,
  }) {
    // Speed in meters per minute
    final s = speedKmh * (1000.0 / 60.0);
    double grossVO2;

    if (grade.abs() <= 0.06) {
      // Standard ACSM Running Equation:
      // VO2 (mL/kg/min) = 0.2 * s + 0.9 * s * G + 3.5
      final verticalComponent = 0.9 * s * grade;
      grossVO2 = (0.2 * s) + verticalComponent + restingVO2mLPerKgMin;
    } else {
      // Minetti et al. (2002) Polynomial for steep slopes:
      // Cr(i) = 155.4*i^5 - 30.4*i^4 - 32.8*i^3 + 43.7*i^2 + 19.5*i + 3.6 (J/kg/m)
      final i = grade;
      final i2 = i * i;
      final i3 = i2 * i;
      final i4 = i3 * i;
      final i5 = i4 * i;
      final jPerKgM =
          (155.4 * i5) -
          (30.4 * i4) -
          (32.8 * i3) +
          (43.7 * i2) +
          (19.5 * i) +
          3.6;

      // Ensure minimum biomechanical energy cost of braking on steep downhill
      final clampedJPerKgM = math.max(1.8, jPerKgM);

      // Convert J/kg/m to mL O2 / kg / min:
      // (J/kg/m) * (s m/min) = J / kg / min
      // 1 L O2 = 4.86 kcal = 4.86 * 4184 J = 20,334.24 J
      // mL O2 = (J / 20.33424)
      final netVO2 = (clampedJPerKgM * s) / 20.33424;
      grossVO2 = netVO2 + restingVO2mLPerKgMin;
    }

    // Prevent VO2 from falling below resting metabolism
    grossVO2 = math.max(restingVO2mLPerKgMin, grossVO2);

    // Gross energy burn rate (kcal/min) = (VO2 / 1000) * weightKg * 4.86
    final grossBurnRate = (grossVO2 / 1000.0) * weightKg * kcalPerLiterO2;
    final netVO2 = math.max(0.0, grossVO2 - restingVO2mLPerKgMin);
    final netBurnRate = (netVO2 / 1000.0) * weightKg * kcalPerLiterO2;

    final grossKcal = grossBurnRate * durationMin;
    final netKcal = netBurnRate * durationMin;
    final mets = grossVO2 / restingVO2mLPerKgMin;

    return CalorieEstimateResult(
      grossKcal: grossKcal,
      netKcal: netKcal,
      burnRateKcalPerMin: grossBurnRate,
      mets: mets,
      legacyFlatKcal: legacyKcal,
    );
  }

  /// Walking energy expenditure model combining ACSM and Minetti gradient cost.
  static CalorieEstimateResult _estimateWalking({
    required double distanceKm,
    required double durationMin,
    required double speedKmh,
    required double grade,
    required double weightKg,
    required double restingKcalPerMin,
    required double legacyKcal,
  }) {
    final s = speedKmh * (1000.0 / 60.0);
    double grossVO2;

    if (grade.abs() <= 0.06) {
      // ACSM Walking Equation:
      // VO2 (mL/kg/min) = 0.1 * s + 1.8 * s * G + 3.5
      final verticalComponent = 1.8 * s * grade;
      grossVO2 = (0.1 * s) + verticalComponent + restingVO2mLPerKgMin;
    } else {
      // Minetti et al. (2002) Walking Polynomial:
      // Cw(i) = 280.5*i^5 - 58.7*i^4 - 76.8*i^3 + 51.9*i^2 + 19.6*i + 2.5 (J/kg/m)
      final i = grade;
      final i2 = i * i;
      final i3 = i2 * i;
      final i4 = i3 * i;
      final i5 = i4 * i;
      final jPerKgM =
          (280.5 * i5) -
          (58.7 * i4) -
          (76.8 * i3) +
          (51.9 * i2) +
          (19.6 * i) +
          2.5;
      final clampedJPerKgM = math.max(1.2, jPerKgM);

      final netVO2 = (clampedJPerKgM * s) / 20.33424;
      grossVO2 = netVO2 + restingVO2mLPerKgMin;
    }

    grossVO2 = math.max(restingVO2mLPerKgMin, grossVO2);

    final grossBurnRate = (grossVO2 / 1000.0) * weightKg * kcalPerLiterO2;
    final netVO2 = math.max(0.0, grossVO2 - restingVO2mLPerKgMin);
    final netBurnRate = (netVO2 / 1000.0) * weightKg * kcalPerLiterO2;

    final grossKcal = grossBurnRate * durationMin;
    final netKcal = netBurnRate * durationMin;
    final mets = grossVO2 / restingVO2mLPerKgMin;

    return CalorieEstimateResult(
      grossKcal: grossKcal,
      netKcal: netKcal,
      burnRateKcalPerMin: grossBurnRate,
      mets: mets,
      legacyFlatKcal: legacyKcal,
    );
  }

  /// Cycling power-balance energy expenditure model (Martin et al. 1998).
  static CalorieEstimateResult _estimateCycling({
    required double distanceKm,
    required double durationMin,
    required double speedKmh,
    required double grade,
    required double weightKg,
    required double restingKcalPerMin,
    required double legacyKcal,
  }) {
    const bikeWeightKg = 10.0;
    final totalMass = weightKg + bikeWeightKg;
    final v = speedKmh / 3.6; // Speed in m/s
    const g = 9.80665; // Gravity m/s^2

    // 1. Rolling resistance power: P_roll = Crr * m * g * v
    const crr = 0.005; // Standard road/hybrid tire on smooth asphalt
    final pRoll = crr * totalMass * g * v;

    // 2. Gravity climb power: P_grav = m * g * grade * v
    final pGrav = totalMass * g * grade * v;

    // 3. Aerodynamic drag power: P_drag = 0.5 * rho * CdA * v^3
    const rho = 1.225; // Air density kg/m^3 (sea level 15°C)
    const cdA = 0.38; // Upright athletic cycling position m^2
    final pDrag = 0.5 * rho * cdA * (v * v * v);

    // Total mechanical propulsion power at wheels
    final pPropulsion = pRoll + pGrav + pDrag;

    // Drivetrain efficiency: ~96%
    const etaDrivetrain = 0.96;
    final pPedal = math.max(0.0, pPropulsion / etaDrivetrain);

    // Human gross mechanical efficiency in cycling: ~22%
    const etaHuman = 0.22;
    final pMetabolic = (pPedal > 0) ? (pPedal / etaHuman) : 0.0;

    // Convert metabolic Watts (J/s) to kcal/min:
    // 1 Watt = 1 J/s = 60 J/min. In kcal/min: (60 / 4184) ~= 0.01434 kcal/min
    final netBurnRateKcalMin = pMetabolic * (60.0 / joulesPerKcal);
    final grossBurnRateKcalMin = netBurnRateKcalMin + restingKcalPerMin;

    final grossKcal = grossBurnRateKcalMin * durationMin;
    final netKcal = netBurnRateKcalMin * durationMin;
    final mets = math.max(1.0, grossBurnRateKcalMin / restingKcalPerMin);

    return CalorieEstimateResult(
      grossKcal: grossKcal,
      netKcal: netKcal,
      burnRateKcalPerMin: grossBurnRateKcalMin,
      mets: mets,
      legacyFlatKcal: legacyKcal,
    );
  }

  /// Legacy flat factor baseline calculation for comparative analysis.
  /// Factor: Running 1.036, Walking 0.73, Cycling 0.40 kcal/kg/km.
  static double computeLegacyFlatCalories({
    required double distanceKm,
    required double weightKg,
    required String activityType,
  }) {
    if (distanceKm <= 0) return 0.0;
    final double factor;
    switch (activityType.toLowerCase()) {
      case 'walking':
      case 'walk':
        factor = 0.73;
        break;
      case 'cycling':
      case 'cycle':
      case 'bike':
      case 'biking':
        factor = 0.40;
        break;
      case 'running':
      case 'run':
      default:
        factor = 1.036;
        break;
    }
    return distanceKm * weightKg * factor;
  }
}
