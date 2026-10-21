import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/ui/widgets/calm_error_screen.dart';

void main() {
  group('CalmErrorScreen Widget Tests', () {
    testWidgets('Renders calm error screen with recovery instructions', (
      tester,
    ) async {
      final details = FlutterErrorDetails(
        exception: Exception('Simulation UI render fault'),
        stack: StackTrace.current,
        library: 'widget library',
        context: ErrorDescription('while building test hierarchy'),
      );

      bool resetTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CalmErrorScreen(
            details: details,
            onReset: () {
              resetTriggered = true;
            },
          ),
        ),
      );

      expect(find.text('RUNNER INTERFACE RECOVERED'), findsOneWidget);
      expect(
        find.textContaining('Your telemetry, active GPS track'),
        findsOneWidget,
      );
      expect(find.text('RETURN TO NAVIGATION'), findsOneWidget);

      // Verify reset callback on tap
      await tester.tap(find.text('RETURN TO NAVIGATION'));
      await tester.pumpAndSettle();

      expect(resetTriggered, isTrue);
    });

    testWidgets('Toggles diagnostics disclosure drawer', (tester) async {
      final details = FlutterErrorDetails(
        exception: 'SpecificExceptionDetailsForDiagnostics',
      );

      await tester.pumpWidget(
        MaterialApp(home: CalmErrorScreen(details: details)),
      );

      // Initial state: details collapsed
      expect(
        find.textContaining('SpecificExceptionDetailsForDiagnostics'),
        findsNothing,
      );

      // Tap disclosure
      await tester.tap(find.text('Show Diagnostics (Debug Only)'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('SpecificExceptionDetailsForDiagnostics'),
        findsOneWidget,
      );
    });
  });
}
