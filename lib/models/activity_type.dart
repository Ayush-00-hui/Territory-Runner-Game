/// Represents the supported exercise modes with physics-calibrated kinematics boundaries.
enum ExerciseActivityType {
  running,
  walking,
  cycling;

  String get id {
    switch (this) {
      case ExerciseActivityType.running:
        return 'running';
      case ExerciseActivityType.walking:
        return 'walking';
      case ExerciseActivityType.cycling:
        return 'cycling';
    }
  }

  String get displayName {
    switch (this) {
      case ExerciseActivityType.running:
        return 'Running';
      case ExerciseActivityType.walking:
        return 'Walking';
      case ExerciseActivityType.cycling:
        return 'Cycling';
    }
  }

  /// Authoritative upper instantaneous speed ceiling (in km/h) for anti-cheat validation.
  double get maxSpeedKmh {
    switch (this) {
      case ExerciseActivityType.running:
        return 25.0; // Human sprinting / distance ceiling
      case ExerciseActivityType.walking:
        return 10.0; // Fast walking ceiling
      case ExerciseActivityType.cycling:
        return 50.0; // Road / urban cycling ceiling
    }
  }

  /// Authoritative endurance average speed ceiling (in km/h).
  double get maxAverageSpeedKmh {
    switch (this) {
      case ExerciseActivityType.running:
        return 22.0; // Human marathon record is ~20.9 km/h
      case ExerciseActivityType.walking:
        return 8.5;
      case ExerciseActivityType.cycling:
        return 40.0; // Peloton average ceiling
    }
  }

  static ExerciseActivityType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'walking':
        return ExerciseActivityType.walking;
      case 'cycling':
        return ExerciseActivityType.cycling;
      case 'running':
      default:
        return ExerciseActivityType.running;
    }
  }
}
