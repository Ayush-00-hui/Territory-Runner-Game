import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/models/user_body_profile.dart';
import 'package:territory_runner/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPreferences Body Profile & Calorie Baseline Tests', () {
    late AppPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = AppPreferences();
      await prefs.init();
      await prefs.clearBodyProfile();
    });

    test('Default state falls back to reference adult (70 kg)', () {
      expect(prefs.hasBodyProfile, isFalse);
      expect(prefs.hasSkippedBodyDetails, isFalse);
      expect(prefs.bodyProfile, isNull);

      // Default calorie formula uses 70 kg
      // 5 km * 70 kg * 1.036 = 362.6 -> 363 kcal
      final cals = prefs.estimateCalories(distanceKm: 5.0);
      expect(cals, equals(363));
    });

    test(
      'Customized body profile updates calorie estimation and persists',
      () async {
        const customProfile = UserBodyProfile(
          weightKg: 85.0,
          heightCm: 182.0,
          gender: Gender.male,
          birthYear: 1990,
          isCustomized: true,
        );

        await prefs.setBodyProfile(customProfile);

        expect(prefs.hasBodyProfile, isTrue);
        expect(prefs.bodyProfile?.weightKg, equals(85.0));
        expect(prefs.bodyWeightKg, equals(85.0));

        // 5 km * 85 kg * 1.036 = 440.3 -> 440 kcal
        final cals = prefs.estimateCalories(distanceKm: 5.0);
        expect(cals, equals(440));
      },
    );

    test('Migrates legacy bodyWeightKg transparently on startup', () async {
      // Simulate existing user with legacy bodyWeightKg in SharedPreferences
      SharedPreferences.setMockInitialValues({'pref_body_weight_kg': 64.5});

      final legacyPrefs = AppPreferences();
      legacyPrefs.resetForTesting();
      await legacyPrefs.init();

      // Should automatically construct a migrated profile preserving weight
      expect(legacyPrefs.bodyWeightKg, equals(64.5));
      expect(legacyPrefs.bodyProfile?.weightKg, equals(64.5));
      expect(legacyPrefs.bodyProfile?.isMigratedWeightOnly, isTrue);
      expect(legacyPrefs.hasBodyProfile, isFalse); // not fully customized yet
    });

    test('Clear body details wipes profile and weight keys', () async {
      const profile = UserBodyProfile(
        weightKg: 78.0,
        heightCm: 175.0,
        gender: Gender.female,
        isCustomized: true,
      );
      await prefs.setBodyProfile(profile);
      expect(prefs.hasBodyProfile, isTrue);

      await prefs.clearBodyProfile();

      expect(prefs.bodyProfile, isNull);
      expect(prefs.bodyWeightKg, isNull);
      expect(prefs.hasBodyProfile, isFalse);
      expect(prefs.hasSkippedBodyDetails, isFalse);
    });

    test(
      'Skipped run counter increments and reminder dismissal works',
      () async {
        // User skips initial prompt
        await prefs.setSkippedBodyDetails(true);
        expect(prefs.hasSkippedBodyDetails, isTrue);

        // Run 1 completes
        await prefs.recordCompletedRunForBodyProfile();
        expect(prefs.bodyProfile?.skippedRunCount, equals(1));
        expect(prefs.bodyProfile?.reminderDismissed, isFalse);

        // Run 2 completes
        await prefs.recordCompletedRunForBodyProfile();
        expect(prefs.bodyProfile?.skippedRunCount, equals(2));

        // Run 3 completes (threshold reached)
        await prefs.recordCompletedRunForBodyProfile();
        expect(prefs.bodyProfile?.skippedRunCount, equals(3));

        // Dismiss reminder
        await prefs.dismissBodyDetailsReminder();
        expect(prefs.bodyProfile?.reminderDismissed, isTrue);

        // Future runs do not increment further once dismissed
        await prefs.recordCompletedRunForBodyProfile();
        expect(prefs.bodyProfile?.skippedRunCount, equals(3));
      },
    );
  });
}
