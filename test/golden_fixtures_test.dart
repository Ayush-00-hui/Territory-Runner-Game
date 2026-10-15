import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';

void main() {
  group('Shared Golden Test Fixtures Tests (Dart Engine)', () {
    test('golden_valid_loop.json passes and area matches within 0.5% tolerance', () {
      final file = File('test_fixtures/golden_valid_loop.json');
      expect(file.existsSync(), isTrue, reason: 'Golden fixture must exist');
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints.map((p) => LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      )).toList();

      final engine = PolygonEnclosureEngine(
        minClosureDistanceMeters: (data['min_closure_distance_meters'] as num).toDouble(),
        minPointsRequired: data['min_points_required'] as int,
        minLoopDistanceMeters: (data['min_loop_distance_meters'] as num).toDouble(),
      );

      EnclosedLoopEvent? event;
      for (final pt in points) {
        event = engine.addPosition(pt);
        if (event != null) break;
      }

      expect(event, isNotNull);
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num).toDouble();
      final double delta = (event!.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(percentDiff, lessThanOrEqualTo(tolerance),
          reason: 'Computed area ${event.areaSqMeters} m² must be within $tolerance% of $expectedArea m²');
    });

    test('golden_figure_8.json is rejected for self-intersection', () {
      final file = File('test_fixtures/golden_figure_8.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints.map((p) => LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      )).toList();

      final bool hasCrossing = PolygonEnclosureEngine.hasSelfIntersection(points);
      expect(hasCrossing, isTrue, reason: 'Figure 8 must be detected as self-intersecting');

      final engine = PolygonEnclosureEngine();
      for (final pt in points) {
        engine.addPosition(pt);
      }
      final manualEvent = engine.sealCurrentPath();
      expect(manualEvent, isNull);
      expect(engine.lastInvalidReason, equals(data['expected_rejection_reason']));
    });

    test('golden_tiny_loop.json is rejected for insufficient perimeter', () {
      final file = File('test_fixtures/golden_tiny_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints.map((p) => LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      )).toList();

      final engine = PolygonEnclosureEngine(
        minClosureDistanceMeters: (data['min_closure_distance_meters'] as num).toDouble(),
        minPointsRequired: data['min_points_required'] as int,
        minLoopDistanceMeters: (data['min_loop_distance_meters'] as num).toDouble(),
      );

      EnclosedLoopEvent? event;
      for (final pt in points) {
        event = engine.addPosition(pt);
        if (event != null) break;
      }
      expect(event, isNull, reason: 'Perimeter under 40m must not trigger enclosure');
    });

    test('golden_lasso_loop.json closes lasso loop at stem crossing within 0.5% tolerance', () {
      final file = File('test_fixtures/golden_lasso_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints.map((p) => LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      )).toList();

      final engine = PolygonEnclosureEngine();
      final events = <EnclosedLoopEvent>[];
      for (final pt in points) {
        final ev = engine.addPosition(pt);
        if (ev != null) events.add(ev);
      }

      expect(events, isNotEmpty, reason: 'Lasso loop crossing stem must be detected');
      final event = events.first;
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num).toDouble();
      final double delta = (event.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(percentDiff, lessThanOrEqualTo(tolerance),
          reason: 'Lasso area ${event.areaSqMeters} m² must match $expectedArea m² within $tolerance%');
    });

    test('golden_loop_with_crossing.json preserves valid loop despite subsequent path crossing', () {
      final file = File('test_fixtures/golden_loop_with_crossing.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints.map((p) => LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      )).toList();

      final engine = PolygonEnclosureEngine();
      final events = <EnclosedLoopEvent>[];
      for (final pt in points) {
        final ev = engine.addPosition(pt);
        if (ev != null) events.add(ev);
      }

      expect(events.length, equals(1), reason: 'Run must preserve 1 valid loop');
      final event = events.first;
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num).toDouble();
      final double delta = (event.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(percentDiff, lessThanOrEqualTo(tolerance),
          reason: 'Loop area ${event.areaSqMeters} m² must match $expectedArea m² within $tolerance%');
    });

    test('golden_two_loops.json detects both valid loops and sums area within 0.5% tolerance', () {
      final file = File('test_fixtures/golden_two_loops.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints.map((p) => LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      )).toList();

      final engine = PolygonEnclosureEngine();
      final events = <EnclosedLoopEvent>[];
      for (final pt in points) {
        final ev = engine.addPosition(pt);
        if (ev != null) events.add(ev);
      }

      expect(events.length, equals(2), reason: 'Must detect both enclosed loops');
      final totalArea = events.fold<double>(0.0, (sum, ev) => sum + ev.areaSqMeters);
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num).toDouble();
      final double delta = (totalArea - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(percentDiff, lessThanOrEqualTo(tolerance),
          reason: 'Total area $totalArea m² must match $expectedArea m² within $tolerance%');
    });
  });
}
