import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/features/map/controllers/map_run_controller.dart';
import 'package:territory_runner/features/map/widgets/breathing_pace_ring.dart';
import 'package:territory_runner/features/map/widgets/kinetic_comet_puck.dart';
import 'package:territory_runner/features/map/widgets/run_flyover_sheet.dart';
import 'package:territory_runner/features/map/widgets/sweat_lock_overlay.dart';
import 'package:territory_runner/features/map/widgets/territory_bloom_overlay.dart';
import 'package:territory_runner/features/profile/widgets/gyroscopic_badge_card.dart';
import 'package:territory_runner/services/loop_closure_intent_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Athlete Motion, Animation & ML Suite Tests', () {
    test(
      'LoopClosureIntentService evaluates closure kinematics accurately',
      () {
        final service = LoopClosureIntentService();

        // Short path -> empty
        final emptyEval = service.evaluateTrajectory(
          activePath: [const LatLng(28.6139, 77.2090)],
          currentSpeedKmh: 10.0,
          totalPathDistanceM: 20.0,
        );
        expect(emptyEval.isClosingIntent, false);

        // Generating circular loop returning to origin
        final List<LatLng> loopPath = [];
        const centerLat = 28.6139;
        const centerLng = 77.2090;
        for (int i = 0; i <= 36; i++) {
          final angle = (i * 10) * (3.14159 / 180.0);
          loopPath.add(
            LatLng(
              centerLat + (0.002 * (1.0 - (1.0 * (1.0 - (angle > 0 ? 1 : 0))))),
              centerLng + (0.002 * angle),
            ),
          );
        }

        // Closing loop scenario (distance to origin < 40m)
        final closeEval = service.evaluateTrajectory(
          activePath: [
            const LatLng(28.6100, 77.2000),
            const LatLng(28.6120, 77.2000),
            const LatLng(28.6140, 77.2020),
            const LatLng(28.6140, 77.2040),
            const LatLng(28.6120, 77.2040),
            const LatLng(28.6102, 77.2001), // within 30m of start
          ],
          currentSpeedKmh: 11.5,
          totalPathDistanceM: 800.0,
        );

        expect(closeEval.isClosingIntent, true);
        expect(closeEval.closureProbability >= 0.65, true);
        expect(closeEval.distanceToOriginM < 40.0, true);
      },
    );

    testWidgets('KineticCometPuck renders pulse and adapts to velocity', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: KineticCometPuck(
                currentSpeedKmh: 15.2, // Sprint tempo
                headingDegrees: 45.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(KineticCometPuck), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(KineticCometPuck), findsOneWidget);
    });

    testWidgets(
      'TerritoryBloomOverlay animates and renders celebration stats',
      (tester) async {
        bool dismissed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TerritoryBloomOverlay(
                celebration: const TerritoryCaptureCelebration(
                  xpEarned: 250,
                  netAreaSqM: 14500.0,
                  timestamp: '2026-11-28T20:00:00Z',
                ),
                onDismissed: () => dismissed = true,
              ),
            ),
          ),
        );

        expect(find.text('TERRITORY CLAIMED'), findsOneWidget);
        expect(find.text('+250 XP • 1.45 ha'), findsOneWidget);
        expect(find.text('Loop secured on foot'), findsOneWidget);

        // Fast-forward animation to completion
        await tester.pump(const Duration(milliseconds: 3000));
        expect(dismissed, true);
      },
    );

    testWidgets(
      'SweatLockOverlay displays metrics and completes hold-to-unlock',
      (tester) async {
        final controller = MapRunController();
        bool unlocked = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: SweatLockOverlay(
              controller: controller,
              onUnlock: () => unlocked = true,
            ),
          ),
        );

        expect(find.text('SWEAT LOCK ACTIVE'), findsOneWidget);
        expect(find.text('CURRENT PACE'), findsOneWidget);
        expect(find.text('DISTANCE'), findsOneWidget);
        expect(find.text('Hold to unlock'), findsOneWidget);

        // Tap and hold
        final unlockGesture = await tester.startGesture(
          tester.getCenter(find.text('Hold to unlock')),
        );
        for (int i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await unlockGesture.up();
        await tester.pumpAndSettle();

        expect(unlocked, true);
        controller.dispose();
      },
    );

    testWidgets('BreathingPaceRing wraps child with breathing shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BreathingPaceRing(
              currentSpeedKmh: 10.5,
              child: Text('10.5 km/h'),
            ),
          ),
        ),
      );

      expect(find.text('10.5 km/h'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('10.5 km/h'), findsOneWidget);
    });

    testWidgets(
      'GyroscopicBadgeCard renders 3D medal and responds to drag pan',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: GyroscopicBadgeCard(
                  title: 'Pioneer Runner',
                  subtitle: 'First loop completed',
                  icon: Icons.emoji_events_rounded,
                  tierLabel: 'Gold',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Pioneer Runner'), findsOneWidget);
        expect(find.text('GOLD'), findsOneWidget);

        // Pan drag to tilt
        await tester.drag(find.text('Pioneer Runner'), const Offset(20, -15));
        await tester.pump();

        // Release to spring back
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Pioneer Runner'), findsOneWidget);
      },
    );

    testWidgets('RunFlyoverSheet controls speed and playback', (tester) async {
      final coords = [
        const LatLng(28.6139, 77.2090),
        const LatLng(28.6149, 77.2100),
        const LatLng(28.6159, 77.2110),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: RunFlyoverSheet(
              coordinates: coords,
              distanceKm: 1.25,
              durationSeconds: 360,
            ),
          ),
        ),
      );

      expect(find.text('ROUTE FLYOVER'), findsOneWidget);
      expect(find.text('1.25 km cinematic replay'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);

      // Tap speed multiplier
      await tester.tap(find.text('2x'));
      await tester.pump();
      expect(find.text('4x'), findsOneWidget);
    });
  });
}
