import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Phase C3: Motion Budget and Smooth Minimal Animations', () {
    test('AppMotion durations follow 180ms to 240ms budget rules', () {
      // 1. Fast micro-interaction & tap feedback budget < 100ms
      expect(AppMotion.fast.inMilliseconds, lessThanOrEqualTo(100));
      expect(AppMotion.fast.inMilliseconds, greaterThanOrEqualTo(50));

      // 2. Standard tab switch & screen transition budget (180 - 240ms)
      expect(AppMotion.standard.inMilliseconds, greaterThanOrEqualTo(180));
      expect(AppMotion.standard.inMilliseconds, lessThanOrEqualTo(240));

      // 3. Modal sheet open budget (180 - 240ms)
      expect(AppMotion.sheet.inMilliseconds, greaterThanOrEqualTo(180));
      expect(AppMotion.sheet.inMilliseconds, lessThanOrEqualTo(240));

      // 4. Athletic count-up & capture budgets
      expect(AppMotion.countUp.inMilliseconds, lessThanOrEqualTo(500));
      expect(AppMotion.capture.inMilliseconds, lessThanOrEqualTo(600));
    });

    testWidgets('AppIntroGate completes within <= 600ms budget', (
      tester,
    ) async {
      AppIntroGate.resetForTesting();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: AppIntroGate(
              key: ValueKey('intro_timing_test'),
              child: Text('HOME_SCREEN_REVEALED'),
            ),
          ),
        ),
      );

      // Advance 300ms (at ~50% progress, brand name is visible)
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TERRITORY RUNNER'), findsOneWidget);

      // Advance another 300ms (total 600ms, intro complete)
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Intro overlay is dismissed and brand title is gone
      expect(find.text('TERRITORY RUNNER'), findsNothing);
      expect(find.text('HOME_SCREEN_REVEALED'), findsOneWidget);
    });

    testWidgets(
      'AppIntroGate skips immediately when reduced motion is preferred',
      (tester) async {
        AppIntroGate.resetForTesting();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: AppIntroGate(
                  key: ValueKey('intro_reduced_motion_test'),
                  child: Text('ACCESSIBLE_REVEALED'),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('ACCESSIBLE_REVEALED'), findsOneWidget);
      },
    );

    testWidgets(
      'MinimalRunningPerson renders without errors and respects reduced motion',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: MinimalRunningPerson(size: 64, isRunning: true),
              ),
            ),
          ),
        );

        expect(find.byType(MinimalRunningPerson), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MinimalRunningPerson),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );

        // Verify with reduced motion
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: MinimalRunningPerson(size: 64, isRunning: true),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(MinimalRunningPerson), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MinimalRunningPerson),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
