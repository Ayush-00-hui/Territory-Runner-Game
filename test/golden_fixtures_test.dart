import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/models/activity_type.dart';

void main() {
  group('Shared Golden Test Fixtures Tests (Dart Engine)', () {
    test('golden_valid_loop.json passes and area matches within 0.5% tolerance', () {
      final file = File('test_fixtures/golden_valid_loop.json');
      expect(file.existsSync(), isTrue, reason: 'Golden fixture must exist');
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();

      final engine = PolygonEnclosureEngine(
        minClosureDistanceMeters: (data['min_closure_distance_meters'] as num)
            .toDouble(),
        minPointsRequired: data['min_points_required'] as int,
        minLoopDistanceMeters: (data['min_loop_distance_meters'] as num)
            .toDouble(),
      );

      EnclosedLoopEvent? event;
      for (final pt in points) {
        event = engine.addPosition(pt);
        if (event != null) break;
      }

      expect(event, isNotNull);
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num)
          .toDouble();
      final double delta = (event!.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(
        percentDiff,
        lessThanOrEqualTo(tolerance),
        reason:
            'Computed area ${event.areaSqMeters} m² must be within $tolerance% of $expectedArea m²',
      );
    });

    test('golden_figure_8.json is rejected for self-intersection', () {
      final file = File('test_fixtures/golden_figure_8.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();

      final bool hasCrossing = PolygonEnclosureEngine.hasSelfIntersection(
        points,
      );
      expect(
        hasCrossing,
        isTrue,
        reason: 'Figure 8 must be detected as self-intersecting',
      );

      final engine = PolygonEnclosureEngine();
      for (final pt in points) {
        engine.addPosition(pt);
      }
      final manualEvent = engine.sealCurrentPath();
      expect(manualEvent, isNull);
      expect(
        engine.lastInvalidReason,
        equals(data['expected_rejection_reason']),
      );
    });

    test('golden_tiny_loop.json is rejected for insufficient perimeter', () {
      final file = File('test_fixtures/golden_tiny_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();

      final engine = PolygonEnclosureEngine(
        minClosureDistanceMeters: (data['min_closure_distance_meters'] as num)
            .toDouble(),
        minPointsRequired: data['min_points_required'] as int,
        minLoopDistanceMeters: (data['min_loop_distance_meters'] as num)
            .toDouble(),
      );

      EnclosedLoopEvent? event;
      for (final pt in points) {
        event = engine.addPosition(pt);
        if (event != null) break;
      }
      expect(
        event,
        isNull,
        reason: 'Perimeter under 40m must not trigger enclosure',
      );
    });

    test('golden_lasso_loop.json closes lasso loop at stem crossing within 0.5% tolerance', () {
      final file = File('test_fixtures/golden_lasso_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();

      final engine = PolygonEnclosureEngine();
      final events = <EnclosedLoopEvent>[];
      for (final pt in points) {
        final ev = engine.addPosition(pt);
        if (ev != null) events.add(ev);
      }

      expect(
        events,
        isNotEmpty,
        reason: 'Lasso loop crossing stem must be detected',
      );
      final event = events.first;
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num)
          .toDouble();
      final double delta = (event.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(
        percentDiff,
        lessThanOrEqualTo(tolerance),
        reason:
            'Lasso area ${event.areaSqMeters} m² must match $expectedArea m² within $tolerance%',
      );
    });

    test('golden_loop_with_crossing.json preserves valid loop despite subsequent path crossing', () {
      final file = File('test_fixtures/golden_loop_with_crossing.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();

      final engine = PolygonEnclosureEngine();
      final events = <EnclosedLoopEvent>[];
      for (final pt in points) {
        final ev = engine.addPosition(pt);
        if (ev != null) events.add(ev);
      }

      expect(
        events.length,
        equals(1),
        reason: 'Run must preserve 1 valid loop',
      );
      final event = events.first;
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num)
          .toDouble();
      final double delta = (event.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(
        percentDiff,
        lessThanOrEqualTo(tolerance),
        reason:
            'Loop area ${event.areaSqMeters} m² must match $expectedArea m² within $tolerance%',
      );
    });

    test('golden_two_loops.json detects both valid loops and sums area within 0.5% tolerance', () {
      final file = File('test_fixtures/golden_two_loops.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final points = rawPoints
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();

      final engine = PolygonEnclosureEngine();
      final events = <EnclosedLoopEvent>[];
      for (final pt in points) {
        final ev = engine.addPosition(pt);
        if (ev != null) events.add(ev);
      }

      expect(
        events.length,
        equals(2),
        reason: 'Must detect both enclosed loops',
      );
      final totalArea = events.fold<double>(
        0.0,
        (sum, ev) => sum + ev.areaSqMeters,
      );
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num)
          .toDouble();
      final double delta = (totalArea - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;

      expect(
        percentDiff,
        lessThanOrEqualTo(tolerance),
        reason:
            'Total area $totalArea m² must match $expectedArea m² within $tolerance%',
      );
    });

    test('golden_cycling_valid_loop.json is rejected in running mode but accepted in cycling mode', () {
      final file = File('test_fixtures/golden_cycling_valid_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;

      // 1. Under running mode: 40 km/h is rejected as outlier jump (> 35 km/h)
      final runningEngine = PolygonEnclosureEngine(
        activityType: ExerciseActivityType.running,
      );
      EnclosedLoopEvent? runningEvent;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = runningEngine.addPosition(pt, ts);
        if (ev != null) runningEvent = ev;
      }
      expect(
        runningEvent,
        isNull,
        reason: '40 km/h cycling track must be rejected under running outlier filter',
      );

      // 2. Under cycling mode: 40 km/h is accepted (<= 60 km/h)
      final cyclingEngine = PolygonEnclosureEngine(
        activityType: ExerciseActivityType.cycling,
      );
      EnclosedLoopEvent? cyclingEvent;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = cyclingEngine.addPosition(pt, ts);
        if (ev != null) cyclingEvent = ev;
      }
      expect(
        cyclingEvent,
        isNotNull,
        reason: '40 km/h cycling track must be accepted under cycling mode',
      );
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num)
          .toDouble();
      final double delta = (cyclingEvent!.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;
      expect(percentDiff, lessThanOrEqualTo(tolerance));
    });

    test(
      'golden_walking_valid_loop.json closes successfully under walking mode',
      () {
        final file = File('test_fixtures/golden_walking_valid_loop.json');
        expect(file.existsSync(), isTrue);
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

        final rawPoints = data['points'] as List<dynamic>;
        final walkingEngine = PolygonEnclosureEngine(
          activityType: ExerciseActivityType.walking,
        );
        EnclosedLoopEvent? walkingEvent;
        for (final p in rawPoints) {
          final pt = LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          );
          final ts = DateTime.parse(p['timestamp'] as String);
          final ev = walkingEngine.addPosition(pt, ts);
          if (ev != null) walkingEvent = ev;
        }
        expect(walkingEvent, isNotNull);
        final double expectedArea = (data['expected_area_sqm'] as num)
            .toDouble();
        final double tolerance = (data['area_tolerance_percent'] as num)
            .toDouble();
        final double delta = (walkingEvent!.areaSqMeters - expectedArea).abs();
        final double percentDiff = (delta / expectedArea) * 100.0;
        expect(percentDiff, lessThanOrEqualTo(tolerance));
      },
    );

    test(
      'golden_broken_gap.json is segmented and rejected due to >15s GPS gap',
      () {
        final file = File('test_fixtures/golden_broken_gap.json');
        expect(file.existsSync(), isTrue);
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

        final rawPoints = data['points'] as List<dynamic>;
        final engine = PolygonEnclosureEngine();
        EnclosedLoopEvent? event;
        for (final p in rawPoints) {
          final pt = LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          );
          final ts = DateTime.parse(p['timestamp'] as String);
          final ev = engine.addPosition(pt, ts);
          if (ev != null) event = ev;
        }

        expect(
          event,
          isNull,
          reason: 'Track with >15s gap must not close loop across dropout',
        );
        expect(
          engine.lastInvalidReason,
          equals(PolygonEnclosureEngine.signalGapReason),
        );
      },
    );

    test('golden_running_tiny_loop.json is valid in walking mode but rejected in running mode', () {
      final file = File('test_fixtures/golden_running_tiny_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;

      // 1. Walking mode (min perimeter 40m, min area 100 m²): Accepted
      final walkingEngine = PolygonEnclosureEngine(
        activityType: ExerciseActivityType.walking,
      );
      EnclosedLoopEvent? walkingEvent;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = walkingEngine.addPosition(pt, ts);
        if (ev != null) walkingEvent = ev;
      }
      expect(
        walkingEvent,
        isNotNull,
        reason: '48m/144m² loop is valid under walking mode',
      );

      // 2. Running mode (min perimeter 60m, min area 200 m²): Rejected
      final runningEngine = PolygonEnclosureEngine(
        activityType: ExerciseActivityType.running,
      );
      EnclosedLoopEvent? runningEvent;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = runningEngine.addPosition(pt, ts);
        if (ev != null) runningEvent = ev;
      }
      expect(
        runningEvent,
        isNull,
        reason: '48m loop must be rejected under running mode (min 60m)',
      );
      expect(
        runningEngine.lastInvalidReason,
        equals(PolygonEnclosureEngine.loopPerimeterTooSmallReason),
      );
    });

    test('golden_cycling_tiny_loop.json is valid in running mode but rejected in cycling mode', () {
      final file = File('test_fixtures/golden_cycling_tiny_loop.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;

      // 1. Running mode (min perimeter 60m, min area 200 m²): Accepted
      final runningEngine = PolygonEnclosureEngine(
        activityType: ExerciseActivityType.running,
      );
      EnclosedLoopEvent? runningEvent;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = runningEngine.addPosition(pt, ts);
        if (ev != null) runningEvent = ev;
      }
      expect(
        runningEvent,
        isNotNull,
        reason: '100m/625m² loop is valid under running mode',
      );

      // 2. Cycling mode (min perimeter 150m, min area 1000 m²): Rejected
      final cyclingEngine = PolygonEnclosureEngine(
        activityType: ExerciseActivityType.cycling,
      );
      EnclosedLoopEvent? cyclingEvent;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = cyclingEngine.addPosition(pt, ts);
        if (ev != null) cyclingEvent = ev;
      }
      expect(
        cyclingEvent,
        isNull,
        reason: '100m loop must be rejected under cycling mode (min 150m)',
      );
      expect(
        cyclingEngine.lastInvalidReason,
        equals(PolygonEnclosureEngine.loopPerimeterTooSmallReason),
      );
    });

    test('golden_pause_resume.json preserves path during pause <= 50m and closes loop', () {
      final file = File('test_fixtures/golden_pause_resume.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final engine = PolygonEnclosureEngine();
      EnclosedLoopEvent? event;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = engine.addPosition(pt, ts);
        if (ev != null) event = ev;
      }

      expect(
        event,
        isNotNull,
        reason: 'Pause <= 50m displacement must not reset path; loop must close',
      );
      final double expectedArea = (data['expected_area_sqm'] as num).toDouble();
      final double tolerance = (data['area_tolerance_percent'] as num).toDouble();
      final double delta = (event!.areaSqMeters - expectedArea).abs();
      final double percentDiff = (delta / expectedArea) * 100.0;
      expect(percentDiff, lessThanOrEqualTo(tolerance));
    });

    test('golden_gap_with_jump.json resets path when displacement > 50m across gap', () {
      final file = File('test_fixtures/golden_gap_with_jump.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final engine = PolygonEnclosureEngine();
      EnclosedLoopEvent? event;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = engine.addPosition(pt, ts);
        if (ev != null) event = ev;
      }

      expect(
        event,
        isNull,
        reason: 'Gap with jump > 50m must reset path and reject loop',
      );
      expect(
        engine.lastInvalidReason,
        equals(PolygonEnclosureEngine.signalGapReason),
      );
    });

    test('golden_very_long_gap.json resets path when gap > 10 minutes', () {
      final file = File('test_fixtures/golden_very_long_gap.json');
      expect(file.existsSync(), isTrue);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final rawPoints = data['points'] as List<dynamic>;
      final engine = PolygonEnclosureEngine();
      EnclosedLoopEvent? event;
      for (final p in rawPoints) {
        final pt = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final ts = DateTime.parse(p['timestamp'] as String);
        final ev = engine.addPosition(pt, ts);
        if (ev != null) event = ev;
      }

      expect(
        event,
        isNull,
        reason: 'Gap > 10 minutes must reset path and reject loop',
      );
      expect(
        engine.lastInvalidReason,
        equals(PolygonEnclosureEngine.signalGapReason),
      );
    });
  });
}
