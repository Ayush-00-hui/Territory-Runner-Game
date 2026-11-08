import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/home/widgets/needs_defending_row.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/models/territory.dart';
import 'package:territory_runner/services/api_client.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/services/notification_service.dart';
import 'package:territory_runner/services/user_settings_service.dart';
import 'package:territory_runner/ui/theme/app_theme.dart';

class MockApiClientForReminders implements ApiClient {
  @override
  final String baseUrl = 'http://127.0.0.1:8080';
  Map<String, dynamic>? lastUpdatedSettings;
  bool shouldThrow = false;

  @override
  Future<Map<String, dynamic>?> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    if (shouldThrow) {
      throw Exception('Simulated network disconnect');
    }
    lastUpdatedSettings = Map<String, dynamic>.from(settings);
    return lastUpdatedSettings;
  }

  @override
  Future<Map<String, dynamic>?> getSettings() async {
    if (shouldThrow) {
      throw Exception('Simulated network disconnect');
    }
    return {
      'live_visibility': 'off',
      'land_reminders': true,
      'timezone': 'UTC',
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task F1: UserSettingsService Land Reminders & Timezone', () {
    late MockApiClientForReminders mockApi;
    late UserSettingsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockApi = MockApiClientForReminders();
      service = UserSettingsService.custom(apiClient: mockApi);
    });

    test(
      'defaults to landReminders = true and loads from local prefs',
      () async {
        expect(service.landReminders, isTrue);
        expect(service.localTimezone.isNotEmpty, isTrue);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pref_land_reminders', false);

        final newService = UserSettingsService.custom(
          apiClient: mockApi,
          isInitialized: false,
        );
        await newService.init();
        expect(newService.landReminders, isFalse);
      },
    );

    test(
      'setLandReminders updates memory, local storage, and syncs timezone',
      () async {
        await service.setLandReminders(false);
        expect(service.landReminders, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('pref_land_reminders'), isFalse);

        expect(mockApi.lastUpdatedSettings, isNotNull);
        expect(mockApi.lastUpdatedSettings!['land_reminders'], isFalse);
        expect(
          mockApi.lastUpdatedSettings!['timezone'],
          equals(service.localTimezone),
        );
      },
    );

    test(
      'setLandReminders operates offline-first on network failure',
      () async {
        mockApi.shouldThrow = true;
        await service.setLandReminders(false);

        expect(service.landReminders, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('pref_land_reminders'), isFalse);
      },
    );
  });

  group('Task F1: NeedsDefendingRow UI & Effective Strength', () {
    testWidgets('hidden when all territories are fortified (> 50% strength)', (
      tester,
    ) async {
      final now = DateTime.now();
      final fortifiedTerritories = [
        Territory(
          id: 'poly_fortified_1',
          ownerId: 'runner_1',
          polygon: const [
            LatLng(51.50, -0.12),
            LatLng(51.51, -0.12),
            LatLng(51.51, -0.11),
          ],
          areaSqMeters: 50000.0,
          capturedAt: now,
          lastDefendedAt: now, // 100% strength
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: NeedsDefendingRow(territories: fortifiedTerritories),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs defending'), findsNothing);
      expect(find.byType(NeedsDefendingRow), findsOneWidget);
    });

    testWidgets('renders weak territory, area, and strength percentage', (
      tester,
    ) async {
      final now = DateTime.now();
      // 4 days since defense: at 15%/day, strength drops by 60% -> 40% strength (<= 50%)
      final fourDaysAgo = now.subtract(const Duration(days: 4));

      final weakTerritories = [
        Territory(
          id: 'poly_weak_1',
          ownerId: 'runner_1',
          polygon: const [
            LatLng(51.50, -0.12),
            LatLng(51.51, -0.12),
            LatLng(51.51, -0.11),
          ],
          areaSqMeters: 25000.0,
          capturedAt: fourDaysAgo,
          lastDefendedAt: fourDaysAgo,
          strength: 100.0,
        ),
      ];

      String? tappedTerritoryId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: NeedsDefendingRow(
              territories: weakTerritories,
              onTerritoryTap: (id) => tappedTerritoryId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs defending'), findsOneWidget);
      expect(find.text('0.03 km²'), findsOneWidget);
      expect(find.text('40% strength'), findsOneWidget);
      expect(
        find.text('A short loop through this area will restore it.'),
        findsOneWidget,
      );

      // Verify tap navigates to territory
      await tester.tap(find.text('Needs defending'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0.03 km²'));
      await tester.pumpAndSettle();
      expect(tappedTerritoryId, equals('poly_weak_1'));
    });
  });

  group('Task F1: SettingsList Land Reminders Toggle', () {
    testWidgets('renders Land reminders switch tile with calm description', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'pref_land_reminders': true});

      UserSettingsService().resetForTesting(initialLandReminders: true);

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
      await tester.pumpAndSettle();

      expect(find.text('Land reminders'), findsOneWidget);
      expect(
        find.text('Notify when territory strength drops below 50% or 30%'),
        findsOneWidget,
      );

      // Verify toggle switch
      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Land reminders',
      );
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
    });
  });

  group(
    'Task F1: Notification Service Zero Coordinates & Foreground Toast',
    () {
      test(
        'simulateAttackedTerritoryTap dispatches id without coords',
        () async {
          final notifService = NotificationService();
          String? receivedId;

          final sub = notifService.onAttackedTerritoryTapped.listen((id) {
            receivedId = id;
          });

          notifService.simulateAttackedTerritoryTap('poly_weak_decay_777');
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(receivedId, equals('poly_weak_decay_777'));
          await sub.cancel();
        },
      );
    },
  );
}
