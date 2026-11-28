import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/auth/widgets/country_code_picker.dart';
import 'package:territory_runner/features/auth/widgets/otp_pin_input_view.dart';
import 'package:territory_runner/features/map/controllers/map_run_controller.dart';
import 'package:territory_runner/features/map/widgets/ghost_duel_hud.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/services/biometric_auth_service.dart';
import 'package:territory_runner/services/ghost_runner_service.dart';
import 'package:territory_runner/services/safety_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Athlete Feature Suite Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BiometricAuthService preference persistence', () async {
      final bio = BiometricAuthService();
      await bio.initialize();
      expect(bio.isEnabled, false);

      await bio.setEnabled(true);
      expect(bio.isEnabled, true);

      // Re-initialize to verify persistence
      await bio.initialize();
      expect(bio.isEnabled, true);

      await bio.setEnabled(false);
      expect(bio.isEnabled, false);
    });

    test('AthletePhoneInputFormatter groups digits cleanly', () {
      final formatter = AthletePhoneInputFormatter();

      // Test 5 digits
      var val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '89200'),
      );
      expect(val.text, '89200');

      // Test 10 digits
      val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '8920047823'),
      );
      expect(val.text, '89200 47823');

      // Test with non-digits
      val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '892-00 478-23'),
      );
      expect(val.text, '89200 47823');
    });

    test(
      'CountryCodeItem list contains essential athletic running regions',
      () {
        expect(kSupportedCountryCodes.isNotEmpty, true);
        final india = kSupportedCountryCodes.firstWhere(
          (c) => c.isoCode == 'IN',
        );
        expect(india.dialCode, '+91');
        expect(india.flagEmoji, '🇮🇳');

        final us = kSupportedCountryCodes.firstWhere((c) => c.isoCode == 'US');
        expect(us.dialCode, '+1');
        expect(us.flagEmoji, '🇺🇸');

        final kenya = kSupportedCountryCodes.firstWhere(
          (c) => c.isoCode == 'KE',
        );
        expect(kenya.dialCode, '+254');
        expect(kenya.flagEmoji, '🇰🇪');
      },
    );

    testWidgets('OtpPinInputView renders 6 digit input boxes and countdown', (
      tester,
    ) async {
      String enteredPin = '';
      bool resendTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpPinInputView(
              formattedPhone: '+91 89200 47823',
              resendTimeoutSeconds: 5,
              onCompleted: (pin) => enteredPin = pin,
              onResend: () => resendTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Enter Verification Code'), findsOneWidget);
      expect(find.text('6-digit code sent to +91 89200 47823'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Resend code in 5s'), findsOneWidget);

      // Fast-forward timer by 5 seconds
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Resend OTP'), findsOneWidget);

      await tester.tap(find.text('Resend OTP'));
      await tester.pump();
      expect(resendTapped, true);

      // Enter digits into each text field
      for (int i = 0; i < 6; i++) {
        await tester.enterText(find.byType(TextField).at(i), '${i + 1}');
        await tester.pump();
      }
      expect(enteredPin, '123456');
    });

    testWidgets(
      'GhostDuelHud hides when inactive and renders delta when active',
      (tester) async {
        final controller = MapRunController();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: GhostDuelHud(controller: controller)),
          ),
        );

        // Inactive initially -> empty SizedBox
        expect(find.textContaining('GHOST DUEL'), findsNothing);

        // Set ghost selection
        final sampleGhostRun = RunLogEntry(
          id: 'ghost_run_1',
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
          endedAt: DateTime.now(),
          totalSeconds: 300,
          movingSeconds: 280,
          distanceM: 1000.0,
          activityType: 'running',
          samples: const [],
        );

        controller.setGhostSelection(
          GhostSelectionResult(
            mode: GhostMode.personalBestActivity,
            matchedRun: sampleGhostRun,
          ),
        );

        controller.ghostTelemetryNotifier.value = const GhostTelemetry(
          ghostElapsedSeconds: 60,
          ghostTotalSeconds: 300,
          runnerProgressDistanceM: 250.0,
          runnerCrossTrackErrorM: 2.0,
          deltaSeconds: -15,
          statusText: '15 s ahead',
          isOffRoute: false,
          isGhostFinished: false,
          isRunnerAhead: true,
        );

        await tester.pump();

        expect(find.textContaining('GHOST DUEL'), findsOneWidget);
        expect(find.text('15 s ahead'), findsOneWidget);
        expect(find.text('Distance: 0.25 km'), findsOneWidget);

        controller.dispose();
      },
    );

    test('SafetyService WhatsApp distress URI building', () async {
      final safety = SafetyService();
      await safety.loadSettings();

      // Without contact configured
      final resultNoContact = await safety.sendWhatsAppDistress(
        position: const LatLng(28.6139, 77.2090),
      );
      expect(resultNoContact, false);

      // With contact configured
      await safety.saveSettings(
        phone: '+91 98765 43210',
        name: 'Emergency Responder',
        message: 'Emergency! I need assistance at my location:',
      );

      expect(safety.hasContactConfigured, true);
      expect(safety.contactPhone, '+91 98765 43210');
    });
  });
}
