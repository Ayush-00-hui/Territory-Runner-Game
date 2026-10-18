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

/// Offline map tile caching engine providing slippy tile coordinate calculations,
/// proactive bounding box pre-downloading, disk size monitoring, and offline-first tile serving.
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  factory TileCacheService() => _instance;

  TileCacheService._internal();

  Directory? _cacheDir;

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/offline_tiles');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Converts latitude, longitude and zoom level to Slippy Map tile X and Y indices
  math.Point<int> latLngToTile(double lat, double lng, int zoom) {
    final n = math.pow(2.0, zoom);
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y = ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n).floor();
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
      AppLogger.error('Error saving tile $z/$x/$y', error: e, stackTrace: st, tag: 'TileCacheService');
    }
  }

  /// Pre-downloads map tiles in a circular area around [center] across [zoomLevels]
  /// Returns the number of successfully downloaded and cached tiles.
  Future<int> preDownloadArea({
    required LatLng center,
    double radiusKm = 1.2,
    List<int> zoomLevels = const [14, 15, 16],
    Function(int completed, int total)? onProgress,
  }) async {
    // Earth radius approximation: 1 deg lat ~= 111 km
    final double dLat = radiusKm / 111.0;
    final double dLng = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180.0));

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
          final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
          final resp = await http.get(Uri.parse(url), headers: {
            'User-Agent': 'TerritoryRunner/4.0',
          }).timeout(const Duration(seconds: 4));

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
      await for (final file in dir.list(recursive: true, followLinks: false)) {
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
      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          totalBytes += await file.length();
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
      AppLogger.error('Error clearing cache', error: e, stackTrace: st, tag: 'TileCacheService');
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

class _OfflineFirstImageProvider extends ImageProvider<_OfflineFirstImageProvider> {
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
  Future<_OfflineFirstImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_OfflineFirstImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_OfflineFirstImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<String>('Tile URL', url),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(ImageDecoderCallback decode) async {
    // 1. Check local disk cache
    final file = await cacheService.getTileFile(z, x, y);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return await decode(buffer);
      }
    }

    // 2. Fetch from network and write to cache
    try {
      final client = http.Client();
      final response = await client.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        // Cache asynchronously in background
        cacheService.saveTile(z, x, y, response.bodyBytes);
        final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
        return await decode(buffer);
      }
    } catch (_) {}

    // 3. Fallback: 1x1 transparent pixel so map rendering doesn't crash
    final transparentPng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
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
