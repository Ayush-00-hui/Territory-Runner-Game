import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:territory_runner/features/map/widgets/run_countdown_overlay.dart';
import 'package:territory_runner/features/map/widgets/run_hud.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences();
    await prefs.init();
    // Turn countdown voice setting off so no audio plugin is touched
    await prefs.toggleCountdownVoice(false);
  });

  group(
    'Run Start Countdown, Step Display, Haptics & Intro Animation Tests',
    () {
      testWidgets('Countdown shows 3, 2, 1 and calls onComplete at 3s', (
        tester,
      ) async {
        bool completed = false;
        bool cancelled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: RunCountdownOverlay(
                onComplete: () => completed = true,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        );

        // Initial state: shows 3
        expect(find.text('GET READY'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Tap anywhere to cancel'), findsOneWidget);
        expect(completed, isFalse);

        // Advance 1 second -> shows 2
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('2'), findsOneWidget);
        expect(completed, isFalse);

        // Advance 1 second -> shows 1
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1'), findsOneWidget);
        expect(completed, isFalse);

        // Advance 1 second (total 3s) -> completes
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));
        expect(completed, isTrue);
        expect(cancelled, isFalse);
      });

      testWidgets('Tapping countdown cancels and never completes', (
        tester,
      ) async {
        bool completed = false;
        bool cancelled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: RunCountdownOverlay(
                onComplete: () => completed = true,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        );

        expect(find.text('3'), findsOneWidget);

        // Tap to cancel
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(cancelled, isTrue);
        expect(completed, isFalse);

        // Advance time further to ensure complete is never invoked
        await tester.pump(const Duration(seconds: 4));
        expect(completed, isFalse);
      });

      testWidgets('RunHud shows "1,234 steps" when stepCount is 1234', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RunHud(
                  isRunActive: true,
                  isAutoPaused: false,
                  stepCount: 1234,
                  distanceKm: 1.30,
                  elapsedSeconds: 300,
                  movingSeconds: 290,
                  splitPace: "5'20\"",
                  currentSpeedKmh: 9.5,
                  territoriesClaimed: 2,
                  satelliteAccuracyMeters: 4.5,
                  onToggleRun: () {},
                  onSealShape: () {},
                  onFinishRun: () {},
                ),
              ),
            ),
          ),
        );

        // Verify formatted thousands separator step count
        expect(find.text('1,234 steps'), findsOneWidget);

        // Verify walking icon
        expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);

        // Verify accessibility label saying "estimated"
        final semanticsFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'estimated',
        );
        expect(semanticsFinder, findsOneWidget);

        // Verify shortened territories label ("2 claimed")
        expect(find.text('2 claimed'), findsOneWidget);
      });

      test('selectionTick, lightTick and mediumTick send no platform haptic calls; heavyBurst sends one, and none when hapticsEnabled is false', () async {
        final List<MethodCall> hapticCalls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall call,
            ) async {
              if (call.method == 'HapticFeedback.vibrate') {
                hapticCalls.add(call);
              }
              return null;
            });

        hapticCalls.clear();

        // selectionTick, lightTick, mediumTick must be no-ops
        AppMotion.selectionTick();
        AppMotion.lightTick();
        AppMotion.mediumTick();

        expect(
          hapticCalls,
          isEmpty,
          reason: 'selectionTick, lightTick, mediumTick should be no-ops',
        );

        // heavyBurst sends one when hapticsEnabled is true
        AppMotion.hapticsEnabled = true;
        AppMotion.heavyBurst();
        expect(
          hapticCalls.length,
          1,
          reason: 'heavyBurst should vibrate once when enabled',
        );

        // heavyBurst sends none when hapticsEnabled is false
        AppMotion.hapticsEnabled = false;
        AppMotion.heavyBurst();
        expect(
          hapticCalls.length,
          1,
          reason: 'heavyBurst should not vibrate when disabled',
        );

        // Restore
        AppMotion.hapticsEnabled = true;
      });

      testWidgets('The intro plays then reveals the child', (tester) async {
        AppIntroGate.resetForTesting();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AppIntroGate(
                key: ValueKey('intro_play'),
                child: Text('CHILD_CONTENT'),
              ),
            ),
          ),
        );

        // Initially overlay is shown
        expect(find.byType(CustomPaint), findsWidgets);

        // Advance through 2.6s animation scene
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('TERRITORY RUNNER'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();

        // Child is fully revealed
        expect(find.text('CHILD_CONTENT'), findsOneWidget);
      });

      testWidgets('Tap skips the intro immediately', (tester) async {
        AppIntroGate.resetForTesting();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AppIntroGate(
                key: ValueKey('intro_skip'),
                child: Text('CHILD_CONTENT_2'),
              ),
            ),
          ),
        );

        // Tap immediately
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        // Child is immediately revealed
        expect(find.text('CHILD_CONTENT_2'), findsOneWidget);
      });
    },
  );
}
