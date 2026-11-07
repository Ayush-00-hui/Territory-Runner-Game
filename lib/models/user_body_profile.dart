enum Gender {
  female,
  male,
  preferNotToSay;

  String get label {
    switch (this) {
      case Gender.female:
        return 'Female';
      case Gender.male:
        return 'Male';
      case Gender.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  static Gender fromString(String? val) {
    if (val == null) return Gender.preferNotToSay;
    switch (val.toLowerCase().trim()) {
      case 'female':
      case 'f':
        return Gender.female;
      case 'male':
      case 'm':
        return Gender.male;
      case 'prefer_not_to_say':
      case 'prefernottosay':
      case 'other':
      default:
        return Gender.preferNotToSay;
    }
  }
}

/// Represents user physical metrics used strictly on-device for physiological energy estimation.
///
/// Under India's DPDP Act and privacy-by-design standards:
/// - Stored exclusively in local SharedPreferences.
/// - NEVER transmitted to backend servers, telemetry, WebSockets, or logs.
/// - Purged upon user request ("Remove my body details" or account deletion).
class UserBodyProfile {
  final double weightKg;
  final double heightCm;
  final Gender gender;
  final int? birthYear;
  final bool isCustomized;
  final int skippedRunCount;
  final bool reminderDismissed;
  final bool isMigratedWeightOnly;

  // Validation range limits
  static const double minWeightKg = 25.0;
  static const double maxWeightKg = 250.0;
  static const double minHeightCm = 100.0;
  static const double maxHeightCm = 230.0;
  static const int minAge = 10;
  static const int maxAge = 100;

  // Reference adult defaults (documented fallback when skipped)
  static const double defaultWeightKg = 70.0;
  static const double defaultHeightCm = 170.0;
  static const Gender defaultGender = Gender.preferNotToSay;
  static const int defaultAge = 30;

  const UserBodyProfile({
    required this.weightKg,
    required this.heightCm,
    required this.gender,
    this.birthYear,
    this.isCustomized = false,
    this.skippedRunCount = 0,
    this.reminderDismissed = false,
    this.isMigratedWeightOnly = false,
  });

  /// Factory producing the standard reference adult (70 kg, 170 cm, neutral gender, age 30).
  factory UserBodyProfile.referenceAdult({
    double? weightKg,
    double? heightCm,
    Gender? gender,
    int? ageYears,
  }) {
    final currentYear = DateTime.now().year;
    return UserBodyProfile(
      weightKg: weightKg ?? defaultWeightKg,
      heightCm: heightCm ?? defaultHeightCm,
      gender: gender ?? defaultGender,
      birthYear: currentYear - (ageYears ?? defaultAge),
      isCustomized: false,
      skippedRunCount: 0,
      reminderDismissed: false,
      isMigratedWeightOnly: false,
    );
  }

  /// Estimated chronological age in years based on birth year.
  int? get ageYears {
    if (birthYear == null) return null;
    final currentYear = DateTime.now().year;
    final age = currentYear - birthYear!;
    if (age < minAge || age > maxAge) return null;
    return age;
  }

  /// Validation helpers
  static String? validateWeightKg(double? weight) {
    if (weight == null) return 'Please enter your weight';
    if (weight < minWeightKg || weight > maxWeightKg) {
      return 'Weight must be between ${minWeightKg.round()} and ${maxWeightKg.round()} kg';
    }
    return null;
  }

  static String? validateWeightLb(double? weightLb) {
    if (weightLb == null) return 'Please enter your weight';
    final minLb = (minWeightKg * 2.20462).round();
    final maxLb = (maxWeightKg * 2.20462).round();
    if (weightLb < minLb || weightLb > maxLb) {
      return 'Weight must be between $minLb and $maxLb lbs';
    }
    return null;
  }

  static String? validateHeightCm(double? height) {
    if (height == null) return 'Please enter your height';
    if (height < minHeightCm || height > maxHeightCm) {
      return 'Height must be between ${minHeightCm.round()} and ${maxHeightCm.round()} cm';
    }
    return null;
  }

  static String? validateHeightFtIn(int? feet, double? inches) {
    if (feet == null && inches == null) return 'Please enter your height';
    final totalInches = (feet ?? 0) * 12.0 + (inches ?? 0.0);
    final cm = totalInches * 2.54;
    if (cm < minHeightCm || cm > maxHeightCm) {
      return 'Height must be between 3\'3" and 7\'7"';
    }
    return null;
  }

  static String? validateAge(int? age) {
    if (age == null) return null; // Optional
    if (age < minAge || age > maxAge) {
      return 'Age must be between $minAge and $maxAge';
    }
    return null;
  }

  static String? validateBirthYear(int? year) {
    if (year == null) return null; // Optional
    final currentYear = DateTime.now().year;
    final age = currentYear - year;
    return validateAge(age);
  }

  // --- UNIT CONVERSIONS ---

  static double kgToLb(double kg) => kg * 2.20462262;
  static double lbToKg(double lb) => lb / 2.20462262;

  static double cmToTotalInches(double cm) => cm / 2.54;
  static double ftInToCm(int feet, double inches) =>
      ((feet * 12.0) + inches) * 2.54;

  static (int feet, double inches) cmToFeetAndInches(double cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = totalInches - (feet * 12);
    return (feet, inches);
  }

  UserBodyProfile copyWith({
    double? weightKg,
    double? heightCm,
    Gender? gender,
    int? birthYear,
    bool? isCustomized,
    int? skippedRunCount,
    bool? reminderDismissed,
    bool? isMigratedWeightOnly,
    bool clearBirthYear = false,
  }) {
    return UserBodyProfile(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      isCustomized: isCustomized ?? this.isCustomized,
      skippedRunCount: skippedRunCount ?? this.skippedRunCount,
      reminderDismissed: reminderDismissed ?? this.reminderDismissed,
      isMigratedWeightOnly: isMigratedWeightOnly ?? this.isMigratedWeightOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'gender': gender.name,
    'birth_year': birthYear,
    'is_customized': isCustomized,
    'skipped_run_count': skippedRunCount,
    'reminder_dismissed': reminderDismissed,
    'is_migrated_weight_only': isMigratedWeightOnly,
  };

  factory UserBodyProfile.fromJson(Map<String, dynamic> json) {
    return UserBodyProfile(
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? defaultWeightKg,
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? defaultHeightCm,
      gender: Gender.fromString(json['gender'] as String?),
      birthYear: json['birth_year'] as int?,
      isCustomized: json['is_customized'] as bool? ?? false,
      skippedRunCount: json['skipped_run_count'] as int? ?? 0,
      reminderDismissed: json['reminder_dismissed'] as bool? ?? false,
      isMigratedWeightOnly: json['is_migrated_weight_only'] as bool? ?? false,
    );
  }
}
