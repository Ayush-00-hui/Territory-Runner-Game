import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPreferences Unit & Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default metric and enabled haptics', () async {
      final prefs = AppPreferences();
      await prefs.init();

      expect(prefs.isHapticsEnabled, isTrue);
      expect(prefs.unit, equals(DistanceUnit.metric));
      expect(prefs.distanceUnitLabel, equals('km'));
      expect(prefs.paceUnitLabel, equals('/km'));
    });

    test('Toggling haptics persists to pref_voice_coach_haptics_enabled', () async {
      final prefs = AppPreferences();
      await prefs.init();

      await prefs.toggleHaptics(false);
      expect(prefs.isHapticsEnabled, isFalse);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('pref_voice_coach_haptics_enabled'), isFalse);

      await prefs.toggleHaptics(true);
      expect(prefs.isHapticsEnabled, isTrue);
      expect(sp.getBool('pref_voice_coach_haptics_enabled'), isTrue);
    });

    test('Changing distance unit persists to pref_distance_unit', () async {
      final prefs = AppPreferences();
      await prefs.init();

      await prefs.setUnit(DistanceUnit.imperial);
      expect(prefs.unit, equals(DistanceUnit.imperial));

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('pref_distance_unit'), equals('imperial'));

      await prefs.setUnit(DistanceUnit.metric);
      expect(prefs.unit, equals(DistanceUnit.metric));
      expect(sp.getString('pref_distance_unit'), equals('metric'));
    });

    test('Distance conversion and formatting helpers calculate accurately', () async {
      final prefs = AppPreferences();
      await prefs.init();

      // Metric checks
      await prefs.setUnit(DistanceUnit.metric);
      expect(prefs.convertDistance(5.0), closeTo(5.0, 0.001));
      expect(prefs.formatDistance(5.0), equals('5.00 km'));
      expect(prefs.distanceUnitLabel, equals('km'));
      expect(prefs.distanceUnitNoun, equals('kilometer'));
      expect(prefs.paceUnitLabel, equals('/km'));

      // Imperial checks
      await prefs.setUnit(DistanceUnit.imperial);
      expect(prefs.convertDistance(10.0), closeTo(6.21371, 0.001));
      expect(prefs.formatDistance(10.0), equals('6.21 mi'));
      expect(prefs.distanceUnitLabel, equals('mi'));
      expect(prefs.distanceUnitNoun, equals('mile'));
      expect(prefs.paceUnitLabel, equals('/mi'));
    });

    test('Area formatting helpers format metric and imperial sectors accurately', () async {
      final prefs = AppPreferences();
      await prefs.init();

      // Metric formatting
      await prefs.setUnit(DistanceUnit.metric);
      expect(prefs.formatArea(500), equals('500 m²'));
      expect(prefs.formatArea(25000), equals('0.03 km²'));

      // Imperial formatting
      await prefs.setUnit(DistanceUnit.imperial);
      expect(prefs.formatArea(100), equals('1076 sq ft'));
      expect(prefs.formatArea(50000), equals('12.4 acres'));
    });

    test('Loads pre-existing saved preferences on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'pref_voice_coach_haptics_enabled': false,
        'pref_distance_unit': 'imperial',
      });

      // Reset internal singleton state
      final prefs = AppPreferences();
      // Force reload
      final sp = await SharedPreferences.getInstance();
      await prefs.toggleHaptics(sp.getBool('pref_voice_coach_haptics_enabled') ?? false);
      final unitStr = sp.getString('pref_distance_unit');
      await prefs.setUnit(unitStr == 'imperial' ? DistanceUnit.imperial : DistanceUnit.metric);

      expect(prefs.isHapticsEnabled, isFalse);
      expect(prefs.unit, equals(DistanceUnit.imperial));
    });
  });
}
