import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/profile/widgets/body_details_sheet.dart';
import 'package:territory_runner/models/user_body_profile.dart';
import 'package:territory_runner/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BodyDetailsSheet Widget & Privacy Tests', () {
    late AppPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = AppPreferences();
      prefs.resetForTesting();
      await prefs.init();
      await prefs.clearBodyProfile();
    });

    Widget createTestApp({
      bool isFirstRun = false,
      VoidCallback? onSaved,
      VoidCallback? onSkipped,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BodyDetailsSheet.show(
                context: context,
                isFirstRun: isFirstRun,
                onSaved: onSaved,
                onSkipped: onSkipped,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'First-run mode displays DPDP notice, Save and start, and Skip for now',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestApp(isFirstRun: true));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Verify privacy notice is prominently visible
        expect(
          find.textContaining('Used on this phone to estimate calories'),
          findsOneWidget,
        );
        expect(find.textContaining('Stored on device only'), findsOneWidget);

        // Verify buttons
        expect(find.text('Save and start'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);
      },
    );

    testWidgets(
      'Skipping first-run triggers callback and sets skip flag without blocking',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool skippedCalled = false;
        await tester.pumpWidget(
          createTestApp(
            isFirstRun: true,
            onSkipped: () => skippedCalled = true,
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        expect(skippedCalled, isTrue);
        expect(prefs.hasSkippedBodyDetails, isTrue);
        expect(prefs.hasBodyProfile, isFalse);
      },
    );

    testWidgets(
      'Validation blocks invalid weight and height inputs with inline calm errors',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestApp(isFirstRun: false));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Enter weight below minimum 25 kg
        final weightField = find.widgetWithText(TextField, 'e.g. 70.0');
        await tester.enterText(weightField, '15');

        // Enter height above maximum 230 cm
        final heightField = find.widgetWithText(TextField, 'e.g. 175');
        await tester.enterText(heightField, '250');

        await tester.tap(find.text('Save details'));
        await tester.pumpAndSettle();

        // Inline error messages shown
        expect(
          find.text('Weight must be between 25 and 250 kg'),
          findsOneWidget,
        );
        expect(
          find.text('Height must be between 100 and 230 cm'),
          findsOneWidget,
        );
        expect(prefs.hasBodyProfile, isFalse);
      },
    );

    testWidgets(
      'Valid inputs save to device storage and update AppPreferences',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool savedCalled = false;
        await tester.pumpWidget(
          createTestApp(isFirstRun: true, onSaved: () => savedCalled = true),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final weightField = find.widgetWithText(TextField, 'e.g. 70.0');
        await tester.enterText(weightField, '72.5');

        final heightField = find.widgetWithText(TextField, 'e.g. 175');
        await tester.enterText(heightField, '178');

        // Select female gender chip
        await tester.tap(find.text('Female'));
        await tester.pump();

        // Enter birth year
        final birthYearField = find.widgetWithText(
          TextField,
          'e.g. 1996 (or age e.g. 28)',
        );
        await tester.enterText(birthYearField, '1995');

        await tester.tap(find.text('Save and start'));
        await tester.pumpAndSettle();

        expect(savedCalled, isTrue);
        expect(prefs.hasBodyProfile, isTrue);
        expect(prefs.bodyProfile?.weightKg, equals(72.5));
        expect(prefs.bodyProfile?.heightCm, equals(178.0));
        expect(prefs.bodyProfile?.gender, equals(Gender.female));
        expect(prefs.bodyProfile?.birthYear, equals(1995));
      },
    );

    testWidgets(
      'Edit mode allows clearing details via "Remove my body details"',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await prefs.setBodyProfile(
          const UserBodyProfile(
            weightKg: 65.0,
            heightCm: 168.0,
            gender: Gender.male,
            isCustomized: true,
          ),
        );

        await tester.pumpWidget(createTestApp(isFirstRun: false));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // "Remove my body details" should be visible in edit mode when a profile exists
        final removeBtn = find.text('Remove my body details');
        expect(removeBtn, findsOneWidget);

        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        expect(prefs.hasBodyProfile, isFalse);
        expect(prefs.bodyProfile, isNull);
      },
    );
  });
}
