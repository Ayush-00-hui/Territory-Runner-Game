import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/core/utils/constants.dart';
import 'package:territory_runner/services/tile_cache_service.dart';
import 'package:territory_runner/features/map/widgets/map_layers.dart';
import 'package:territory_runner/features/profile/widgets/offline_maps_sheet.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tile Compliance & OpenStreetMap Policy', () {
    test('AppConstants defaults enforce OSM compliance', () {
      expect(
        AppConstants.tileUrlTemplate,
        equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
      );
      expect(
        AppConstants.tileAttribution,
        equals('© OpenStreetMap contributors'),
      );
      expect(AppConstants.allowTilePrefetch, isFalse);
      expect(AppConstants.minTileCacheDays, equals(7));
      expect(AppConstants.userAgent, contains('com.territoryrunner.app'));
      expect(
        AppConstants.userAgent,
        contains('https://github.com/Ayush-00-hui/Territory-Runner-Game'),
      );
    });

    test(
      'TileCacheService rejects preDownloadArea when prefetch is disabled',
      () async {
        final service = TileCacheService();
        expect(AppConstants.allowTilePrefetch, isFalse);

        final downloaded = await service.preDownloadArea(
          center: const LatLng(51.5074, -0.1278),
          radiusKm: 1.0,
        );

        // Must return 0 immediately without performing network requests
        expect(downloaded, equals(0));
      },
    );

    test('TileCacheService saves, reads count/size, and clears cache in test directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('tile_cache_test_');
      final service = TileCacheService();
      service.setCacheDirectoryForTesting(tempDir);

      try {
        expect(await service.getCachedTileCount(), equals(0));
        expect(await service.getCacheSizeBytes(), equals(0));

        // Save a mock 4-byte tile
        final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
        await service.saveTile(15, 100, 200, fakeBytes);

        expect(await service.hasCachedTile(15, 100, 200), isTrue);
        expect(await service.hasCachedTile(15, 101, 200), isFalse);
        expect(await service.getCachedTileCount(), equals(1));
        expect(await service.getCacheSizeBytes(), equals(4));

        // Clear cache
        await service.clearCache();
        expect(await service.getCachedTileCount(), equals(0));
        expect(await service.getCacheSizeBytes(), equals(0));
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('MapLayers.buildTileLayer constructs compliant TileLayer', () {
      final layer = MapLayers.buildTileLayer();

      expect(layer.urlTemplate, equals(AppConstants.tileUrlTemplate));
      expect(layer.tileProvider, isA<OfflineFirstTileProvider>());
      expect(
        layer.tileProvider.headers['User-Agent'],
        equals(AppConstants.userAgent),
      );
    });

    testWidgets(
      'OfflineMapsSheet renders policy compliance notice when prefetch is disabled',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: OfflineMapsSheet()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Check header and storage card
        expect(find.text('Offline Map Storage'), findsOneWidget);
        expect(find.text('Cached Tiles'), findsOneWidget);
        expect(find.text('Disk Occupied'), findsOneWidget);

        // Check policy notice
        expect(
          find.text(
            'OSM Tile Usage Policy viewing cache active. Viewed areas remain cached offline.',
          ),
          findsOneWidget,
        );

        // Bulk download button should NOT be present when prefetch is disabled
        expect(find.text('Pre-Cache Current Sector (1.2 km)'), findsNothing);

        // Purge cache button should be present
        expect(find.text('Purge Offline Map Cache'), findsOneWidget);
      },
    );

    testWidgets(
      'Map Data & Attribution tile renders AppConstants.tileAttribution',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProfileOptionTile(
                icon: Icons.map_outlined,
                title: 'Map Data & Attribution',
                subtitle: AppConstants.tileAttribution,
                onTap: null,
              ),
            ),
          ),
        );
        expect(find.text('Map Data & Attribution'), findsOneWidget);
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      },
    );
  });
}
