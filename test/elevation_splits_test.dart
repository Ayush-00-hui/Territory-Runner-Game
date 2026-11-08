import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/history/widgets/elevation_profile_chart.dart';
import 'package:territory_runner/features/history/widgets/splits_table.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/elevation_splits_service.dart';
import 'package:territory_runner/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task F2: ElevationSplitsService Pure Engine Tests', () {
    late ElevationSplitsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ElevationSplitsService();
      service.clearCache();
    });

    List<RunSample> generateTrack({
      required int pointCount,
      required double distanceMeters,
      required double startAltitude,
      required double Function(double progressFraction) altitudeProfile,
      double Function(double progressFraction)? noiseGenerator,
      double? spikeAtIndex,
      double? spikeAltitude,
      int? pauseAtIndex,
      int? pauseDurationSec,
    }) {
      final samples = <RunSample>[];
      const startLat = 12.9716;
      const startLng = 77.5946;
      final stepM = distanceMeters / (pointCount - 1);
      final stepSec = (stepM / 3.0); // ~3 m/s pace (~5:33 /km)

      int currentElapsedMs = 0;

      for (int i = 0; i < pointCount; i++) {
        final progress = i / (pointCount - 1);
        final lat = startLat + (i * (stepM / 111320.0)); // northwards
        final lng = startLng;

        double alt = startAltitude + altitudeProfile(progress);
        if (noiseGenerator != null) {
          alt += noiseGenerator(progress);
        }

        if (spikeAtIndex != null &&
            i == spikeAtIndex &&
            spikeAltitude != null) {
          alt = spikeAltitude;
        }

        if (pauseAtIndex != null &&
            i == pauseAtIndex &&
            pauseDurationSec != null) {
          currentElapsedMs += pauseDurationSec * 1000;
        } else if (i > 0) {
          currentElapsedMs += (stepSec * 1000).round();
        }

        samples.add(
          RunSample(
            timeOffsetMs: currentElapsedMs,
            lat: lat,
            lng: lng,
            altitude: alt,
            accuracy: 5.0,
          ),
        );
      }
      return samples;
    }

    test('Synthetic flat track: 0% grade, splits have near-zero elevation change, zero false gain', () {
      final rng = math.Random(42);
      // 3.0 km flat track with +/- 1.0m sensor noise
      final samples = generateTrack(
        pointCount: 300,
        distanceMeters: 3000.0,
        startAltitude: 100.0,
        altitudeProfile: (_) => 0.0,
        noiseGenerator: (_) => (rng.nextDouble() - 0.5) * 2.0,
      );

      final result = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.metric,
      );

      expect(result.hasValidAltitude, isTrue);
      // Hysteresis threshold (3m) prevents false gain accumulation from flat GPS jitter
      expect(result.totalGainMeters, equals(0.0));
      expect(result.totalLossMeters, equals(0.0));
      expect(result.splits.length, equals(3)); // 3 x 1km splits

      for (final split in result.splits) {
        expect(split.elevationChangeMeters.abs(), lessThan(1.5));
        expect(split.averageGrade.abs(), lessThan(0.005)); // < 0.5% grade
        expect(split.paceSeconds, inInclusiveRange(300, 360));
      }
    });

    test('Steady hill (+5% slope over 2000m): tracks positive gain and ~5% average grade across splits', () {
      final rng = math.Random(123);
      // 2.0 km steady climb (+100m total climb)
      final samples = generateTrack(
        pointCount: 200,
        distanceMeters: 2000.0,
        startAltitude: 100.0,
        altitudeProfile: (p) => p * 100.0, // rises from 100m to 200m
        noiseGenerator: (_) => (rng.nextDouble() - 0.5) * 1.0,
      );

      final result = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.metric,
      );

      expect(result.hasValidAltitude, isTrue);
      expect(result.totalGainMeters, inInclusiveRange(90.0, 105.0));
      expect(result.totalLossMeters, equals(0.0));
      expect(result.minAltitudeMeters, inInclusiveRange(98.0, 102.0));
      expect(result.maxAltitudeMeters, inInclusiveRange(195.0, 202.0));

      expect(result.splits.length, equals(2));
      for (final split in result.splits) {
        expect(split.averageGrade, inInclusiveRange(0.040, 0.060)); // ~5% grade
        expect(split.elevationChangeMeters, inInclusiveRange(40.0, 60.0));
      }
    });

    test('Rolling hills: captures both climbs separated by descent without loss of accuracy', () {
      // 3.0 km track: climbs 50m in first km, descends 40m in second km, climbs 60m in third km
      final samples = generateTrack(
        pointCount: 300,
        distanceMeters: 3000.0,
        startAltitude: 100.0,
        altitudeProfile: (p) {
          if (p <= 0.33) {
            return (p / 0.33) * 50.0; // 100m -> 150m
          } else if (p <= 0.66) {
            return 50.0 - ((p - 0.33) / 0.33) * 40.0; // 150m -> 110m
          } else {
            return 110.0 - 100.0 + ((p - 0.66) / 0.34) * 60.0; // 110m -> 170m
          }
        },
      );

      final result = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.metric,
      );

      expect(result.hasValidAltitude, isTrue);
      // Gain: ~50m + ~60m = ~110m
      expect(result.totalGainMeters, inInclusiveRange(95.0, 120.0));
      // Loss: ~40m
      expect(result.totalLossMeters, inInclusiveRange(30.0, 50.0));

      expect(result.splits.length, equals(3));
      // Split 1: climb
      expect(result.splits[0].elevationChangeMeters, greaterThan(35.0));
      // Split 2: descent
      expect(result.splits[1].elevationChangeMeters, lessThan(-25.0));
      // Split 3: climb
      expect(result.splits[2].elevationChangeMeters, greaterThan(45.0));
    });

    test(
      'GPS spike rejection: vertical velocity > 15 m/s spike is smoothed out',
      () {
        // Track with normal altitude ~100m, but point 50 has a sudden spike to 800m!
        final samples = generateTrack(
          pointCount: 150,
          distanceMeters: 1500.0,
          startAltitude: 100.0,
          altitudeProfile: (_) => 0.0,
          spikeAtIndex: 50,
          spikeAltitude:
              800.0, // Impulsive spike (+700m in ~3s = 233 m/s vertical speed!)
        );

        final result = service.computeProfile(
          samples: samples,
          unit: DistanceUnit.metric,
        );

        expect(result.hasValidAltitude, isTrue);
        // Spike must be suppressed: max altitude should remain near 100m, NOT anywhere near 800m
        expect(result.maxAltitudeMeters, lessThan(125.0));
        expect(result.totalGainMeters, lessThan(10.0));
      },
    );

    test('Short run (< 1 km): produces a single partial split with projected pace and flagged as best', () {
      // 600m short run
      final samples = generateTrack(
        pointCount: 60,
        distanceMeters: 600.0,
        startAltitude: 100.0,
        altitudeProfile: (p) => p * 15.0, // rises 15m
      );

      final result = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.metric,
      );

      expect(result.hasValidAltitude, isTrue);
      expect(result.splits.length, equals(1));
      final singleSplit = result.splits.first;
      expect(singleSplit.index, equals(1));
      expect(singleSplit.isPartial, isTrue);
      expect(singleSplit.isBest, isTrue); // Best by definition
      expect(singleSplit.displayDistance, closeTo(0.60, 0.05));
      expect(singleSplit.elevationChangeMeters, inInclusiveRange(10.0, 16.0));
      expect(singleSplit.paceSeconds, greaterThan(0));
    });

    test('Pauses: handles stationary elapsed time without corrupting moving pace calculation', () {
      // 2000m track: split 1 normal, split 2 has a 60-second pause at midpoint
      final samples = generateTrack(
        pointCount: 200,
        distanceMeters: 2000.0,
        startAltitude: 100.0,
        altitudeProfile: (_) => 0.0,
        pauseAtIndex: 150,
        pauseDurationSec: 60,
      );

      final result = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.metric,
      );

      expect(result.splits.length, equals(2));
      // Split 1 pace should be normal
      expect(result.splits[0].paceSeconds, inInclusiveRange(300, 360));
      // Split 1 was faster than split 2 because split 2 included pause
      expect(result.splits[0].isBest, isTrue);
      expect(result.splits[1].isBest, isFalse);
    });

    test('Unit changes: metric (1km, meters) vs imperial (1 mile, feet)', () {
      // 3250m track (~2.02 miles)
      final samples = generateTrack(
        pointCount: 300,
        distanceMeters: 3250.0,
        startAltitude: 100.0,
        altitudeProfile: (p) => p * 50.0, // 50m climb
      );

      // Metric profile
      final metricResult = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.metric,
      );
      expect(metricResult.unit, equals(DistanceUnit.metric));
      expect(
        metricResult.splits.length,
        equals(4),
      ); // 3 full 1km splits + 1 partial (250m)
      expect(metricResult.splits.first.formattedElevationChange, contains('m'));
      expect(metricResult.formattedGain, contains('m'));

      // Imperial profile
      final imperialResult = service.computeProfile(
        samples: samples,
        unit: DistanceUnit.imperial,
      );
      expect(imperialResult.unit, equals(DistanceUnit.imperial));
      // 3250m / 1609.344m = 2.019 miles -> 2 full 1-mile splits + 1 tiny remainder (<50m ignored)
      expect(imperialResult.splits.length, inInclusiveRange(2, 3));
      expect(
        imperialResult.splits.first.formattedElevationChange,
        contains('ft'),
      );
      expect(imperialResult.formattedGain, contains('ft'));
    });

    test('Missing or low-quality altitude: returns hasValidAltitude == false with calm reason', () {
      // Track with null altitude
      final samplesNoAlt = [
        RunSample(timeOffsetMs: 0, lat: 12.971, lng: 77.591),
        RunSample(timeOffsetMs: 10000, lat: 12.972, lng: 77.592),
        RunSample(timeOffsetMs: 20000, lat: 12.973, lng: 77.593),
      ];

      final result = service.computeProfile(
        samples: samplesNoAlt,
        unit: DistanceUnit.metric,
      );

      expect(result.hasValidAltitude, isFalse);
      expect(result.unavailableReason, isNotNull);
      expect(result.unavailableReason!, contains('altitude data was missing'));
    });

    test('Downsampling & Caching: downsamples dense track to ~300 points and reuses cache', () {
      // Very dense track with 1500 points
      final denseSamples = generateTrack(
        pointCount: 1500,
        distanceMeters: 5000.0,
        startAltitude: 100.0,
        altitudeProfile: (p) => math.sin(p * math.pi) * 30.0,
      );

      final result = service.computeProfile(
        samples: denseSamples,
        unit: DistanceUnit.metric,
        cacheKey: 'run_dense_test_1',
      );

      expect(
        result.points.length,
        equals(ElevationSplitsService.targetProfilePoints),
      );
      expect(result.points.first.distanceMeters, equals(0.0));
      expect(result.points.last.distanceMeters, greaterThan(4000.0));

      // Second call hits cache
      final cachedResult = service.computeProfile(
        samples: denseSamples,
        unit: DistanceUnit.metric,
        cacheKey: 'run_dense_test_1',
      );
      expect(identical(result, cachedResult), isTrue);
    });
  });

  group('Task F2: ElevationProfileChart and SplitsTable Widget Tests', () {
    testWidgets('Renders empty state when altitude is unavailable', (
      tester,
    ) async {
      const data = ElevationProfileData(
        hasValidAltitude: false,
        unavailableReason: 'Elevation chart unavailable: this run does not contain altitude data.',
        unit: DistanceUnit.metric,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: ElevationProfileChart(profileData: data)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Elevation chart unavailable: this run does not contain altitude data.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.terrain_rounded), findsOneWidget);
    });

    testWidgets(
      'Renders valid elevation chart, chips, and responds to drag scrubbing',
      (tester) async {
        final points = List.generate(
          100,
          (i) => ElevationPoint(
            distanceMeters: i * 20.0, // 0 to 2000m
            altitudeMeters: 100.0 + (i * 0.5), // 100m to 150m
            lat: 12.97 + (i * 0.0001),
            lng: 77.59,
            timeOffsetMs: i * 2000,
            grade: 0.025,
          ),
        );

        final data = ElevationProfileData(
          hasValidAltitude: true,
          points: points,
          minAltitudeMeters: 100.0,
          maxAltitudeMeters: 150.0,
          totalGainMeters: 50.0,
          totalLossMeters: 0.0,
          unit: DistanceUnit.metric,
        );

        ElevationPoint? scrubbedPoint;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ElevationProfileChart(
                profileData: data,
                onScrub: (pt) => scrubbedPoint = pt,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('+50 m'), findsOneWidget);
        expect(find.text('-0 m'), findsOneWidget);
        expect(find.text('Min 100 m • Max 150 m'), findsOneWidget);

        // Scrub halfway across chart
        final chartFinder = find.byType(ElevationProfileChart);
        await tester.drag(chartFinder, const Offset(150, 0));
        await tester.pumpAndSettle();

        expect(scrubbedPoint, isNotNull);
        expect(scrubbedPoint!.distanceMeters, greaterThan(0.0));
      },
    );

    testWidgets('SplitsTable renders per-km rows and highlights best split', (
      tester,
    ) async {
      final splits = [
        const RunSplit(
          index: 1,
          distanceMeters: 1000.0,
          displayDistance: 1.0,
          durationSeconds: 320,
          paceSeconds: 320, // 5'20"
          elevationChangeMeters: 12.0,
          elevationGainMeters: 12.0,
          elevationLossMeters: 0.0,
          averageGrade: 0.012,
          isBest: false,
          unit: DistanceUnit.metric,
        ),
        const RunSplit(
          index: 2,
          distanceMeters: 1000.0,
          displayDistance: 1.0,
          durationSeconds: 295,
          paceSeconds: 295, // 4'55" -> BEST
          elevationChangeMeters: -5.0,
          elevationGainMeters: 0.0,
          elevationLossMeters: 5.0,
          averageGrade: -0.005,
          isBest: true,
          unit: DistanceUnit.metric,
        ),
        const RunSplit(
          index: 3,
          distanceMeters: 450.0,
          displayDistance: 0.45,
          durationSeconds: 150,
          paceSeconds: 333,
          elevationChangeMeters: 3.0,
          elevationGainMeters: 3.0,
          elevationLossMeters: 0.0,
          averageGrade: 0.006,
          isBest: false,
          isPartial: true,
          unit: DistanceUnit.metric,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SplitsTable(splits: splits, unit: DistanceUnit.metric),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KM'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('Elev'), findsOneWidget);
      expect(find.text('Grade'), findsOneWidget);

      expect(find.text("5'20\""), findsOneWidget);
      expect(find.text("4'55\""), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('+12 m'), findsOneWidget);
      expect(find.text('-5 m'), findsOneWidget);
      expect(find.text('+1.2%'), findsOneWidget);
      expect(find.text('-0.5%'), findsOneWidget);
      expect(find.text('3 (0.45)'), findsOneWidget);
    });
  });
}
