import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:territory_runner/features/history/run_history_screen.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/export_service.dart';
import 'package:territory_runner/services/run_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<String> testBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('run_log_test_');
    Hive.init(tempDir.path);
    testBox = await Hive.openBox<String>('test_run_log');
  });

  tearDown(() async {
    if (testBox.isOpen) {
      await testBox.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RunLogEntry & RunSample Models', () {
    test('serialization round-trip preserves all fields and version', () {
      final now = DateTime.now();
      final entry = RunLogEntry(
        id: 'run_idem_001',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        activityType: 'running',
        movingSeconds: 1750,
        totalSeconds: 1800,
        distanceM: 5250.0,
        samples: [
          const RunSample(
            timeOffsetMs: 0,
            lat: 51.5000,
            lng: -0.1200,
            altitude: 25.4,
            accuracy: 3.2,
          ),
          const RunSample(
            timeOffsetMs: 1000,
            lat: 51.5001,
            lng: -0.1201,
            altitude: 25.8,
            accuracy: 3.1,
          ),
        ],
        stepCount: 2600,
        cadenceStats: const CadenceStats(
          averageSpm: 168.0,
          maxSpm: 182.0,
          confidence: 0.95,
        ),
        calories: 385,
        calorieModelVersion: '1.0.0',
        elevationGainM: 42.0,
        elevationLossM: 38.0,
        claimedAreaSqM: 12500.0,
        xp: 625,
        syncStatus: 'synced',
        isSimplified: false,
      );

      final json = entry.toJson();
      expect(json['v'], equals(1));
      expect(json['id'], equals('run_idem_001'));
      expect(json['cal'], equals(385));
      expect(json['steps'], equals(2600));

      final restored = RunLogEntry.fromJson(json);
      expect(restored.id, equals(entry.id));
      expect(restored.movingSeconds, equals(1750));
      expect(restored.totalSeconds, equals(1800));
      expect(restored.distanceM, equals(5250.0));
      expect(restored.samples.length, equals(2));
      expect(restored.samples[0].altitude, equals(25.4));
      expect(restored.cadenceStats?.averageSpm, equals(168.0));
      expect(restored.calories, equals(385));
      expect(restored.claimedAreaSqM, equals(12500.0));
      expect(restored.isSimplified, isFalse);
    });

    test('pace calculation handles normal and edge cases', () {
      final normal = RunLogEntry(
        id: 'run_pace',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        movingSeconds: 1200, // 20 mins for 4 km -> 300 s/km (5:00/km)
        totalSeconds: 1250,
        distanceM: 4000.0,
        samples: [],
      );
      expect(normal.paceSecondsPerKm, equals(300.0));
      expect(normal.paceSecondsPerMile, closeTo(482.8, 0.5));

      final zero = RunLogEntry(
        id: 'run_zero',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        movingSeconds: 0,
        totalSeconds: 0,
        distanceM: 0.0,
        samples: [],
      );
      expect(zero.paceSecondsPerKm, equals(0.0));
      expect(zero.paceSecondsPerMile, equals(0.0));
    });
  });

  group('Douglas-Peucker Polyline Simplification', () {
    test('simplifies straight line to 2 endpoints', () {
      final straight = [
        for (int i = 0; i <= 20; i++)
          RunSample(
            timeOffsetMs: i * 1000,
            lat: 51.5000 + (i * 0.0001),
            lng: -0.1200,
          ),
      ];
      final simplified = douglasPeucker(straight, 5.0);
      expect(simplified.length, equals(2));
      expect(simplified.first.lat, equals(straight.first.lat));
      expect(simplified.last.lat, equals(straight.last.lat));
    });

    test('preserves prominent deviation points on curved track', () {
      final points = [
        const RunSample(timeOffsetMs: 0, lat: 51.5000, lng: -0.1200),
        const RunSample(timeOffsetMs: 1000, lat: 51.5005, lng: -0.1200),
        // Sharp 90-degree corner (deviation > 50m)
        const RunSample(timeOffsetMs: 2000, lat: 51.5005, lng: -0.1215),
        const RunSample(timeOffsetMs: 3000, lat: 51.5010, lng: -0.1215),
      ];
      final simplified = douglasPeucker(points, 5.0);
      expect(simplified.length, greaterThanOrEqualTo(3));
      expect(
        simplified.any((p) => p.lat == 51.5005 && p.lng == -0.1215),
        isTrue,
      );
    });
  });

  group('RunLogService Persistence, Caps & Retention', () {
    test('enforces per-run sample cap with 2x downsampling', () async {
      final service = RunLogService(overrideBox: testBox);

      // Create 15,000 samples (exceeding 10,000 cap)
      final samples = List.generate(
        15000,
        (i) => RunSample(
          timeOffsetMs: i * 1000,
          lat: 51.5 + (i * 0.00001),
          lng: -0.12,
        ),
      );

      final entry = await service.recordRun(
        id: 'run_large',
        startedAt: DateTime.now(),
        endedAt: DateTime.now().add(const Duration(hours: 4)),
        movingSeconds: 14000,
        totalSeconds: 15000,
        distanceM: 25000.0,
        samples: samples,
      );

      expect(
        entry.samples.length,
        lessThanOrEqualTo(RunLogService.perRunSampleCap),
      );
      expect(entry.samples.length, equals(7501));
    });

    test(
      'enforces 200-run retention policy and simplifies older runs',
      () async {
        final service = RunLogService(overrideBox: testBox);

        // Insert 205 runs
        final baseTime = DateTime(2026, 1, 1);
        for (int i = 0; i < 205; i++) {
          final runTime = baseTime.add(Duration(days: i));
          final samples = [
            for (int s = 0; s <= 20; s++)
              RunSample(
                timeOffsetMs: s * 1000,
                lat: 51.5 + (s * 0.0001),
                lng: -0.12,
              ),
          ];

          await service.recordRun(
            id: 'run_$i',
            startedAt: runTime,
            endedAt: runTime.add(const Duration(minutes: 30)),
            movingSeconds: 1800,
            totalSeconds: 1800,
            distanceM: 5000.0,
            samples: samples,
          );
        }

        final all = service.getAllRuns();
        expect(all.length, equals(205));

        // The 5 oldest runs (at indices 200..204 in newest-first list) should be simplified
        for (int i = 200; i < 205; i++) {
          expect(all[i].isSimplified, isTrue);
          expect(all[i].samples.length, lessThan(21));
        }

        // The top 200 runs should remain full fidelity
        for (int i = 0; i < 200; i++) {
          expect(all[i].isSimplified, isFalse);
          expect(all[i].samples.length, equals(21));
        }
      },
    );

    test('deleteRun removes entry and updates notifier', () async {
      final service = RunLogService(overrideBox: testBox);
      await service.recordRun(
        id: 'run_to_delete',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        movingSeconds: 600,
        totalSeconds: 600,
        distanceM: 1500.0,
        samples: [],
      );

      expect(service.getAllRuns().length, equals(1));
      await service.deleteRun('run_to_delete');
      expect(service.getAllRuns().length, equals(0));
      expect(service.getRun('run_to_delete'), isNull);
    });

    test('clearAllRuns removes all entries from box and notifier', () async {
      final service = RunLogService(overrideBox: testBox);
      await service.recordRun(
        id: 'run_1',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        movingSeconds: 600,
        totalSeconds: 600,
        distanceM: 1500.0,
        samples: [],
      );
      await service.recordRun(
        id: 'run_2',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        movingSeconds: 900,
        totalSeconds: 900,
        distanceM: 2500.0,
        samples: [],
      );

      expect(service.getAllRuns().length, equals(2));
      await service.clearAllRuns();
      expect(service.getAllRuns().length, equals(0));
      expect(service.runsNotifier.value.isEmpty, isTrue);
    });
  });

  group('PersonalRecords Calculation', () {
    test(
      'computes longest run, fastest km/mile, biggest capture, and streak',
      () {
        final service = RunLogService(overrideBox: testBox);
        final now = DateTime.now();

        final runs = [
          RunLogEntry(
            id: 'run_a',
            startedAt: now.subtract(const Duration(days: 2)),
            endedAt: now.subtract(const Duration(days: 2)),
            movingSeconds: 1500, // 5000m in 1500s -> 300 s/km (5:00/km)
            totalSeconds: 1500,
            distanceM: 5000.0,
            samples: [],
            claimedAreaSqM: 8000.0,
          ),
          RunLogEntry(
            id: 'run_b',
            startedAt: now.subtract(const Duration(days: 1)),
            endedAt: now.subtract(const Duration(days: 1)),
            movingSeconds: 3000, // 10000m in 3000s -> 300 s/km
            totalSeconds: 3000,
            distanceM: 10000.0,
            samples: [],
            claimedAreaSqM: 25000.0,
          ),
          RunLogEntry(
            id: 'run_c',
            startedAt: now,
            endedAt: now,
            movingSeconds: 500, // 2000m in 500s -> 250 s/km (4:10/km) - FASTEST
            totalSeconds: 500,
            distanceM: 2000.0,
            samples: [],
            claimedAreaSqM: 4000.0,
          ),
        ];

        final records = service.computePersonalRecords(overrideRuns: runs);

        expect(records.longestRunDistanceM, equals(10000.0));
        expect(records.biggestCaptureSqm, equals(25000.0));
        expect(records.fastestKmPaceSeconds, equals(250.0));
        expect(records.longestStreakDays, equals(3));
        expect(records.weeklyAreaSqm, equals(37000.0));
      },
    );

    test('returns empty records when no runs exist', () {
      final service = RunLogService(overrideBox: testBox);
      final records = service.computePersonalRecords(overrideRuns: []);

      expect(records.longestRunDistanceM, equals(0.0));
      expect(records.biggestCaptureSqm, equals(0.0));
      expect(records.fastestKmPaceSeconds, isNull);
      expect(records.longestStreakDays, equals(0));
      expect(records.weeklyAreaSqm, equals(0.0));
      expect(records.hasAnyRecord, isFalse);
    });
  });

  group('Enhanced GPX 1.1 Export with Time & Elevation', () {
    test(
      'generateGpxFromRun outputs valid GPX containing <ele> and <time>',
      () {
        final startTime = DateTime.utc(2026, 11, 8, 8, 0, 0);
        final run = RunLogEntry(
          id: 'run_gpx_test',
          startedAt: startTime,
          endedAt: startTime.add(const Duration(minutes: 10)),
          movingSeconds: 600,
          totalSeconds: 600,
          distanceM: 1500.0,
          samples: [
            const RunSample(
              timeOffsetMs: 0,
              lat: 51.5000,
              lng: -0.1200,
              altitude: 18.5,
            ),
            const RunSample(
              timeOffsetMs: 30000,
              lat: 51.5005,
              lng: -0.1205,
              altitude: 21.0,
            ),
          ],
        );

        final gpx = ExportService().generateGpxFromRun(
          run,
          applyPrivacyRedaction: false,
        );

        expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
        expect(gpx, contains('<gpx version="1.1"'));
        expect(gpx, contains('<trkpt lat="51.5000000" lon="-0.1200000">'));
        expect(gpx, contains('<ele>18.5</ele>'));
        expect(gpx, contains('<time>2026-11-08T08:00:00.000Z</time>'));
        expect(gpx, contains('<ele>21.0</ele>'));
        expect(gpx, contains('<time>2026-11-08T08:00:30.000Z</time>'));
      },
    );
  });

  group('RunHistoryScreen Empty State & Real Runs UI', () {
    testWidgets('renders calm empty state when zero runs recorded', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RunHistoryScreen(
            initialRuns: const [],
            initialProfile: RunnerProfile(
              id: 'empty_user',
              username: 'NewRunner',
              totalDistanceKm: 0.0,
              xp: 0,
              level: 1,
              badges: [],
              totalHexesClaimed: 0,
              currentStreak: 0,
              faction: 'Unassigned',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('No runs in range'), findsOneWidget);
      expect(
        find.text(
          'Try changing your filters or start a new run to claim territory.',
        ),
        findsOneWidget,
      );
      // Personal records should display calm placeholders
      expect(find.text('Longest run'), findsOneWidget);
      expect(find.text('Biggest capture'), findsOneWidget);
      expect(find.text('Fastest km'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(4));
    });

    testWidgets('renders real recorded runs and computes records correctly', (
      tester,
    ) async {
      final now = DateTime.now();
      final run = RunLogEntry(
        id: 'real_run_1',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 25)),
        movingSeconds: 1500,
        totalSeconds: 1500,
        distanceM: 5000.0,
        samples: [
          const RunSample(timeOffsetMs: 0, lat: 51.5, lng: -0.12),
          const RunSample(timeOffsetMs: 500000, lat: 51.51, lng: -0.12),
          const RunSample(timeOffsetMs: 1000000, lat: 51.51, lng: -0.11),
          const RunSample(timeOffsetMs: 1500000, lat: 51.5, lng: -0.11),
        ],
        claimedAreaSqM: 14200.0,
        calories: 360,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RunHistoryScreen(
            initialRuns: [run],
            initialProfile: RunnerProfile(
              id: 'runner_1',
              username: 'FastPace',
              totalDistanceKm: 5.0,
              xp: 250,
              level: 2,
              badges: [],
              totalHexesClaimed: 1,
              currentStreak: 1,
              faction: 'Cyber Vanguard',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('No runs in range'), findsNothing);
      expect(find.text('Closed loop'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(
        find.text('0.01 km²'),
        findsNWidgets(2),
      ); // Total area & biggest capture
      expect(
        find.text('5\'00"'),
        findsOneWidget,
      ); // 1500s / 5km = 300s/km -> 5'00"
    });
  });
}
