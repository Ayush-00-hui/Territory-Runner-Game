import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/map/widgets/map_tools_sheet.dart';
import 'package:territory_runner/features/map/widgets/pacer_sheet.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/services/location_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences();
    prefs.setMockDemoState(unlocked: false, enabled: false);
    LocationService().setVirtualPacer(VirtualPacerMode.none);
  });

  group('C4 Demo Mode & Simulation Controls Tests', () {
    test('AppPreferences defaults to demo mode locked and disabled', () {
      final prefs = AppPreferences();
      expect(prefs.isDemoModeUnlocked, isFalse);
      expect(prefs.isDemoModeEnabled, isFalse);
    });

    testWidgets('MapToolsSheet hides Virtual Pacer when demo mode is OFF', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MapToolsSheet(
              isDemoMode: false,
              onOpenPacer: () {},
              onOpenGoals: () {},
              onOpenRoutePlanner: () {},
              onToggleAmoled: () {},
              onOpenOfflineMaps: () {},
              onTriggerSos: () {},
            ),
          ),
        ),
      );

      // Simulation controls must NOT be visible to regular users
      expect(find.text('Virtual pacer'), findsNothing);
      expect(find.text('Run goals'), findsOneWidget);
      expect(find.text('Route suggestions'), findsOneWidget);
      expect(find.text('Low-power display'), findsOneWidget);
      expect(find.text('Offline maps'), findsOneWidget);
      expect(find.text('Emergency SOS'), findsOneWidget);
    });

    testWidgets('MapToolsSheet reveals Virtual Pacer when demo mode is ON', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MapToolsSheet(
              isDemoMode: true,
              onOpenPacer: () {},
              onOpenGoals: () {},
              onOpenRoutePlanner: () {},
              onToggleAmoled: () {},
              onOpenOfflineMaps: () {},
              onTriggerSos: () {},
            ),
          ),
        ),
      );

      // Pacer / simulation is revealed
      expect(find.text('Virtual pacer'), findsOneWidget);
      expect(find.text('Run goals'), findsOneWidget);
    });

    testWidgets('VirtualPacerSheet hides DemoControlsLab when demo mode is OFF', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: VirtualPacerSheet(
              isDemoMode: false,
              locationService: LocationService(),
              onSimulateLoop: () {},
              onSimulateRivalCut: () {},
              onSimulateAnomaly: () {},
              onSimulateCoachDebrief: () {},
              onSimulateDecayAndAttack: () {},
            ),
          ),
        ),
      );

      expect(find.text('Classroom & viva demo lab'), findsNothing);
      expect(find.text('Auto-simulate 400m loop'), findsNothing);
      expect(find.text('Auto-simulate rival territory cut'), findsNothing);
    });

    testWidgets('VirtualPacerSheet displays DemoControlsLab when demo mode is ON', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: VirtualPacerSheet(
              isDemoMode: true,
              locationService: LocationService(),
              onSimulateLoop: () {},
              onSimulateRivalCut: () {},
              onSimulateAnomaly: () {},
              onSimulateCoachDebrief: () {},
              onSimulateDecayAndAttack: () {},
            ),
          ),
        ),
      );

      expect(find.text('Classroom & viva demo lab'), findsOneWidget);
      expect(find.text('Auto-simulate 400m loop'), findsOneWidget);
    });

    testWidgets('Tapping version row 7 times unlocks demo mode and displays switch', (
      tester,
    ) async {
      final prefs = AppPreferences();
      prefs.setMockDemoState(unlocked: false, enabled: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileSettingsList(
                firebaseService: FirebaseService(),
                territoryService: TerritoryService(),
                onOpenAuth: () {},
              ),
            ),
          ),
        ),
      );

      // Before 7 taps, Demo mode switch is not rendered
      expect(find.text('Demo mode & simulation'), findsNothing);

      // Tap 1 to 6 times
      final versionTile = find.text('Territory Runner');
      expect(versionTile, findsOneWidget);
      await tester.ensureVisible(versionTile);
      await tester.pumpAndSettle();

      for (int i = 1; i <= 6; i++) {
        await tester.tap(versionTile);
        await tester.pump(const Duration(milliseconds: 100));
        expect(prefs.isDemoModeUnlocked, isFalse);
      }

      // 7th tap: unlocks demo mode
      await tester.tap(versionTile);
      await tester.pumpAndSettle();

      expect(prefs.isDemoModeUnlocked, isTrue);
      expect(prefs.isDemoModeEnabled, isTrue);
      expect(find.text('Demo mode & simulation'), findsOneWidget);

      // Verify toggling switch OFF disables demo mode
      final switchFinder = find.widgetWithText(SwitchListTile, 'Demo mode & simulation');
      expect(switchFinder, findsOneWidget);
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(prefs.isDemoModeEnabled, isFalse);
    });
  });
}
