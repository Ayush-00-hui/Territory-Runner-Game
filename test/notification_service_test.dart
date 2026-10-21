import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/services/notification_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService & FCM Client Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'NotificationService initializes gracefully when Firebase unconfigured',
      () async {
        final service = NotificationService();
        expect(service.isFirebaseAvailable, isFalse);

        await service.initialize();
        expect(service.isInitialized, isTrue);
      },
    );

    test(
      'onAttackedTerritoryTapped stream receives simulated attack tap events',
      () async {
        final service = NotificationService();
        String? receivedTerritoryId;

        final sub = service.onAttackedTerritoryTapped.listen((id) {
          receivedTerritoryId = id;
        });

        service.simulateAttackedTerritoryTap('sector_alpha_99');
        await pumpEventQueue();

        expect(receivedTerritoryId, equals('sector_alpha_99'));
        await sub.cancel();
      },
    );

    testWidgets(
      'Permission primer bottom sheet renders radar title and action buttons',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        NotificationService().showPermissionPrimerIfNeeded(
                          context,
                          force: true,
                        );
                      },
                      child: const Text('OPEN PRIMER'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        // Tap button to open primer
        await tester.tap(find.text('OPEN PRIMER'));
        await tester.pumpAndSettle();

        // Verify sheet title and features
        expect(find.text('TACTICAL RADAR ALERTS'), findsOneWidget);
        expect(find.text('EARLY WARNING DEFENSE SYSTEM'), findsOneWidget);
        expect(find.text('Real-Time Attack Radar'), findsOneWidget);
        expect(find.text('Direct Tactical Deep-Link'), findsOneWidget);
        expect(find.text('Weekly League Cutoffs'), findsOneWidget);

        // Verify buttons
        expect(find.text('MAYBE LATER'), findsOneWidget);
        expect(find.text('ENABLE RADAR ALERTS'), findsOneWidget);

        // Tap Maybe Later to dismiss
        await tester.tap(find.text('MAYBE LATER'));
        await tester.pumpAndSettle();

        expect(find.text('TACTICAL RADAR ALERTS'), findsNothing);
      },
    );

    testWidgets('Permission primer sheet can be accepted', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      NotificationService().showPermissionPrimerIfNeeded(
                        context,
                        force: true,
                      );
                    },
                    child: const Text('OPEN PRIMER'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('OPEN PRIMER'));
      await tester.pumpAndSettle();

      // Tap ENABLE RADAR ALERTS
      await tester.tap(find.text('ENABLE RADAR ALERTS'));
      await tester.pumpAndSettle();

      expect(find.text('TACTICAL RADAR ALERTS'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('fcm_permission_prompted'), isTrue);
    });
  });
}
