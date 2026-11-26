import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/map/controllers/map_run_controller.dart';
import 'package:territory_runner/features/map/widgets/map_floating_controls.dart';
import 'package:territory_runner/features/map/widgets/map_controls_rail.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  group('Phase M: Camera Follow & Recenter Mechanics Tests', () {
    test(
      'MapRunController defaults to camera follow locked and updates state',
      () {
        final controller = MapRunController();
        expect(controller.isCameraFollowLocked, isTrue);

        bool notified = false;
        controller.addListener(() => notified = true);

        controller.setCameraFollow(false);
        expect(controller.isCameraFollowLocked, isFalse);
        expect(notified, isTrue);

        controller.setCameraFollow(true);
        expect(controller.isCameraFollowLocked, isTrue);
      },
    );

    testWidgets(
      'MapFloatingControls shows prominent Recenter pill when camera follow is unlocked',
      (tester) async {
        bool recenterCalled = false;

        // 1. Camera is locked (following runner) -> prominent Recenter button is NOT shown
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MapFloatingControls(
                isLeftHanded: false,
                bottomOffset: 100.0,
                isCameraLocked: true,
                onOpenTools: () {},
                onOpenLayers: () {},
                onRecenter: () => recenterCalled = true,
                onTriggerSos: () {},
              ),
            ),
          ),
        );

        expect(find.text('Recenter'), findsNothing);

        // 2. Camera is unlocked (user panned) -> prominent Recenter button appears
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MapFloatingControls(
                isLeftHanded: false,
                bottomOffset: 100.0,
                isCameraLocked: false,
                onOpenTools: () {},
                onOpenLayers: () {},
                onRecenter: () => recenterCalled = true,
                onTriggerSos: () {},
              ),
            ),
          ),
        );

        final recenterPillFinder = find.text('Recenter');
        expect(recenterPillFinder, findsOneWidget);

        // 3. Tapping Recenter triggers onRecenter callback
        await tester.tap(recenterPillFinder);
        await tester.pump();
        expect(recenterCalled, isTrue);
      },
    );

    testWidgets(
      'MapControlsRail highlights recenter action icon when camera is unlocked',
      (tester) async {
        bool recenterCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MapControlsRail(
                isCameraLocked: false,
                onOpenTools: () {},
                onOpenLayers: () {},
                onRecenter: () => recenterCalled = true,
              ),
            ),
          ),
        );

        final btnFinder = find.byTooltip('Recenter map');
        expect(btnFinder, findsOneWidget);

        await tester.tap(btnFinder);
        await tester.pump();
        expect(recenterCalled, isTrue);
      },
    );
  });
}
