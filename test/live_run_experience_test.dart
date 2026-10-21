import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/gameplay/polygon_enclosure_engine.dart';
import 'package:territory_runner/features/map/widgets/hold_to_finish_button.dart';
import 'package:territory_runner/features/map/widgets/loop_celebration_overlay.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/ui/widgets/app_toast.dart';

void main() {
  group('Phase 2 Live Run Experience Widgets', () {
    testWidgets(
      'RunHud renders distance, timer, split pace, and proximity meter',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RunHud(
                isRunActive: true,
                isAutoPaused: false,
                distanceKm: 4.82,
                elapsedSeconds: 1540,
                movingSeconds: 1500,
                splitPace: "5'12\"",
                currentSpeedKmh: 11.5,
                satelliteAccuracyMeters: 3.0,
                territoriesClaimed: 2,
                distanceToClosureMeters: 18.0,
                proximityToClosure: 0.9,
                targetPace: '5:00',
                onToggleRun: () {},
                onSealShape: () {},
                onFinishRun: () {},
              ),
            ),
          ),
        );

        expect(find.text('4.82'), findsOneWidget);
        expect(find.text("5'12\""), findsOneWidget);
        expect(find.text('25:00'), findsOneWidget);
        expect(find.text('Ready to close loop'), findsOneWidget);
        expect(find.text('18 m to start'), findsOneWidget);
        expect(find.text('Close loop'), findsOneWidget);
      },
    );

    testWidgets('HoldToFinishButton shows LOCKED when inactive', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HoldToFinishButton(isRunActive: false, onFinish: () {}),
          ),
        ),
      );

      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('HoldToFinishButton triggers finish callback when held', (
      tester,
    ) async {
      bool finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HoldToFinishButton(
              isRunActive: true,
              onFinish: () => finished = true,
            ),
          ),
        ),
      );

      expect(find.text('Hold stop'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hold stop')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Hold'), findsOneWidget);
      expect(finished, isFalse);

      await tester.pumpAndSettle();
      expect(finished, isTrue);
      await gesture.up();
      await tester.pump();
    });

    testWidgets(
      'LoopCelebrationOverlay displays territory claimed banner and XP',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LoopCelebrationOverlay(
                areaSqMeters: 12450.0,
                xpAwarded: 620,
                onDismissed: () {},
              ),
            ),
          ),
        );

        expect(find.text('+0.01 km² claimed'), findsOneWidget);
        expect(find.text('+620 XP'), findsOneWidget);
      },
    );

    testWidgets(
      'Toast is not repeated across consecutive GPS ticks with identical rejection',
      (tester) async {
        String? lastShownRejectionReason;
        int toastInvocationCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      final reason = PolygonEnclosureEngine.signalGapReason;
                      if (lastShownRejectionReason != reason) {
                        lastShownRejectionReason = reason;
                        toastInvocationCount++;
                        AppToast.show(
                          context,
                          reason,
                          type: AppToastType.warning,
                        );
                      }
                    },
                    child: const Text('Tick'),
                  );
                },
              ),
            ),
          ),
        );

        // Tap 1: First tick with rejection
        await tester.tap(find.text('Tick'));
        await tester.pump();
        expect(toastInvocationCount, equals(1));
        expect(find.byType(SnackBar), findsOneWidget);

        // Tap 2: Second consecutive tick with identical rejection
        await tester.tap(find.text('Tick'));
        await tester.pump();
        expect(
          toastInvocationCount,
          equals(1),
          reason: 'Consecutive tick with same rejection must not duplicate toast',
        );
      },
    );
  });
}
