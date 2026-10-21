import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../core/logging/app_logger.dart';
import '../core/utils/constants.dart';

/// Offline map tile caching engine providing slippy tile coordinate calculations,
/// proactive bounding box pre-downloading, disk size monitoring, and offline-first tile serving.
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  factory TileCacheService() => _instance;

  TileCacheService._internal();

  static Directory? _cacheDir;

  @visibleForTesting
  void setCacheDirectoryForTesting(Directory dir) {
    _cacheDir = dir;
  }

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) {
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      return _cacheDir!;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final dir = Directory('${Directory.systemTemp.path}/test_offline_tiles');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/offline_tiles');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (_) {
      final dir = Directory('${Directory.systemTemp.path}/offline_tiles');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    }
  }

  /// Converts latitude, longitude and zoom level to Slippy Map tile X and Y indices
  math.Point<int> latLngToTile(double lat, double lng, int zoom) {
    final n = math.pow(2.0, zoom);
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y =
        ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
                2.0 *
                n)
            .floor();
    return math.Point<int>(x, y);
  }

  /// Returns the local cached File object for a given tile coordinate
  Future<File> getTileFile(int z, int x, int y) async {
    final dir = await _getCacheDirectory();
    return File('${dir.path}/$z/$x/$y.png');
  }

  /// Checks if a tile is already cached locally
  Future<bool> hasCachedTile(int z, int x, int y) async {
    final file = await getTileFile(z, x, y);
    return file.exists();
  }

  /// Saves raw image bytes for a tile into the local cache
  Future<void> saveTile(int z, int x, int y, Uint8List bytes) async {
    try {
      final file = await getTileFile(z, x, y);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e, st) {
      AppLogger.error(
        'Error saving tile $z/$x/$y',
        error: e,
        stackTrace: st,
        tag: 'TileCacheService',
      );
    }
  }

  /// Pre-downloads map tiles in a circular area around [center] across [zoomLevels]
  /// Returns the number of successfully downloaded and cached tiles.
  /// Note: Gated by [AppConstants.allowTilePrefetch] to comply with OSM Tile Usage Policy.
  Future<int> preDownloadArea({
    required LatLng center,
    double radiusKm = 1.2,
    List<int> zoomLevels = const [14, 15, 16],
    Function(int completed, int total)? onProgress,
  }) async {
    if (!AppConstants.allowTilePrefetch) {
      AppLogger.warning(
        'Tile prefetch skipped: ALLOW_TILE_PREFETCH is false. Bulk downloading is disallowed under OpenStreetMap Tile Usage Policy.',
        tag: 'TileCacheService',
      );
      return 0;
    }

    // Earth radius approximation: 1 deg lat ~= 111 km
    final double dLat = radiusKm / 111.0;
    final double dLng =
        radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180.0));

    final double minLat = center.latitude - dLat;
    final double maxLat = center.latitude + dLat;
    final double minLng = center.longitude - dLng;
    final double maxLng = center.longitude + dLng;

    final List<Map<String, int>> tilesToFetch = [];

    for (final zoom in zoomLevels) {
      final topLeft = latLngToTile(maxLat, minLng, zoom);
      final bottomRight = latLngToTile(minLat, maxLng, zoom);

      final minX = math.min(topLeft.x, bottomRight.x);
      final maxX = math.max(topLeft.x, bottomRight.x);
      final minY = math.min(topLeft.y, bottomRight.y);
      final maxY = math.max(topLeft.y, bottomRight.y);

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          tilesToFetch.add({'z': zoom, 'x': x, 'y': y});
        }
      }
    }

    final total = tilesToFetch.length;
    int completed = 0;
    int newlySaved = 0;

    for (final t in tilesToFetch) {
      final z = t['z']!;
      final x = t['x']!;
      final y = t['y']!;

      if (!await hasCachedTile(z, x, y)) {
        try {
          final url = AppConstants.tileUrlTemplate
              .replaceAll('{z}', z.toString())
              .replaceAll('{x}', x.toString())
              .replaceAll('{y}', y.toString())
              .replaceAll('{apiKey}', AppConstants.tileApiKey)
              .replaceAll('{accessToken}', AppConstants.tileApiKey);

          final resp = await http
              .get(
                Uri.parse(url),
                headers: {'User-Agent': AppConstants.userAgent},
              )
              .timeout(const Duration(seconds: 4));

          if (resp.statusCode == 200) {
            await saveTile(z, x, y, resp.bodyBytes);
            newlySaved++;
          }
        } catch (_) {}
      }

      completed++;
      onProgress?.call(completed, total);
    }

    return newlySaved;
  }

  /// Calculates total count of offline cached tile images
  Future<int> getCachedTileCount() async {
    try {
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) return 0;
      int count = 0;
      for (final file in dir.listSync(recursive: true, followLinks: false)) {
        if (file is File && file.path.endsWith('.png')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Calculates total disk size in bytes of offline cached tile files
  Future<int> getCacheSizeBytes() async {
    try {
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) return 0;
      int totalBytes = 0;
      for (final file in dir.listSync(recursive: true, followLinks: false)) {
        if (file is File) {
          totalBytes += file.lengthSync();
        }
      }
      return totalBytes;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all cached offline map tiles
  Future<void> clearCache() async {
    try {
      final dir = await _getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e, st) {
      AppLogger.error(
        'Error clearing cache',
        error: e,
        stackTrace: st,
        tag: 'TileCacheService',
      );
    }
  }
}

/// Offline-first [TileProvider] that inspects local disk cache before falling back to network
class OfflineFirstTileProvider extends TileProvider {
  final TileCacheService _cacheService = TileCacheService();

  OfflineFirstTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final z = coordinates.z.toInt();
    final x = coordinates.x.toInt();
    final y = coordinates.y.toInt();

    final url = getTileUrl(coordinates, options);

    return _OfflineFirstImageProvider(
      url: url,
      z: z,
      x: x,
      y: y,
      cacheService: _cacheService,
      headers: headers,
    );
  }
}

class _OfflineFirstImageProvider
    extends ImageProvider<_OfflineFirstImageProvider> {
  final String url;
  final int z;
  final int x;
  final int y;
  final TileCacheService cacheService;
  final Map<String, String>? headers;

  const _OfflineFirstImageProvider({
    required this.url,
    required this.z,
    required this.x,
    required this.y,
    required this.cacheService,
    this.headers,
  });

  @override
  Future<_OfflineFirstImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<_OfflineFirstImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _OfflineFirstImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<String>('Tile URL', url),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(ImageDecoderCallback decode) async {
    final file = await cacheService.getTileFile(z, x, y);
    bool hasCachedFile = await file.exists();
    DateTime? lastModified;
    Uint8List? cachedBytes;

    if (hasCachedFile) {
      try {
        lastModified = await file.lastModified();
        cachedBytes = await file.readAsBytes();
      } catch (_) {
        hasCachedFile = false;
        cachedBytes = null;
      }
    }

    // 1. If we have a fresh cached tile (< minTileCacheDays old), serve immediately.
    final bool isCacheFresh =
        hasCachedFile &&
        cachedBytes != null &&
        cachedBytes.isNotEmpty &&
        lastModified != null &&
        DateTime.now().difference(lastModified).inDays <
            AppConstants.minTileCacheDays;

    if (isCacheFresh) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(cachedBytes);
      return await decode(buffer);
    }

    // 2. Fetch from network (fresh fetch or conditional revalidation)
    final requestHeaders = <String, String>{
      'User-Agent': AppConstants.userAgent,
      ...?headers,
    };
    if (hasCachedFile && lastModified != null) {
      requestHeaders['If-Modified-Since'] = HttpDate.format(lastModified);
    }

    try {
      final response = await http
          .get(Uri.parse(url), headers: requestHeaders)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Cache asynchronously in background
        cacheService.saveTile(z, x, y, response.bodyBytes);
        final buffer = await ui.ImmutableBuffer.fromUint8List(
          response.bodyBytes,
        );
        return await decode(buffer);
      } else if (response.statusCode == 304 &&
          cachedBytes != null &&
          cachedBytes.isNotEmpty) {
        // Not Modified: touch timestamp to extend cache freshness
        try {
          await file.setLastModified(DateTime.now());
        } catch (_) {}
        final buffer = await ui.ImmutableBuffer.fromUint8List(cachedBytes);
        return await decode(buffer);
      }
    } catch (_) {
      // Network failed or timed out: fall back to cached tile if available
      if (cachedBytes != null && cachedBytes.isNotEmpty) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(cachedBytes);
        return await decode(buffer);
      }
    }

    // 3. If cache was stale but network failed, fallback to stale cached bytes
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(cachedBytes);
      return await decode(buffer);
    }

    // 3. Fallback: 1x1 transparent pixel so map rendering doesn't crash
    final transparentPng = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    final buffer = await ui.ImmutableBuffer.fromUint8List(transparentPng);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _OfflineFirstImageProvider &&
        other.url == url &&
        other.z == z &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(url, z, x, y);
}
