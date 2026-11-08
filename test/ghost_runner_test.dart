import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/ghost_runner_service.dart';
import 'package:territory_runner/features/map/widgets/ghost_runner_marker.dart';
import 'package:territory_runner/features/map/widgets/ghost_runner_picker_sheet.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/features/map/widgets/summary_sheet.dart';
import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/ui/theme/app_theme.dart';

void main() {
  group('Task F3: GhostRunnerService Pure Engine Tests', () {
    late GhostRunnerService service;

    setUp(() {
      service = GhostRunnerService();
    });

    // Helper to synthesize a rectangular loop of ~1000m perimeter
    // Starting at (12.9716, 77.5946)
    List<RunSample> buildTestLoopSamples({
      required int totalDurationSeconds,
      double latOffset = 0.0,
      double lngOffset = 0.0,
    }) {
      const baseLat = 12.9716;
      const baseLng = 77.5946;

      final waypoints = [
        LatLng(baseLat + latOffset, baseLng + lngOffset),
        LatLng(baseLat + latOffset + 0.002, baseLng + lngOffset),
        LatLng(baseLat + latOffset + 0.002, baseLng + lngOffset + 0.002),
        LatLng(baseLat + latOffset, baseLng + lngOffset + 0.002),
        LatLng(baseLat + latOffset, baseLng + lngOffset),
      ];

      final samples = <RunSample>[];
      for (int i = 0; i < waypoints.length; i++) {
        final tMs =
            ((totalDurationSeconds * 1000) * (i / (waypoints.length - 1)))
                .round();
        samples.add(
          RunSample(
            timeOffsetMs: tMs,
            lat: waypoints[i].latitude,
            lng: waypoints[i].longitude,
            altitude: 900.0,
            accuracy: 4.0,
          ),
        );
      }
      return samples;
    }

    RunLogEntry buildRunEntry({
      required String id,
      required DateTime startedAt,
      required int durationSeconds,
      double distanceM = 1000.0,
      String activityType = 'running',
      List<RunSample>? samples,
    }) {
      final s =
          samples ??
          buildTestLoopSamples(totalDurationSeconds: durationSeconds);
      return RunLogEntry(
        id: id,
        startedAt: startedAt,
        endedAt: startedAt.add(Duration(seconds: durationSeconds)),
        activityType: activityType,
        movingSeconds: durationSeconds,
        totalSeconds: durationSeconds,
        distanceM: distanceM,
        samples: s,
      );
    }

    test('Empty state: returns calm explanation when no runs exist', () {
      final result = service.selectGhostRun(
        mode: GhostMode.lastOnLoop,
        origin: const LatLng(12.9716, 77.5946),
        overrideRuns: [],
      );

      expect(result.isMatch, isFalse);
      expect(result.calmExplanation, contains('No completed runs found'));
    });

    test('Mode off: returns disabled result', () {
      final result = service.selectGhostRun(
        mode: GhostMode.off,
        origin: const LatLng(12.9716, 77.5946),
      );

      expect(result.mode, GhostMode.off);
      expect(result.isMatch, isFalse);
    });

    test('Personal best selection: picks fastest pace across activity regardless of origin', () {
      final run1 = buildRunEntry(
        id: 'run-1',
        startedAt: DateTime(2026, 11, 1),
        durationSeconds: 360, // 6:00/km
        distanceM: 1000.0,
      );
      final run2 = buildRunEntry(
        id: 'run-2',
        startedAt: DateTime(2026, 11, 2),
        durationSeconds: 300, // 5:00/km (Fastest PR)
        distanceM: 1000.0,
      );
      final run3 = buildRunEntry(
        id: 'run-3',
        startedAt: DateTime(2026, 11, 3),
        durationSeconds: 420, // 7:00/km
        distanceM: 1000.0,
      );

      final result = service.selectGhostRun(
        mode: GhostMode.personalBestActivity,
        origin: const LatLng(0, 0), // far away origin
        overrideRuns: [run1, run2, run3],
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedRun?.id, 'run-2');
    });

    test('Last run on loop: selects most recent run starting within 50m', () {
      final origin = const LatLng(12.9716, 77.5946);
      final olderRun = buildRunEntry(
        id: 'older-run',
        startedAt: DateTime(2026, 11, 1, 8, 0),
        durationSeconds: 320,
      );
      final newerRun = buildRunEntry(
        id: 'newer-run',
        startedAt: DateTime(2026, 11, 5, 8, 0),
        durationSeconds: 340,
      );
      // Run starting far away (> 50m)
      final farRun = buildRunEntry(
        id: 'far-run',
        startedAt: DateTime(2026, 11, 6, 8, 0),
        durationSeconds: 280,
        samples: buildTestLoopSamples(
          totalDurationSeconds: 280,
          latOffset: 0.01, // ~1.1km away
        ),
      );

      final result = service.selectGhostRun(
        mode: GhostMode.lastOnLoop,
        origin: origin,
        overrideRuns: [olderRun, newerRun, farRun],
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedRun?.id, 'newer-run');
    });

    test('Best run on loop: selects fastest among matching loops and rejects distant routes', () {
      final origin = const LatLng(12.9716, 77.5946);
      // Run starting nearby on an earlier date but running completely different direction (Fréchet > 45m)
      final differentLoop = buildRunEntry(
        id: 'diff-loop',
        startedAt: DateTime(2026, 11, 1),
        durationSeconds: 200,
        samples: [
          const RunSample(timeOffsetMs: 0, lat: 12.9716, lng: 77.5946),
          const RunSample(timeOffsetMs: 100000, lat: 12.9650, lng: 77.5850),
          const RunSample(timeOffsetMs: 200000, lat: 12.9716, lng: 77.5946),
        ],
      );
      final loopNormal = buildRunEntry(
        id: 'loop-normal',
        startedAt: DateTime(2026, 11, 2),
        durationSeconds: 350,
      );
      final loopFast = buildRunEntry(
        id: 'loop-fast',
        startedAt: DateTime(2026, 11, 3),
        durationSeconds: 290, // Fastest on same loop
      );

      final result = service.selectGhostRun(
        mode: GhostMode.bestOnLoop,
        origin: origin,
        overrideRuns: [differentLoop, loopNormal, loopFast],
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedRun?.id, 'loop-fast');
    });

    test('Discrete Fréchet Distance: zero for identical paths and high for disparate routes', () {
      final pathA = GhostRunnerService.resamplePath([
        const LatLng(12.0, 77.0),
        const LatLng(12.001, 77.001),
        const LatLng(12.002, 77.002),
      ], 100);

      final frechetSame = GhostRunnerService.computeDiscreteFrechetDistance(
        pathA,
        pathA,
      );
      expect(frechetSame, closeTo(0.0, 0.01));

      final pathB = GhostRunnerService.resamplePath([
        const LatLng(12.0, 77.0),
        const LatLng(12.005, 77.005), // large deviation (~600m)
        const LatLng(12.002, 77.002),
      ], 100);

      final frechetDiff = GhostRunnerService.computeDiscreteFrechetDistance(
        pathA,
        pathB,
      );
      expect(frechetDiff, greaterThan(100.0));
    });

    test('Progress projection and off-route threshold (>40m)', () {
      final ghostSamples = [
        const RunSample(timeOffsetMs: 0, lat: 12.9716, lng: 77.5946),
        const RunSample(
          timeOffsetMs: 100000,
          lat: 12.9716,
          lng: 77.6046,
        ), // ~1080m east
      ];

      // Runner on-route (5m south of segment)
      final onRoutePos = const LatLng(12.97155, 77.5996);
      final projOnRoute = GhostRunnerService.projectOntoGhostRoute(
        runnerPosition: onRoutePos,
        ghostSamples: ghostSamples,
      );
      expect(projOnRoute.crossTrackErrorMeters, lessThan(15.0));

      // Runner off-route (60m south of segment)
      final offRoutePos = const LatLng(12.9710, 77.5996);
      final projOffRoute = GhostRunnerService.projectOntoGhostRoute(
        runnerPosition: offRoutePos,
        ghostSamples: ghostSamples,
      );
      expect(projOffRoute.crossTrackErrorMeters, greaterThan(40.0));
    });

    test('Ahead/Behind maths: accurately computes ahead, behind, and on-pace states', () {
      final ghostRun = buildRunEntry(
        id: 'ghost-1',
        startedAt: DateTime(2026, 11, 1),
        durationSeconds: 300,
        samples: [
          const RunSample(timeOffsetMs: 0, lat: 12.9700, lng: 77.5900),
          const RunSample(
            timeOffsetMs: 100000,
            lat: 12.9700,
            lng: 77.5950,
          ), // midpoint at 100s
          const RunSample(
            timeOffsetMs: 200000,
            lat: 12.9700,
            lng: 77.6000,
          ), // end at 200s
        ],
      );

      // Midpoint coordinate
      final midPoint = const LatLng(12.9700, 77.5950);

      // 1. Runner reaches midpoint at 88 seconds (12s ahead of ghost's 100s)
      final telemAhead = service.computeTelemetry(
        ghostRun: ghostRun,
        runnerPosition: midPoint,
        runnerMovingSeconds: 88,
        runnerElapsedSeconds: 88,
      );
      expect(telemAhead.deltaSeconds, -12);
      expect(telemAhead.isRunnerAhead, isTrue);
      expect(telemAhead.statusText, '12 s ahead');

      // 2. Runner reaches midpoint at 108 seconds (8s behind ghost's 100s)
      final telemBehind = service.computeTelemetry(
        ghostRun: ghostRun,
        runnerPosition: midPoint,
        runnerMovingSeconds: 108,
        runnerElapsedSeconds: 108,
      );
      expect(telemBehind.deltaSeconds, 8);
      expect(telemBehind.isRunnerAhead, isFalse);
      expect(telemBehind.statusText, '8 s behind');

      // 3. Runner on pace (100 seconds)
      final telemOnPace = service.computeTelemetry(
        ghostRun: ghostRun,
        runnerPosition: midPoint,
        runnerMovingSeconds: 100,
        runnerElapsedSeconds: 100,
      );
      expect(telemOnPace.deltaSeconds, 0);
      expect(telemOnPace.statusText, 'On ghost pace');
    });

    test(
      'Pause handling: preserves ahead/behind delta and marks paused status',
      () {
        final ghostRun = buildRunEntry(
          id: 'ghost-1',
          startedAt: DateTime(2026, 11, 1),
          durationSeconds: 300,
          samples: [
            const RunSample(timeOffsetMs: 0, lat: 12.9700, lng: 77.5900),
            const RunSample(timeOffsetMs: 100000, lat: 12.9700, lng: 77.5950),
          ],
        );

        final telemPaused = service.computeTelemetry(
          ghostRun: ghostRun,
          runnerPosition: const LatLng(12.9700, 77.5950),
          runnerMovingSeconds: 88, // frozen moving time
          runnerElapsedSeconds: 120, // elapsed time continued
          isPaused: true,
        );

        expect(telemPaused.isPaused, isTrue);
        expect(telemPaused.deltaSeconds, -12);
        expect(telemPaused.statusText, 'Paused • 12 s ahead');
      },
    );

    test(
      'Ghost finish handling: locks to finish line when ghost completes route',
      () {
        final ghostRun = buildRunEntry(
          id: 'ghost-1',
          startedAt: DateTime(2026, 11, 1),
          durationSeconds: 100,
          samples: [
            const RunSample(timeOffsetMs: 0, lat: 12.9700, lng: 77.5900),
            const RunSample(timeOffsetMs: 100000, lat: 12.9700, lng: 77.6000),
          ],
        );

        // Runner is at 120 seconds (ghost finished at 100s)
        final telemFinished = service.computeTelemetry(
          ghostRun: ghostRun,
          runnerPosition: const LatLng(12.9700, 77.5990),
          runnerMovingSeconds: 120,
          runnerElapsedSeconds: 120,
        );

        expect(telemFinished.isGhostFinished, isTrue);
        expect(
          telemFinished.ghostPosition?.longitude,
          closeTo(77.6000, 0.0001),
        );
        expect(telemFinished.statusText, contains('Ghost finished'));
      },
    );
  });

  group('Task F3: Widget Tests', () {
    testWidgets(
      'GhostRunnerMarkerWidget renders neutral marker with dashed ring',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: GhostRunnerMarkerWidget(isBatterySaverActive: false),
              ),
            ),
          ),
        );

        expect(find.byType(GhostRunnerMarkerWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets('GhostRunnerPickerSheet displays modes and handles selection', (
      tester,
    ) async {
      GhostSelectionResult? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GhostRunnerPickerSheet(
              initialMode: GhostMode.off,
              currentLocation: const LatLng(12.9716, 77.5946),
              onGhostSelected: (res) => selected = res,
            ),
          ),
        ),
      );

      expect(find.text('Ghost runner'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Last run on this loop'), findsOneWidget);
      expect(find.text('Best run on this loop'), findsOneWidget);
      expect(find.text('Personal best for this activity'), findsOneWidget);

      // Select 'Off' and confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected?.mode, GhostMode.off);
    });

    testWidgets(
      'RunHud renders Ghost HUD chip when telemetry notifier has active ghost',
      (tester) async {
        final ghostNotifier = ValueNotifier<GhostTelemetry?>(
          const GhostTelemetry(
            ghostElapsedSeconds: 50,
            ghostTotalSeconds: 100,
            runnerProgressDistanceM: 500.0,
            runnerCrossTrackErrorM: 5.0,
            deltaSeconds: -12,
            statusText: '12 s ahead',
            isOffRoute: false,
            isGhostFinished: false,
            isRunnerAhead: true,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: RunHud(
                isRunActive: true,
                isSearchingGps: false,
                isAutoPaused: false,
                distanceKm: 0.5,
                elapsedSeconds: 50,
                movingSeconds: 50,
                splitPace: "5'00\"",
                currentSpeedKmh: 12.0,
                satelliteAccuracyMeters: 4.0,
                territoriesClaimed: 0,
                ghostTelemetryNotifier: ghostNotifier,
                onToggleRun: () {},
                onSealShape: () {},
                onFinishRun: () {},
              ),
            ),
          ),
        );

        expect(find.text('12 s ahead'), findsOneWidget);
      },
    );

    testWidgets(
      'SummarySheet displays Ghost Comparison card when ghostResult is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SummarySheet(
                distanceKm: 3.5,
                durationSeconds: 1200,
                territoriesClaimed: 1,
                profile: RunnerProfile(
                  id: 'runner-1',
                  username: 'GhostChaser',
                  level: 3,
                  totalDistanceKm: 45.0,
                  totalTerritoriesClaimed: 5,
                ),
                coachService: LLMCoachService(),
                ghostResult: 'Finished 14 s ahead of Ghost (Personal best)',
              ),
            ),
          ),
        );

        expect(
          find.text('Finished 14 s ahead of Ghost (Personal best)'),
          findsOneWidget,
        );
      },
    );
  });
}
