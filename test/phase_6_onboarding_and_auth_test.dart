import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/auth/auth_screen.dart';
import 'package:territory_runner/features/onboarding/onboarding_screen.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('hive_auth_test_');
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 6: OnboardingScreen Tests', () {
    testWidgets(
      'OnboardingScreen renders Slide 1 initial state and advances to Slide 2 & 3',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        bool completed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: OnboardingScreen(
              autoAnimate: false,
              onCompleted: () => completed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Slide 1
        expect(find.text('TERRITORY RUNNER'), findsOneWidget);
        expect(find.text('01 / CONQUEST MECHANICS'), findsOneWidget);
        expect(find.text('Run & Claim Real-World Sectors'), findsOneWidget);
        expect(find.text('SECTOR #042 CLAIMED • 14,250 m²'), findsOneWidget);
        expect(find.text('SKIP'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);

        // Tap Next to advance to Slide 2
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Verify Slide 2
        expect(find.text('02 / RIVALRY & DEFENSE'), findsOneWidget);
        expect(find.text('Defend & Compete in Real-Time'), findsOneWidget);
        expect(
          find.text('TACTICAL RADAR ACTIVE • 3 RIVALS NEARBY'),
          findsOneWidget,
        );
        expect(find.text('Previous'), findsOneWidget);

        // Tap Next to advance to Slide 3
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Verify Slide 3
        expect(find.text('03 / TACTICAL TELEMETRY'), findsOneWidget);
        expect(find.text('Sub-Meter Precision & AI Coaching'), findsOneWidget);
        expect(find.text('Get Started • Enter The Grid'), findsOneWidget);

        // Tap Get Started
        await tester.tap(find.text('Get Started • Enter The Grid'));
        await tester.pumpAndSettle();

        expect(completed, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(OnboardingScreen.prefsKeyCompleted), isTrue);
      },
    );

    testWidgets(
      'OnboardingScreen Skip button immediately triggers completion and writes prefs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        bool completed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: OnboardingScreen(
              autoAnimate: false,
              onCompleted: () => completed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap SKIP
        await tester.tap(find.text('SKIP'));
        await tester.pumpAndSettle();

        expect(completed, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(OnboardingScreen.prefsKeyCompleted), isTrue);
      },
    );

    testWidgets(
      'OnboardingScreen Previous button navigates back to preceding slide',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: OnboardingScreen(autoAnimate: false, onCompleted: () {}),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to Slide 2
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('02 / RIVALRY & DEFENSE'), findsOneWidget);

        // Tap Previous
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();
        expect(find.text('01 / CONQUEST MECHANICS'), findsOneWidget);
      },
    );
  });

  group('Phase 6: PermissionPrimerSheet Tests', () {
    testWidgets(
      'Location permission primer renders satellite precision content',
      (WidgetTester tester) async {
        bool accepted = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: PermissionPrimerSheet.location(
                onAccept: () => accepted = true,
              ),
            ),
          ),
        );

        expect(find.text('HIGH-PRECISION SATELLITE GPS'), findsOneWidget);
        expect(find.text('TERRITORY LOCK & ENCLOSURE'), findsOneWidget);
        expect(find.text('Sub-Meter Loop Enclosure'), findsOneWidget);
        expect(find.text('Real-Time Pace & Telemetry'), findsOneWidget);
        expect(find.text('Strict Athlete Privacy'), findsOneWidget);
        expect(find.text('GRANT GPS ACCESS'), findsOneWidget);
        expect(find.text('MAYBE LATER'), findsOneWidget);

        await tester.tap(find.text('GRANT GPS ACCESS'));
        await tester.pumpAndSettle();

        expect(accepted, isTrue);
      },
    );

    testWidgets(
      'Background location permission primer renders locked-screen sensing content',
      (WidgetTester tester) async {
        bool declined = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: PermissionPrimerSheet.backgroundLocation(
                onDecline: () => declined = true,
              ),
            ),
          ),
        );

        expect(find.text('BACKGROUND TRACKING SENSING'), findsOneWidget);
        expect(find.text('CONTINUOUS ENCLOSURE RADAR'), findsOneWidget);
        expect(find.text('Locked-Screen Run Capture'), findsOneWidget);
        expect(find.text('AMOLED Minimalist Display'), findsOneWidget);
        expect(find.text('ALLOW ALL-TIME GPS'), findsOneWidget);

        await tester.tap(find.text('MAYBE LATER'));
        await tester.pumpAndSettle();

        expect(declined, isTrue);
      },
    );

    testWidgets(
      'Static helper PermissionPrimerSheet.show presents and returns result',
      (WidgetTester tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      dialogResult = await PermissionPrimerSheet.show(
                        context,
                        type: PermissionPrimerType.location,
                      );
                    },
                    child: const Text('OPEN'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();

        expect(find.text('HIGH-PRECISION SATELLITE GPS'), findsOneWidget);

        await tester.tap(find.text('GRANT GPS ACCESS'));
        await tester.pumpAndSettle();

        expect(dialogResult, isTrue);
      },
    );
  });

  group('Phase 6: AuthScreen Redesign Tests', () {
    testWidgets(
      'AuthScreen renders brand header, tabs, and switches between One-Tap, Email, Phone',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: AuthScreen(onAuthenticated: () {}),
          ),
        );

        // Verify brand header & title
        expect(find.text('TERRITORY RUNNER'), findsOneWidget);
        expect(find.text('Athlete Access'), findsOneWidget);
        expect(find.text('One-Tap'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Phone OTP'), findsOneWidget);

        // Initial tab is One-Tap
        expect(find.text('Instant Google Sign-In'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);

        // Switch to Email Tab
        await tester.tap(find.text('Email'));
        await tester.pumpAndSettle();

        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Password (min 6 characters)'), findsOneWidget);
        expect(find.text('Log In with Email'), findsOneWidget);
        expect(
          find.text('New to Territory Runner? Create Account'),
          findsOneWidget,
        );

        // Switch to Sign Up mode
        await tester.tap(find.text('New to Territory Runner? Create Account'));
        await tester.pumpAndSettle();

        expect(find.text('Athlete Callsign / Name'), findsOneWidget);
        expect(find.text('Create Athlete Account'), findsOneWidget);

        // Switch to Phone OTP Tab
        await tester.tap(find.text('Phone OTP'));
        await tester.pumpAndSettle();

        expect(find.text('Phone Number'), findsOneWidget);
        expect(find.text('Send SMS OTP Code'), findsOneWidget);
      },
    );

    testWidgets(
      'AuthScreen Email validation triggers error notice on empty fields',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: AuthScreen(onAuthenticated: () {}),
          ),
        );

        // Switch to Email tab
        await tester.tap(find.text('Email'));
        await tester.pumpAndSettle();

        // Tap Log In with empty fields
        await tester.tap(find.text('Log In with Email'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter both email and password.'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'AuthScreen Continue as Guest triggers onAuthenticated callback',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        bool authenticated = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: AuthScreen(onAuthenticated: () => authenticated = true),
          ),
        );

        expect(find.text('Continue as Guest (Instant Play)'), findsOneWidget);

        await tester.ensureVisible(
          find.text('Continue as Guest (Instant Play)'),
        );
        await tester.tap(find.text('Continue as Guest (Instant Play)'));
        await tester.pumpAndSettle();

        expect(authenticated, isTrue);
      },
    );
  });
}
