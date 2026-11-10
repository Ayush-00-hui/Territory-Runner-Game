import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/runner_avatar.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/wardrobe_catalog.dart';
import 'package:territory_runner/services/avatar_service.dart';
import 'package:territory_runner/ui/widgets/runner_avatar_painter.dart';
import 'package:territory_runner/features/profile/widgets/wardrobe_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase A: WardrobeCatalog & UnlockCondition Tests', () {
    test('Catalog contains 6 categories and >= 60 items total (>= 10 per category)', () {
      expect(WardrobeCategory.values.length, 6);
      expect(WardrobeCatalog.items.length, greaterThanOrEqualTo(60));

      for (final cat in WardrobeCategory.values) {
        final items = WardrobeCatalog.getItemsByCategory(cat);
        expect(
          items.length,
          greaterThanOrEqualTo(10),
          reason: 'Category ${cat.name} must have at least 10 items',
        );
        for (final item in items) {
          expect(item.id.trim(), isNotEmpty);
          expect(item.name.trim(), isNotEmpty);
          expect(item.description.trim(), isNotEmpty);
        }
      }
    });

    test(
      'Unlock conditions accurately evaluate against RunnerProfile metrics',
      () {
        final novice = RunnerProfile(
          id: 'novice_1',
          username: 'Rookie',
          level: 1,
          xp: 50,
          totalDistanceKm: 5.0,
          currentStreak: 1,
        );

        final veteran = RunnerProfile(
          id: 'veteran_1',
          username: 'ProRunner',
          level: 5,
          xp: 1500,
          totalDistanceKm: 60.0,
          currentStreak: 7,
        );

        const freeCond = WardrobeUnlockCondition.free();
        expect(freeCond.isUnlocked(novice), isTrue);
        expect(freeCond.isUnlocked(null), isTrue);

        const levelCond = WardrobeUnlockCondition.level(3);
        expect(levelCond.isUnlocked(novice), isFalse);
        expect(levelCond.isUnlocked(veteran), isTrue);

        const distCond = WardrobeUnlockCondition.distance(25);
        expect(distCond.isUnlocked(novice), isFalse);
        expect(distCond.isUnlocked(veteran), isTrue);

        const streakCond = WardrobeUnlockCondition.streak(5);
        expect(streakCond.isUnlocked(novice), isFalse);
        expect(streakCond.isUnlocked(veteran), isTrue);
      },
    );
  });

  group('Phase A: RunnerAvatar & AvatarService Tests', () {
    test('RunnerAvatar serializes and deserializes accurately with default fallback', () {
      const avatar = RunnerAvatar(
        headwearId: 'headwear_cap_graphite',
        topId: 'top_singlet_electric',
        bottomsId: 'bottoms_shorts_blue',
        shoesId: 'shoes_spike_yellow',
        accessoryId: 'acc_watch_charcoal',
        bodyToneId: 'tone_golden_olive',
        isReadyPose: true,
      );

      final raw = avatar.serialize();
      final restored = RunnerAvatar.deserialize(raw);

      expect(restored, equals(avatar));
      expect(restored.headwearId, 'headwear_cap_graphite');
      expect(restored.isReadyPose, isTrue);

      // Faulty JSON fallback
      final fallback = RunnerAvatar.deserialize('not a json string');
      expect(fallback, equals(RunnerAvatar.defaultAvatar));
    });

    test(
      'AvatarService equips items across all 6 categories and updates notifier',
      () async {
        final service = AvatarService.instance;
        service.setAvatarForTesting(RunnerAvatar.defaultAvatar);

        await service.equip(
          WardrobeCategory.headwear,
          'headwear_headband_blue',
        );
        expect(service.currentAvatar.headwearId, 'headwear_headband_blue');

        await service.equip(WardrobeCategory.top, 'top_pro_tank_yellow');
        expect(service.currentAvatar.topId, 'top_pro_tank_yellow');

        await service.equip(
          WardrobeCategory.bottoms,
          'bottoms_half_tights_dark',
        );
        expect(service.currentAvatar.bottomsId, 'bottoms_half_tights_dark');

        await service.equip(WardrobeCategory.shoes, 'shoes_carbon_cyan');
        expect(service.currentAvatar.shoesId, 'shoes_carbon_cyan');

        await service.equip(WardrobeCategory.accessory, 'acc_shades_cyan');
        expect(service.currentAvatar.accessoryId, 'acc_shades_cyan');

        await service.equip(WardrobeCategory.bodyTone, 'tone_deep_bronze');
        expect(service.currentAvatar.bodyToneId, 'tone_deep_bronze');

        await service.setReadyPose(true);
        expect(service.currentAvatar.isReadyPose, isTrue);

        // Reset
        await service.clear();
        expect(service.currentAvatar, equals(RunnerAvatar.defaultAvatar));
      },
    );
  });

  group('Phase A: RunnerAvatarPainter & AvatarWidget Rendering Tests', () {
    testWidgets(
      'AvatarWidget renders in running cycle across animation values without error',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: AvatarWidget(size: 80, isRunning: true)),
            ),
          ),
        );

        expect(find.byType(AvatarWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);

        // Advance animation frames across stride cycle
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
      },
    );

    testWidgets(
      'AvatarWidget respects reduced motion by rendering static ready pose',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: AvatarWidget(size: 64, isRunning: true)),
              ),
            ),
          ),
        );

        expect(find.byType(AvatarWidget), findsOneWidget);
        // Under reduced motion, no AnimatedBuilder is built
        expect(
          find.descendant(
            of: find.byType(AvatarWidget),
            matching: find.byType(AnimatedBuilder),
          ),
          findsNothing,
        );
      },
    );

    test(
      'RunnerAvatarPainter paints running stride and ready stance safely',
      () {
        final painterRunning = RunnerAvatarPainter(
          avatar: RunnerAvatar.defaultAvatar,
          progress: 0.5,
          isReadyPose: false,
        );

        final painterReady = RunnerAvatarPainter(
          avatar: RunnerAvatar.defaultAvatar,
          progress: 0.0,
          isReadyPose: true,
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        // Paint 100x100 virtual space
        expect(
          () => painterRunning.paint(canvas, const Size(100, 100)),
          returnsNormally,
        );
        expect(
          () => painterReady.paint(canvas, const Size(100, 100)),
          returnsNormally,
        );

        // Verify all silhouette variants (singlet, long sleeve, full tights, cap, shades, watch)
        final variantAvatar = const RunnerAvatar(
          headwearId: 'headwear_cap_graphite',
          topId: 'top_long_sleeve_obsidian',
          bottomsId: 'bottoms_tights_thermal',
          shoesId: 'shoes_carbon_cyan',
          accessoryId: 'acc_shades_cyan',
          bodyToneId: 'tone_deep_bronze',
        );
        for (final t in [0.0, 0.25, 0.5, 0.75]) {
          expect(
            () => RunnerAvatarPainter(
              avatar: variantAvatar,
              progress: t,
              isReadyPose: false,
            ).paint(canvas, const Size(160, 160)),
            returnsNormally,
          );
        }
        expect(
          () => RunnerAvatarPainter(
            avatar: variantAvatar.copyWith(
              topId: 'top_pro_tank_yellow',
              headwearId: 'headwear_beanie_dark',
              accessoryId: 'acc_watch_charcoal',
            ),
            progress: 0.0,
            isReadyPose: true,
          ).paint(canvas, const Size(160, 160)),
          returnsNormally,
        );
      },
    );
  });

  group('Phase A: WardrobeSheet Widget Tests', () {
    setUp(() {
      AvatarService.instance.setAvatarForTesting(RunnerAvatar.defaultAvatar);
    });

    testWidgets(
      'WardrobeSheet renders avatar stage, category tabs, and equips items',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final profile = RunnerProfile(
          id: 'marathoner_1',
          username: 'Marathoner',
          level: 5,
          xp: 1200,
          totalDistanceKm: 35.0,
          currentStreak: 4,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WardrobeSheet(profile: profile)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Runner Wardrobe'), findsOneWidget);
        expect(find.text('Tops'), findsOneWidget);
        expect(find.text('Headwear'), findsOneWidget);
        expect(find.text('Shoes'), findsOneWidget);

        // Tap an unlocked top to equip it
        final proTankFinder = find.text('Mustard Speed Tank');
        expect(proTankFinder, findsOneWidget);
        await tester.tap(proTankFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          AvatarService.instance.currentAvatar.topId,
          'top_pro_tank_yellow',
        );
      },
    );

    testWidgets('WardrobeSheet guards locked items and informs runner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final novice = RunnerProfile(
        id: 'newbie_1',
        username: 'Newbie',
        level: 1,
        xp: 10,
        totalDistanceKm: 1.0,
        currentStreak: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WardrobeSheet(profile: novice)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on locked Mustard Speed Tank (requires Level 2, novice is Level 1)
      final lockedTankFinder = find.text('Mustard Speed Tank');
      expect(lockedTankFinder, findsOneWidget);

      await tester.tap(lockedTankFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tank remains unequipped
      expect(
        AvatarService.instance.currentAvatar.topId,
        isNot('top_pro_tank_yellow'),
      );
    });
  });
}
