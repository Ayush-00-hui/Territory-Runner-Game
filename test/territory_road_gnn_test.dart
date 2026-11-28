import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/services/territory_road_gnn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerritoryRoadGnnService RTX 5070 Spatial Model Tests', () {
    late TerritoryRoadGnnService service;

    setUp(() {
      service = TerritoryRoadGnnService();
    });

    test('Initializes with default graph metadata', () async {
      await service.initialize();
      expect(service.isModelLoaded, true);
    });

    test('Evaluates High Value Citadel road segment accurately', () {
      final res = service.evaluateRoadSegment(
        latitude: 28.6139,
        longitude: 77.2090,
        classification: RoadClassification.residentialStreet,
        speedLimitKmh: 35.0,
        athleteFootfallDensity: 0.90, // High traffic
        contentionIndex: 0.85, // Heavy contention
        greeneryRatio: 0.60,
      );

      expect(res.dynamicStrategicScore, greaterThanOrEqualTo(0.75));
      expect(res.xpMultiplier, greaterThan(2.0));
      expect(res.factionDefenseMultiplier, greaterThan(2.5));
      expect(res.strategicTier, 'High Value Citadel');
      expect(res.guidance, contains('bonus XP'));
    });

    test('Evaluates Scenic Green Corridor for athlete recovery', () {
      final res = service.evaluateRoadSegment(
        latitude: 28.6145,
        longitude: 77.2095,
        classification: RoadClassification.pedestrianFootway,
        speedLimitKmh: 15.0,
        athleteFootfallDensity: 0.20,
        contentionIndex: 0.10,
        greeneryRatio: 0.95, // High park canopy
      );

      expect(res.runnerSafetyScore, greaterThanOrEqualTo(0.80));
      expect(res.strategicTier, 'Scenic Green Corridor');
      expect(res.guidance, contains('recovery loop'));
    });

    test('Evaluates Contested Border road segment', () {
      final res = service.evaluateRoadSegment(
        latitude: 28.6150,
        longitude: 77.2100,
        classification: RoadClassification.secondaryAvenue,
        speedLimitKmh: 50.0,
        athleteFootfallDensity: 0.50,
        contentionIndex: 0.65,
        greeneryRatio: 0.30,
      );

      expect(res.dynamicStrategicScore, inInclusiveRange(0.50, 0.74));
      expect(res.strategicTier, 'Contested Border');
      expect(res.factionDefenseMultiplier, greaterThan(1.5));
    });
  });
}
