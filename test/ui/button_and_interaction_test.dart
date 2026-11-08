import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  group('Phase U1: Button Family & Interaction Consistency Tests', () {
    testWidgets(
      'PrimaryButton enforces >= 48dp touch target and debounces rapid double-taps',
      (tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PrimaryButton(
                  label: 'Start Run',
                  debounce: true,
                  onPressed: () {
                    tapCount++;
                  },
                ),
              ),
            ),
          ),
        );

        final buttonFinder = find.byType(PrimaryButton);
        final size = tester.getSize(buttonFinder);
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'Touch target height must be at least 48 dp',
        );

        var testTime = DateTime(2026, 1, 1, 12, 0, 0);
        PrimaryButton.clock = () => testTime;

        // Tap once
        await tester.tap(buttonFinder);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tapCount, equals(1));

        // Rapid second tap within 100ms should be debounced
        testTime = testTime.add(const Duration(milliseconds: 100));
        await tester.tap(buttonFinder);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tapCount,
          equals(1),
          reason:
              'Rapid double tap must be debounced to prevent duplicate actions',
        );

        // Advance time past debounce threshold (400ms) and tap again
        testTime = testTime.add(const Duration(milliseconds: 500));
        await tester.tap(buttonFinder);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tapCount, equals(2));

        // Restore clock
        PrimaryButton.clock = DateTime.now;
      },
    );

    testWidgets(
      'Disabled PrimaryButton invokes onDisabledTap or disabledReason',
      (tester) async {
        bool disabledTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PrimaryButton(
                  label: 'Sync Pending',
                  onPressed: null, // Disabled
                  disabledReason: 'No internet connection',
                  onDisabledTap: () {
                    disabledTapped = true;
                  },
                ),
              ),
            ),
          ),
        );

        final buttonFinder = find.byType(PrimaryButton);
        await tester.tap(buttonFinder);
        await tester.pump();

        expect(
          disabledTapped,
          isTrue,
          reason: 'Tapping a disabled control should explain why to the user',
        );
      },
    );

    testWidgets(
      'SecondaryButton enforces >= 48dp touch target and debounces rapid double-taps',
      (tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SecondaryButton(
                  label: 'Export Route',
                  debounce: true,
                  onPressed: () {
                    tapCount++;
                  },
                ),
              ),
            ),
          ),
        );

        final buttonFinder = find.byType(SecondaryButton);
        final size = tester.getSize(buttonFinder);
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'Touch target height must be at least 48 dp',
        );

        // First tap
        await tester.tap(buttonFinder);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tapCount, equals(1));

        // Rapid second tap debounced
        await tester.tap(buttonFinder);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tapCount, equals(1));
      },
    );

    testWidgets(
      'AppChip provides >= 48dp interactive touch target bounding box',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppChip(
                  label: 'Loop Only',
                  isSelected: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        final chipFinder = find.byType(AppChip);
        final size = tester.getSize(chipFinder);
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: 'Interactive chip touch target height must be at least 48 dp',
        );
      },
    );

    testWidgets(
      'AppToast uses dynamic bottomOffset to position above bottom navigation',
      (tester) async {
        AppToast.bottomOffset = 80.0;

        await tester.pumpWidget(
          MaterialApp(
            scaffoldMessengerKey: AppToast.messengerKey,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        AppToast.show(context, 'Territory loop saved');
                      },
                      child: const Text('Show Toast'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Show Toast'));
        await tester.pump(); // Render SnackBar

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);

        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        final margin = snackBar.margin as EdgeInsets;
        expect(
          margin.bottom,
          equals(80.0),
          reason:
              'Toast must float comfortably above the bottom navigation bar',
        );

        // Clean up
        AppToast.bottomOffset = 0.0;
      },
    );
  });
}
