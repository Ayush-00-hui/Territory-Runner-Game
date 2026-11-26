import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/coach/pace_prediction_service.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/services/daily_quest_service.dart';
import 'package:territory_runner/services/exploration_service.dart';
import 'package:territory_runner/services/notification_service.dart';
import 'package:territory_runner/services/privacy_zone_service.dart';
import 'package:territory_runner/services/run_log_service.dart';

RunLogEntry _makeRun({
  required String id,
  required DateTime startedAt,
  double distanceM = 2500.0,
  int movingSeconds = 750,
  double claimedAreaSqM = 0.0,
  bool simulated = false,
}) {
  return RunLogEntry(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(seconds: movingSeconds)),
    movingSeconds: movingSeconds,
    totalSeconds: movingSeconds,
    distanceM: distanceM,
    samples: const [
      RunSample(timeOffsetMs: 0, lat: 28.6139, lng: 77.2090),
      RunSample(timeOffsetMs: 300000, lat: 28.6180, lng: 77.2130),
    ],
    claimedAreaSqM: claimedAreaSqM,
    simulated: simulated,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('daily_habit_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TerritoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RunnerProfileAdapter());
    }
    await Hive.openBox<Territory>('territories_v3');
    await Hive.openBox<RunnerProfile>('profile');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RunLogService streak calculation', () {
    test(
      'counts consecutive non-simulated runs >= 100m ending today or yesterday',
      () {
        final now = DateTime(2026, 11, 26, 18, 0);
        final service = RunLogService.custom();

        final runs = [
          _makeRun(
            id: 'r1',
            startedAt: DateTime(2026, 11, 26, 7, 30),
            distanceM: 3200.0,
          ),
          _makeRun(
            id: 'r2',
            startedAt: DateTime(2026, 11, 25, 19, 0),
            distanceM: 1800.0,
          ),
          _makeRun(
            id: 'r3',
            startedAt: DateTime(2026, 11, 24, 6, 45),
            distanceM: 5000.0,
          ),
          // Broken gap on Nov 23, older run on Nov 22 should not join streak
          _makeRun(
            id: 'r4',
            startedAt: DateTime(2026, 11, 22, 8, 0),
            distanceM: 4000.0,
          ),
          // Tiny jitter run or simulated run ignored
          _makeRun(
            id: 'r5',
            startedAt: DateTime(2026, 11, 23, 9, 0),
            distanceM: 60.0,
          ),
          _makeRun(
            id: 'r6',
            startedAt: DateTime(2026, 11, 23, 10, 0),
            distanceM: 5000.0,
            simulated: true,
          ),
        ];

        expect(
          service.computeActiveStreakDays(
            overrideRuns: runs,
            referenceNow: now,
          ),
          equals(3),
        );

        // Streak still alive if last valid run was yesterday
        expect(
          service.computeActiveStreakDays(
            overrideRuns: runs.sublist(1),
            referenceNow: now,
          ),
          equals(2),
        );

        // Streak resets when last run was 2+ days ago
        expect(
          service.computeActiveStreakDays(
            overrideRuns: [runs[2]],
            referenceNow: now,
          ),
          equals(0),
        );
      },
    );
  });

  group('DailyQuestService', () {
    test(
      'evaluates 3 quests and claims XP idempotently once per day',
      () async {
        final now = DateTime(2026, 11, 26, 10, 0);
        await DailyQuestService().recordNewBlocksToday(8, now: now);
        await DailyQuestService().recordDefenseToday(now: now);

        final todayRuns = [
          _makeRun(
            id: 'q1',
            startedAt: now,
            distanceM: 3600.0,
            movingSeconds: 1200,
            claimedAreaSqM: 900.0,
          ),
        ];

        final quests = await DailyQuestService().getTodayQuests(
          now: now,
          overrideRuns: todayRuns,
          totalAreaSqMeters: 12000.0,
        );
        expect(quests.length, equals(3));
        expect(quests.every((q) => q.isCompleted), isTrue);

        final beforeXp = TerritoryService().getProfile().xp;
        final claimedFirst = await DailyQuestService().claimCompletedQuests(
          now: now,
          overrideRuns: todayRuns,
          totalAreaSqMeters: 12000.0,
        );
        expect(claimedFirst.length, equals(3));

        final afterProfile = TerritoryService().getProfile();
        final expectedXp = claimedFirst.fold<int>(0, (s, q) => s + q.xpReward);
        expect(
          afterProfile.xp + (afterProfile.level - 1) * 250,
          greaterThanOrEqualTo(beforeXp + expectedXp),
        );

        // Second claim on the same day must grant zero additional XP
        final claimedSecond = await DailyQuestService().claimCompletedQuests(
          now: now,
          overrideRuns: todayRuns,
          totalAreaSqMeters: 12000.0,
        );
        expect(claimedSecond, isEmpty);
      },
    );
  });

  group(
    'ExplorationService bounding polygons & Notifications & AI target helper',
    () {
      test('getExploredCellPolygonsInBounds returns discovered blocks excluding privacy zones', () async {
        final privacy = PrivacyZoneService();
        final service = ExplorationService(privacyZoneService: privacy);
        await service.init();

        await service.recordVisitedPoints(const [
          LatLng(28.6105, 77.2105),
          LatLng(28.6115, 77.2115),
        ]);

        final inBounds = service.getExploredCellPolygonsInBounds(
          minLat: 28.6000,
          maxLat: 28.6200,
          minLng: 77.2000,
          maxLng: 77.2200,
        );
        expect(inBounds.length, greaterThanOrEqualTo(2));
        expect(inBounds.first.length, equals(4));

        final outOfBounds = service.getExploredCellPolygonsInBounds(
          minLat: 10.0,
          maxLat: 10.1,
          minLng: 10.0,
          maxLng: 10.1,
        );
        expect(outOfBounds, isEmpty);
      });

      test('NotificationService buffers cold-start defend tap and clears after consume', () {
        NotificationService().simulateAttackedTerritoryTap('terr_99');
        expect(
          NotificationService().consumePendingTerritoryId(),
          equals('terr_99'),
        );
        expect(NotificationService().consumePendingTerritoryId(), isNull);
      });

      test('PacePredictionService.pastRunsFromLog filters simulated and jitter runs chronologically', () {
        final older = _makeRun(
          id: 'p1',
          startedAt: DateTime(2026, 11, 20, 7, 0),
          distanceM: 3000.0,
          movingSeconds: 900,
        );
        final newer = _makeRun(
          id: 'p2',
          startedAt: DateTime(2026, 11, 24, 7, 0),
          distanceM: 5000.0,
          movingSeconds: 1500,
        );
        final jitter = _makeRun(
          id: 'p3',
          startedAt: DateTime(2026, 11, 25, 7, 0),
          distanceM: 120.0,
          movingSeconds: 40,
        );
        final sim = _makeRun(
          id: 'p4',
          startedAt: DateTime(2026, 11, 26, 7, 0),
          distanceM: 5000.0,
          movingSeconds: 1500,
          simulated: true,
        );

        final parsed = PacePredictionService.pastRunsFromLog([
          newer,
          jitter,
          sim,
          older,
        ]);
        expect(parsed.length, equals(2));
        expect(parsed.first.distanceKm, closeTo(3.0, 1e-6));
        expect(parsed.last.distanceKm, closeTo(5.0, 1e-6));
      });
    },
  );
}
